import {safeArea} from './safe-area'
import {bus} from '../core/event-bus'
import {uid} from '../core/id'
import {Rect} from '../core/geometry'
import {preferences} from '../a11y/preferences'
import {clamp} from '../core/math'
import {SCROLL_EDGE_SIZE} from '../core/constants'

export const ScrollEdgeEffect =
	automatic: 'automatic'
	soft: 'soft'
	hard: 'hard'
	hidden: 'hidden'

let activeRendererProvider = null

export def setEdgeRendererProvider fn
	activeRendererProvider = fn

export class SafeAreaBarModel
	prop edge
	prop style

	def constructor el, edge = 'top', style = 'automatic'
		self.id = uid 'gkbar'
		self.el = el
		self.edge = edge
		self.styleRaw = style
		self.strength = 0
		self.barId = null
		self.effect = null
		self.rectCss = new Rect
		self.scrollUnsub = null

	get resolvedStyle
		if self.styleRaw == 'automatic'
			'soft'
		else
			self.styleRaw

	def attach
		self.barId = safeArea.registerBar self.edge, measureThickness!, self.el
		let provider = activeRendererProvider
		if provider
			let renderer = provider!
			if renderer
				self.effect = renderer.registerEdgeEffect
					id: self.id
					edge: self.edge
					style: (if preferences.reducedTransparency then 'hard' else resolvedStyle)
					strength: self.strength
					rectGL: new Rect
					bandSizeGL: SCROLL_EDGE_SIZE
		self.scrollUnsub = bus.on 'scroll:updated', do(payload) self.handleScroll(payload)
		updateRects 1, 600

	def measureThickness
		let r = self.el.getBoundingClientRect!
		if self.edge == 'top' or self.edge == 'bottom'
			r.height
		else
			r.width

	def handleScroll payload
		let el = payload.element
		let under = 0
		if self.edge == 'top'
			under = payload.top
		elif self.edge == 'bottom'
			under = Math.max 0, (el.scrollHeight - el.clientHeight) - payload.top
		else
			under = payload.leading
		let s = clamp under / 24, 0, 1
		if s != self.strength
			self.strength = s
			if self.effect
				self.effect.strength = s
			bus.emit 'edge:strength', {id: self.id, strength: s}

	def updateRects dpr = 1, vpHeight = 600
		let r = self.el.getBoundingClientRect!
		self.rectCss.set r.left, r.top, r.width, r.height
		if self.barId
			safeArea.updateBar self.barId, (self.edge == 'top' or self.edge == 'bottom' ? r.height : r.width)
		if self.effect
			self.effect.rectGL.set r.left * dpr, (vpHeight - r.top - r.height) * dpr, r.width * dpr, r.height * dpr
			self.effect.bandSizeGL = SCROLL_EDGE_SIZE * dpr
			self.effect.strength = self.strength
			self.effect.style = (if preferences.reducedTransparency then 'hard' else resolvedStyle)

	def detach
		if self.barId
			safeArea.unregisterBar self.barId
		if self.effect and activeRendererProvider
			let renderer = activeRendererProvider!
			if renderer
				renderer.unregisterEdgeEffect self.effect
		if self.scrollUnsub
			self.scrollUnsub!

tag gk-safe-bar
	prop edge = 'top'
	prop scrollEdge = 'automatic'

	def mount
		self.barModel = new SafeAreaBarModel self, edge, scrollEdge
		self.barModel.attach!
		self.setAttribute 'data-gk-safe-bar', edge

	def unmount
		self.barModel.detach!
		self.barModel = null

	get model
		self.barModel

	<self>
		<slot>
