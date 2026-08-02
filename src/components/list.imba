import {logger} from '../core/logger'
import {RovingGroup} from '../a11y/keyboard-nav'

const ROW_SELECTOR = 'gk-list-row, [role="row"]'

tag gk-list
	prop style = 'inset'
	prop selection = 'single'
	prop value = null
	prop label = ''

	def mount
		self.values = parseValues value
		self.roving = null
		self.io = null
		setupRoving!

	def unmount
		if self.roving != null
			self.roving.detach!
			self.roving = null
		if self.io != null
			self.io.disconnect!
			self.io = null

	def setupRoving
		self.roving = new RovingGroup self, ROW_SELECTOR,
			orientation: 'vertical'
			wrap: no
			onActivate: do(el)
				if el.activate
					el.activate null
		self.roving.attach!
		if typeof globalThis.MutationObserver == 'function'
			self.io = new MutationObserver do(muts)
				if self.roving != null
					self.roving.updateTabstops!
			self.io.observe self, {childList: yes, subtree: yes}

	def parseValues raw
		if raw == null or raw == ''
			return []
		if Array.isArray raw
			return raw.slice 0
		String(raw).split(',').map do(s) s.trim!

	def syncSelection
		let rows = self.querySelectorAll ROW_SELECTOR
		for i in [0 ... rows.length]
			let row = rows[i]
			let v = if row.selectValue then row.selectValue! else row.getAttribute('value')
			let on = self.values.indexOf(v) >= 0
			row.selected = on

	def rowToggled e
		let detail = e.detail or {}
		let v = detail.value
		if selection == 'none'
			return
		e.stopPropagation!
		if selection == 'single'
			self.values = [v]
		else
			let at = self.values.indexOf v
			if at >= 0
				self.values.splice at, 1
			else
				self.values.push v
		syncSelection!
		value = selection == 'single' ? v : self.values.join(',')
		let ev = new CustomEvent 'selectionchange', {bubbles: no, detail: {value: value, values: self.values.slice(0)}}
		self.dispatchEvent ev

	def valueDidSet raw
		self.values = parseValues raw
		syncSelection!

	def render
		<self role='listbox'
			aria-label=(label != '' ? label : null)
			aria-multiselectable=(selection == 'multiple' ? 'true' : null)
			data-style=style
			data-selection=selection
			self.rowactivate=rowToggled>
			<slot>

tag gk-list-row-separator
	def render
		<self role='separator'>
