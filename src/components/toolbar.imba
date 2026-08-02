import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {uid} from '../core/id'

tag gk-toolbar
	prop label = 'Toolbar'
	prop glass = yes

	def mount
		self.__gkOwnsGlassSurface = yes
		self.overflowing = []
		self.overflowOpen = no
		if glass
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 16),
				namespace: 'toolbar'
				glassId: 'toolbar:' + uid('tb')
				transition: 'materialize'
		self.ro = new globalThis.ResizeObserver do self.checkOverflow!
		self.ro.observe self

	def unmount
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null
		if self.ro
			self.ro.disconnect!

	def checkOverflow
		let items = directItems!
		if items.length == 0
			return
		let hiddenCount = self.overflowing.length
		let avail = self.clientWidth - 64
		let used = 0
		let overflow = []
		for item in items
			item.style.display = ''
		globalThis.requestAnimationFrame do
			for item in items
				let w = item.getBoundingClientRect!.width + 2
				if used + w > avail
					overflow.push item
					item.style.display = 'none'
				else
					used += w
			let changed = overflow.length != self.overflowing.length
			self.overflowing = overflow
			if changed
				imba.commit!

	def directItems
		let out = []
		for child in self.children
			if child.tagName == 'GK-TOOLBAR-ITEM' or child.tagName == 'GK-TOOLBAR-GROUP'
				out.push child
		out

	def toggleOverflow
		self.overflowOpen = !self.overflowOpen
		imba.commit!

	def overflowMenuKey e
		if e.key == 'Escape'
			e.preventDefault!
			closeOverflow!

	def closeOverflow
		self.overflowOpen = no
		imba.commit!

	def onOverflowItemClick item, e
		let btn = item.querySelector 'button'
		if btn
			btn.click!
		closeOverflow!

	def render
		<self role='toolbar' aria-label=label>
			<slot>
			if self.overflowing.length > 0
				<button aria-label='More items' aria-haspopup='menu' aria-expanded=(self.overflowOpen ? 'true' : 'false') style="min-width:32px;height:32px;color:inherit;" @click=toggleOverflow>
					<gk-icon name='ellipsis'>
			if self.overflowOpen
				<div data-overflow-menu role='menu' @keydown=(do self.overflowMenuKey(e))>
					for item in self.overflowing
						<button role='menuitem' style="display:flex;align-items:center;gap:8px;padding:8px 12px;border-radius:8px;text-align:start;color:inherit;" @click=(do(e) onOverflowItemClick(item, e))>
							item.textContent.trim!
