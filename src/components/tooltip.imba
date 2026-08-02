import {uid} from '../core/id'
import {clamp} from '../core/math'
import {isBrowser} from '../core/env'

const DWELL_MS = 600
const EDGE_GAP = 8
const TOOLTIP_OFFSET = 10

tag gk-tooltip
	prop text = ''
	prop placement = 'top'
	prop visible = no
	prop anchorX = 0
	prop anchorY = 0
	prop forId = null

	def mount
		self.tipId = uid 'gktip'
		self.dwellTimer = null
		self.anchor = null
		self.listeners = []
		attachAnchor!

	def unmount
		clearDwell!
		detachAnchor!

	def forIdDidSet val
		if self.anchor != null
			detachAnchor!
			attachAnchor!

	def attachAnchor
		unless isBrowser
			return
		let el = null
		let ref = forId
		if ref == null or ref == ''
			ref = self.getAttribute 'for'
		if ref != null and ref != ''
			el = globalThis.document.getElementById ref
		elif self.parentElement != null
			el = self.parentElement
		if el == null
			return
		self.anchor = el
		el.setAttribute 'aria-describedby', self.tipId
		add el, 'pointerenter', do(e) scheduleShow e
		add el, 'pointerleave', do(e) hide e
		add el, 'focus', do(e) scheduleShow e
		add el, 'blur', do(e) hide e
		add el, 'keydown', do(e) (if e.key == 'Escape' then hide!)

	def detachAnchor
		for pair in self.listeners
			pair[0].removeEventListener pair[1], pair[2]
		self.listeners = []
		if self.anchor != null
			self.anchor.removeAttribute 'aria-describedby'
			self.anchor = null

	def add el, type, fn
		el.addEventListener type, fn
		self.listeners.push [el, type, fn]

	def clearDwell
		if self.dwellTimer != null
			globalThis.clearTimeout self.dwellTimer
			self.dwellTimer = null

	def scheduleShow e
		clearDwell!
		self.dwellTimer = globalThis.setTimeout (do show!), DWELL_MS

	def show
		self.dwellTimer = null
		if self.anchor == null or text == ''
			return
		let rect = self.anchor.getBoundingClientRect!
		positionFor rect
		visible = yes
		imba.commit!
		globalThis.setTimeout (do self.measure!), 0

	def positionFor rect
		let vw = globalThis.window.innerWidth
		let vh = globalThis.window.innerHeight
		let cx = rect.left + rect.width / 2
		let cy = if placement == 'bottom' then rect.bottom + TOOLTIP_OFFSET else rect.top - TOOLTIP_OFFSET
		anchorX = clamp(cx, EDGE_GAP + 40, vw - EDGE_GAP - 40)
		anchorY = clamp(cy, EDGE_GAP, vh - EDGE_GAP)

	def measure
		if !visible
			return
		let vw = globalThis.window.innerWidth
		let vh = globalThis.window.innerHeight
		let rect = self.getBoundingClientRect!
		let nx = anchorX
		let ny = anchorY
		if placement == 'top' and rect.top < EDGE_GAP
			placement = 'bottom'
			let arect = self.anchor.getBoundingClientRect!
			ny = arect.bottom + TOOLTIP_OFFSET
		elif placement == 'bottom' and rect.bottom > vh - EDGE_GAP
			placement = 'top'
			let arect2 = self.anchor.getBoundingClientRect!
			ny = arect2.top - TOOLTIP_OFFSET
		if rect.left < EDGE_GAP
			nx = anchorX + (EDGE_GAP - rect.left)
		elif rect.right > vw - EDGE_GAP
			nx = anchorX - (rect.right - (vw - EDGE_GAP))
		if nx != anchorX or ny != anchorY
			anchorX = nx
			anchorY = ny
			imba.commit!

	def hide e
		clearDwell!
		if visible
			visible = no
			imba.commit!

	def render
		<self role='tooltip'
			id=self.tipId
			data-placement=placement
			data-visible=(visible ? '1' : null)
			style="left:{Math.round(anchorX)}px; top:{Math.round(anchorY)}px">
			<span .gk-tooltip-text> text

export def attachTooltip el, tipText, opts = {}
	let tip = globalThis.document.createElement 'gk-tooltip'
	tip.setAttribute 'text', tipText
	if opts.placement != null
		tip.setAttribute 'placement', opts.placement
	if el.id == null or el.id == ''
		el.id = uid 'gktta'
	tip.setAttribute 'for', el.id
	globalThis.document.body.appendChild tip
	tip
