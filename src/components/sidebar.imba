import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {BackgroundExtension} from '../index'
import {preferences} from '../a11y/preferences'
import {clamp} from '../core/math'
import {uid} from '../core/id'

tag gk-sidebar
	prop items = []
	prop selected = null
	prop collapsible = yes
	prop resizable = yes
	prop label = 'Sidebar'
	prop bgExtensionOf = null
	prop minWidth = 180
	prop maxWidth = 420

	def mount
		self.__gkOwnsGlassSurface = yes
		self.collapsed = no
		self.width = 260
		self.barId = uid 'gksb'
		self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 0),
			namespace: 'sidebar'
			glassId: 'sidebar:' + self.barId
			transition: 'materialize'
		if bgExtensionOf != null
			bindBackgroundExtension!

	def unmount
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null
		if self.bgExtensionHandle
			self.bgExtensionHandle.dispose!
			self.bgExtensionHandle = null

	def bindBackgroundExtension
		let target = globalThis.document.querySelector bgExtensionOf
		if target
			self.bgExtensionHandle = applyBackgroundExtension target, [if preferences.dir == 'rtl' then 'trailing' else 'leading']

	def groupsList
		let list = typeof items == 'string' ? JSON.parse(items or '[]') : items
		list or []

	def keyOnItem e, id
		if e.key == 'Enter' or e.key == ' '
			e.preventDefault!
			selectItem id

	def selectItem id
		if selected != id
			selected = id
			self.dispatchEvent new CustomEvent 'change', {bubbles: yes, detail: {selected: id}}

	def toggle
		if collapsible == no
			return
		self.collapsed = !self.collapsed
		if self.collapsed
			self.setAttribute 'data-collapsed', '1'
			self.style.width = '0px'
		else
			self.removeAttribute 'data-collapsed'
			self.style.width = "{self.width}px"
		self.dispatchEvent new CustomEvent 'toggle', {bubbles: yes, detail: {collapsed: self.collapsed}}

	def onResizeStart e
		unless resizable
			return
		e.preventDefault!
		let startX = e.clientX
		let startW = self.getBoundingClientRect!.width
		let move = do(ev)
			let delta = ev.clientX - startX
			if preferences.dir == 'rtl'
				delta = -delta
			self.width = clamp startW + delta, (Number(minWidth) or 180), (Number(maxWidth) or 420)
			self.style.width = "{self.width.toFixed(1)}px"
			self.dispatchEvent new CustomEvent 'resize', {bubbles: yes, detail: {width: self.width}}
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def render
		let groups = groupsList!
		<self role='navigation' aria-label=label>
			for group, gi in groups
				if group.label
					<div .gk-group-label role='presentation'> group.label
				for item in group.items or []
					<div .gk-item role='link' tabindex='0'
						aria-current=(selected == item.id ? 'true' : null)
						aria-selected=(selected == item.id ? 'true' : 'false')
						@click=(do selectItem(item.id))
						@keydown=(do self.keyOnItem(e, item.id))>
						if item.icon
							<gk-icon name=item.icon>
						<span> item.label
			if resizable
				<div .gk-resize-handle role='separator' aria-orientation='vertical' tabindex='0' @pointerdown=onResizeStart>
