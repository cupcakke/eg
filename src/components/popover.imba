import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {clamp} from '../core/math'
import {uid} from '../core/id'
import {logger} from '../core/logger'

tag gk-popover
	prop anchorel = null
	prop open = no @watch
	prop placement = 'bottom'
	prop label = 'Popover'

	def mount
		self.__gkOwnsGlassSurface = yes
		self.popId = uid 'gkp'
		self.outsideHandler = do(e) self.handleOutside(e)
		self.keyHandler = do(e) if e.key == 'Escape' then self.requestClose!
		self.arrowEl = null
		if open
			present!

	def unmount
		dismissAll!

	def openDidSet value
		if value then present! else dismissSoft!

	def present
		if self.glassHandle == null
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 16),
				namespace: 'popovers'
				glassId: 'popover:' + self.popId
				transition: 'materialize'
		globalThis.document.addEventListener 'pointerdown', self.outsideHandler, yes
		globalThis.document.addEventListener 'keydown', self.keyHandler, yes
		position!

	def dismissSoft
		globalThis.document.removeEventListener 'pointerdown', self.outsideHandler, yes
		globalThis.document.removeEventListener 'keydown', self.keyHandler, yes
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def dismissAll
		dismissSoft!

	def dialogKey e
		if e.key == 'Escape'
			e.preventDefault!
			requestClose!

	def requestClose
		self.dispatchEvent new CustomEvent 'close', {bubbles: yes}

	def handleOutside e
		if self.contains(e.target) == no
			let a = resolvedAnchor!
			if a == null or a.contains(e.target) == no
				requestClose!

	def resolvedAnchor
		if anchorel == null then return null
		if typeof anchorel == 'string' then return globalThis.document.querySelector anchorel
		anchorel

	def updateArrow ax, anchorCenterX
		if self.arrowEl == null
			return
		let axClamped = ax
		self.arrowEl.style.left = "{Math.round(axClamped)}px"

	def position
		globalThis.requestAnimationFrame do
			let a = resolvedAnchor!
			if a == null
				return
			let ar = a.getBoundingClientRect!
			let mr = self.getBoundingClientRect!
			let vw = globalThis.window.innerWidth
			let vh = globalThis.window.innerHeight
			let gap = 12
			let x = ar.left + ar.width / 2 - mr.width / 2
			let y = ar.bottom + gap
			let placementActual = placement
			if y + mr.height > vh - 8 and ar.top - gap - mr.height > 8
				y = ar.top - gap - mr.height
				placementActual = 'top'
			x = clamp x, 8, Math.max 8, vw - mr.width - 8
			self.style.left = "{Math.round(x)}px"
			self.style.top = "{Math.round(y)}px"
			let anchorCenterX = ar.left + ar.width / 2
			if self.arrowEl
				let ax = anchorCenterX - x - 9
				self.arrowEl.style.left = "{Math.round(clamp(ax, 10, mr.width - 28))}px"
				if placementActual == 'top'
					self.arrowEl.style.top = 'auto'
					self.arrowEl.style.bottom = '-9px'
					self.arrowEl.style.transform = 'rotate(180deg)'
				else
					self.arrowEl.style.top = '-9px'
					self.arrowEl.style.bottom = 'auto'
					self.arrowEl.style.transform = ''
			if self.getAttribute('open-announced') == null
				self.setAttribute 'open-announced', '1'

	def render
		<self role='dialog' aria-label=label style=(open ? '' : 'display:none') @keydown=(do self.dialogKey(e))>
			<div .gk-arrow$arrowEl aria-hidden='yes'>
			<slot>
