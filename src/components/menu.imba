import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {actionInfo} from './icon'
import {RovingGroup} from '../a11y/keyboard-nav'
import {preferences} from '../a11y/preferences'
import {uid} from '../core/id'
import {clamp} from '../core/math'

tag gk-menu
	prop items = []
	prop anchorel = null
	prop selected = -1
	prop placement = 'bottom'
	prop glassId = null
	prop depth = 0

	def mount
		self.__gkOwnsGlassSurface = yes
		self.menuId = uid 'gkm'
		self.openSubmenu = -1
		self.outsideHandler = do(e) self.handleOutside(e)
		self.glassHandle = applyGlassEffect self, Glass.regular.interactive(no), Shape.rect(cornerRadius: 14),
			namespace: 'menus'
			glassId: glassId or ('menu:' + self.menuId)
			transition: 'matchedGeometry'
		self.group = new RovingGroup self, '[data-gk-mi]', {orientation: 'vertical', onActivate: do(el) self.activateIndex(Number(el.getAttribute('data-gk-mi')))}
		positionMenu!
		globalThis.document.addEventListener 'pointerdown', self.outsideHandler, yes
		globalThis.setTimeout (do self.group.attach!), 0

	def unmount
		globalThis.document.removeEventListener 'pointerdown', self.outsideHandler, yes
		self.group.detach!
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def itemsList
		let list = typeof items == 'string' ? JSON.parse(items or '[]') : items
		list or []

	def anchor
		if anchorel == null
			return null
		if typeof anchorel == 'string'
			return globalThis.document.querySelector anchorel
		anchorel

	def positionMenu
		globalThis.requestAnimationFrame do
			let a = anchor!
			let vw = globalThis.window.innerWidth
			let vh = globalThis.window.innerHeight
			let mr = self.getBoundingClientRect!
			let x = 0
			let y = 0
			if a == null
				x = (vw - mr.width) / 2
				y = (vh - mr.height) / 2
			else
				let ar = a.getBoundingClientRect!
				if placement == 'right'
					x = ar.right + 6
					y = ar.top - 4
					if x + mr.width > vw - 8 then x = ar.left - mr.width - 6
				else
					x = ar.left
					y = ar.bottom + 6
					if y + mr.height > vh - 8
						y = ar.top - mr.height - 6
					if mr.width < ar.width
						x = ar.left
				x = clamp x, 8, Math.max(8, vw - mr.width - 8)
				y = clamp y, 8, Math.max(8, vh - mr.height - 8)
			self.style.left = "{Math.round(x)}px"
			self.style.top = "{Math.round(y)}px"

	def handleOutside e
		if self.contains(e.target) == no
			closeAll!

	def closeAll
		self.dispatchEvent new CustomEvent 'close', {bubbles: yes}

	def menuItemClicked i
		activateIndex i

	def menuItemEntered item, i
		if item.submenu != null
			openSubmenuAt i

	def activateIndex i
		let list = itemsList!
		let item = list[i]
		if item == null or item.disabled
			return
		if item.submenu != null
			openSubmenuAt i
			return
		self.dispatchEvent new CustomEvent 'select', {bubbles: yes, detail: {index: i, item: item}}
		closeAll!

	def openSubmenuAt i
		self.openSubmenu = i
		imba.commit!

	def onKeydown e
		let fwd = if preferences.dir == 'rtl' then 'ArrowLeft' else 'ArrowRight'
		let bck = if preferences.dir == 'rtl' then 'ArrowRight' else 'ArrowLeft'
		if e.key == fwd
			let list = itemsList!
			let idx = focusedIndex!
			if idx >= 0 and list[idx] and list[idx].submenu != null
				e.preventDefault!
				openSubmenuAt idx
		elif e.key == bck and depth > 0
			e.preventDefault!
			closeAll!
		elif e.key == 'Escape'
			e.preventDefault!
			closeAll!

	def focusedIndex
		let el = globalThis.document.activeElement
		if el == null then return -1
		let host = el.closest '[data-gk-mi]'
		if host == null then return -1
		Number host.getAttribute 'data-gk-mi'

	def render
		let list = itemsList!
		<self role='menu' aria-label='Menu' @keydown=onKeydown>
			for item, i in list
				if item.separator
					<div .gk-separator role='separator'>
				else
					let info = item.action != null ? actionInfo(item.action) : null
					let title = item.title or (info ? info.title : String(item))
					let icon = item.icon or (info ? info.icon : null)
					<button data-gk-mi=i role='menuitem'
						aria-disabled=(item.disabled ? 'true' : null)
						aria-haspopup=(item.submenu != null ? 'menu' : null)
						data-destructive=((item.destructive or (info ? info.destructive : no)) ? '1' : null)
						data-checked=(item.checked ? '1' : null)
						data-submenu=(item.submenu != null ? '1' : null)
						tabindex='-1'
						@click=(do self.menuItemClicked(i))
						@pointerenter=(do self.menuItemEntered(item, i))>
						if item.checked
							<svg viewBox='0 0 24 24' width='16' height='16' style="flex:none;">
								<path d='M5 12.8l4.5 4.5L19 7.8' fill='none' stroke='currentColor' stroke-width='2.2' stroke-linecap='round'>
						else
							<span style="width:16px;flex:none;">
						if icon
							<gk-icon name=icon scale='small'>
						<span style="flex:1;text-align:start;"> title
						if item.shortcut
							<span .gk-shortcut aria-hidden='yes'> "⌘{item.shortcut}"
						if item.submenu != null
							<gk-icon name=(preferences.dir == 'rtl' ? 'chevron-left' : 'chevron-right') scale='small'>
					if self.openSubmenu == i and item.submenu != null
						<gk-menu items=item.submenu depth=(depth + 1) placement='right' anchorel=(self.querySelector("[data-gk-mi='{i}']")) @close=(do self.dispatchEvent(new CustomEvent('close', {bubbles: yes})))>
