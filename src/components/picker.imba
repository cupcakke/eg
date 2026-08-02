import {RovingGroup} from '../a11y/keyboard-nav'
import {setExpanded, announce} from '../a11y/aria'
import {clamp} from '../core/math'
import {uid} from '../core/id'

tag gk-picker
	prop items = []
	prop selected = 0
	prop kind = 'menu'
	prop label = 'Picker'
	prop placeholder = 'Select'

	def mount
		self.open = no
		self.wheelTimer = null
		if kind == 'inline'
			self.rovingGroup = new RovingGroup self, '[data-gk-inline-item]', {orientation: 'horizontal', onActivate: do(el) self.pickAttr(el)}
			self.rovingGroup.attach!

	def unmount
		if self.rovingGroup
			self.rovingGroup.detach!

	def itemsList
		if typeof items == 'string'
			items.split(',').map do(s) s.trim!
		else
			items

	def pickAttr el
		let idx = Number el.getAttribute('data-gk-inline-item')
		if Number.isFinite idx
			pick idx

	def pick i
		let list = itemsList!
		if i < 0 or i >= list.length
			return
		if selected != i
			selected = i
			let ev = new CustomEvent 'change', {bubbles: yes, detail: {index: i, value: list[i]}}
			self.dispatchEvent ev
		if kind == 'menu'
			closeMenu!

	def openMenu
		self.open = yes
		setExpanded self, yes
		let menu = self.querySelector 'gk-menu'

	def closeMenu
		self.open = no
		setExpanded self, no

	def toggleMenu
		if self.open then closeMenu! else openMenu!

	def onButtonKey e
		if e.key == 'ArrowDown' or e.key == 'Enter' or e.key == ' '
			e.preventDefault!
			openMenu!

	def onMenuSelect e
		pick e.detail.index

	def onWheelScroll e
		if kind != 'wheel'
			return
		let el = e.currentTarget
		if self.wheelTimer
			globalThis.clearTimeout self.wheelTimer
		self.wheelTimer = globalThis.setTimeout (do
			let itemH = 32
			let idx = clamp Math.round(el.scrollTop / itemH), 0, itemsList!.length - 1
			pick idx
			el.scrollTop = idx * itemH
		), 140

	def render
		let list = itemsList!
		let current = list[selected] or placeholder
		if kind == 'segmented'
			<self>
				<gk-segmented-control items=list selected=selected label=label @change=(do(e) pick(e.detail.index))>
		elif kind == 'inline'
			<self role='radiogroup' aria-label=label>
				for item, i in list
					<button data-gk-inline-item=i role='radio' aria-checked=(i == selected ? 'true' : 'false') tabindex=(i == selected ? 0 : -1) @click=(do pick(i))>
						item
		elif kind == 'wheel'
			<self role='listbox' aria-label=label>
				<div style="max-height:160px;overflow-y:auto;scroll-snap-type:y mandatory;" @scroll=onWheelScroll>
					for item, i in list
						<div role='option' aria-selected=(i == selected ? 'true' : 'false') data-selected=(i == selected ? '1' : null)
							style="height:32px;display:flex;align-items:center;justify-content:center;scroll-snap-align:center;font-weight:{i == selected ? 600 : 400};"
							@click=(do pick(i))>
							item
		else
			<self>
				<button aria-haspopup='menu' aria-expanded=(self.open ? 'true' : 'false') @click=toggleMenu @keydown=onButtonKey style="display:inline-flex;align-items:center;gap:8px;color:inherit;font:inherit;">
					<span> current
					<gk-icon .gk-chevron name='chevron-down' scale='small'>
				if self.open
					<gk-menu anchorel=self items=list selected=selected @select=onMenuSelect @close=closeMenu>
