import {announce} from '../a11y/aria'
import {setExpanded} from '../a11y/aria'
import {uid} from '../core/id'
import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'

tag gk-text-field
	prop value = ''
	prop placeholder = ''
	prop label = 'Text field'
	prop suggestions = []
	prop glass = no
	prop disabled = no
	prop tokens = []

	def mount
		self.inputEl = null
		self.open = no
		self.activeIndex = -1
		self.listId = uid 'gkf'
		self.vViewport = null
		if glass
			self.glassHandle = applyGlassEffect self, Glass.regular.interactive(yes), Shape.rect(cornerRadius: 11),
				namespace: 'fields'
				transition: 'materialize'
		if typeof globalThis.visualViewport != 'undefined'
			self.vvResize = do self.avoidKeyboard!
			globalThis.visualViewport.addEventListener 'resize', self.vvResize

	def unmount
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null
		if typeof globalThis.visualViewport != 'undefined' and self.vvResize
			globalThis.visualViewport.removeEventListener 'resize', self.vvResize

	def suggestionsList
		if typeof suggestions == 'string'
			suggestions.split(',').map do(s) s.trim!
		else
			suggestions

	def tokensList
		if typeof tokens == 'string'
			(if tokens.length > 0 then tokens.split(',').map(do(s) s.trim!) else [])
		else
			tokens

	def matches
		let list = suggestionsList!
		let q = String(value).toLowerCase!
		if q.length == 0
			list
		else
			list.filter do(s) s.toLowerCase!.indexOf(q) >= 0

	def avoidKeyboard
		if self.focused != yes or typeof globalThis.visualViewport == 'undefined'
			return
		let vv = globalThis.visualViewport
		let r = self.getBoundingClientRect!
		let overlap = r.bottom - vv.height + 16
		if overlap > 0
			self.scrollIntoView {block: 'center', behavior: 'smooth'}
			let scroller = self.closest('gk-scroll-view') or self.parentElement
			if scroller and scroller.scrollBy
				scroller.scrollBy {top: overlap, behavior: 'smooth'}

	def onFocus e
		self.focused = yes
		if matches!.length > 0
			openList!

	def onBlur e
		self.focused = no
		globalThis.setTimeout (do closeList!), 120

	def openList
		self.open = yes
		self.activeIndex = -1
		setExpanded self, yes

	def closeList
		if self.open
			self.open = no
			setExpanded self, no

	def onInput e
		value = e.target.value
		openList!
		let ev = new CustomEvent 'input', {bubbles: yes, detail: {value: value}}
		self.dispatchEvent ev

	def commitFromPointer e, item
		e.preventDefault!
		commit item

	def commit v
		value = v
		closeList!
		let ev = new CustomEvent 'change', {bubbles: yes, detail: {value: v}}
		self.dispatchEvent ev
		if self.inputEl
			self.inputEl.focus!

	def onKeydown e
		let list = matches!
		if e.key == 'ArrowDown'
			e.preventDefault!
			openList!
			self.activeIndex = Math.min list.length - 1, self.activeIndex + 1
		elif e.key == 'ArrowUp'
			e.preventDefault!
			self.activeIndex = Math.max -1, self.activeIndex - 1
		elif e.key == 'Enter'
			if self.open and self.activeIndex >= 0 and list[self.activeIndex]
				e.preventDefault!
				commit list[self.activeIndex]
		elif e.key == 'Escape'
			if self.open
				e.preventDefault!
				closeList!
		elif e.key == 'Backspace' and String(value).length == 0 and tokensList!.length > 0
			removeToken tokensList!.length - 1

	def removeToken i
		let list = tokensList!.slice(0)
		list.splice i, 1
		tokens = list
		let ev = new CustomEvent 'tokenschange', {bubbles: yes, detail: {tokens: list}}
		self.dispatchEvent ev

	def render
		let list = matches!
		<self role='combobox' aria-haspopup='listbox' aria-expanded=(self.open ? 'true' : 'false') aria-owns=self.listId data-open=(self.open ? '1' : null)>
			if tokensList!.length > 0
				<span style="display:inline-flex;gap:4px;flex-wrap:wrap;">
					for token, i in tokensList!
						<span style="display:inline-flex;align-items:center;gap:4px;padding:2px 6px;border-radius:8px;background:var(--gk-fill);font-size:12px;">
							token
							<button aria-label="Remove {token}" style="color:var(--gk-text-secondary);" @click=(do removeToken(i))> '×'
			<input$inputEl type='text' value=value placeholder=placeholder aria-label=label aria-autocomplete='list' aria-controls=self.listId
				disabled=disabled
				@input=onInput @keydown=onKeydown @focus=onFocus @blur=onBlur>
			if self.open and list.length > 0
				<div .gk-suggestions role='listbox' id=self.listId aria-label='Suggestions'>
					for item, i in list
						<div role='option' aria-selected=(i == self.activeIndex ? 'true' : 'false') data-active=(i == self.activeIndex ? '1' : null)
							@pointerdown=(do self.commitFromPointer(e, item))>
							item
