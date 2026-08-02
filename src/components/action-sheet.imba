import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {clamp} from '../core/math'
import {uid} from '../core/id'

tag gk-action-sheet
	prop anchorel = null
	prop actions = []
	prop open = no @watch
	prop label = 'Actions'

	def mount
		self.__gkOwnsGlassSurface = yes
		self.asId = uid 'gkas'
		self.outsideHandler = do(e) self.handleOutside(e)
		self.keyHandler = do(e) if e.key == 'Escape' then self.requestClose!
		if open
			present!

	def unmount
		dismissAll!

	def openDidSet value
		if value then present! else dismissSoft!

	def actionsList
		let list = typeof actions == 'string' ? JSON.parse(actions or '[]') : actions
		list or []

	def present
		if self.glassHandle == null
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 16),
				namespace: 'sheets'
				glassId: 'actionsheet:' + self.asId
				transition: 'matchedGeometry'
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

	def requestClose
		self.dispatchEvent new CustomEvent 'close', {bubbles: yes}

	def handleOutside e
		if self.contains(e.target) == no
			requestClose!

	def resolvedAnchor
		if anchorel == null then return null
		if typeof anchorel == 'string' then return globalThis.document.querySelector anchorel
		anchorel

	def position
		globalThis.requestAnimationFrame do
			let a = resolvedAnchor!
			let mr = self.getBoundingClientRect!
			let vw = globalThis.window.innerWidth
			let vh = globalThis.window.innerHeight
			let x = (vw - mr.width) / 2
			let y = vh - mr.height - 16
			if a != null
				let ar = a.getBoundingClientRect!
				x = clamp ar.left + ar.width / 2 - mr.width / 2, 8, Math.max(8, vw - mr.width - 8)
				y = ar.bottom + 8
				if y + mr.height > vh - 8
					y = ar.top - mr.height - 8
			self.style.left = "{Math.round(x)}px"
			self.style.top = "{Math.round(y)}px"

	def runAction action, index
		self.dispatchEvent new CustomEvent 'select', {bubbles: yes, detail: {index: index, action: action}}
		if action.autoClose != no
			requestClose!

	def render
		<self role='menu' aria-label=label style=(open ? '' : 'display:none')>
			for action, i in actionsList!
				<gk-button role='menuitem' tabindex='0' data-style=(action.destructive ? 'glassProminentClear' : 'glassClear') tint=(action.destructive ? '#d93a34' : null)
					@click=(do runAction(action, i))>
					action.title
