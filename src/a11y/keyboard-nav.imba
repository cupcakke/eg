import {preferences} from './preferences'
import {isBrowser} from '../core/env'

export class RovingGroup
	def constructor container, selector, opts = {}
		self.container = container
		self.selector = selector
		self.orientation = opts.orientation or 'horizontal'
		self.wrap = opts.wrap !== no
		self.onActivate = opts.onActivate or null
		self.keydown = do(e) self.handleKey(e)
		self.attached = no

	def attach
		unless self.attached
			self.attached = yes
			self.container.addEventListener 'keydown', self.keydown
			updateTabstops!

	def detach
		if self.attached
			self.attached = no
			self.container.removeEventListener 'keydown', self.keydown

	def items
		let nodes = self.container.querySelectorAll self.selector
		let out = []
		if nodes
			for i in [0 ... nodes.length]
				let el = nodes[i]
				if el.getAttribute('aria-disabled') != 'true' and el.hasAttribute('disabled') == no
					out.push el
		out

	def updateTabstops activeEl = null
		let list = items!
		if list.length == 0
			return
		let current = activeEl
		if current == null
			for el in list
				if el.tabIndex == 0
					current = el
		if current == null
			current = list[0]
		for el in list
			el.tabIndex = (if el == current then 0 else -1)

	def handleKey e
		let list = items!
		if list.length == 0
			return
		let horizontal = self.orientation == 'horizontal' or self.orientation == 'both'
		let vertical = self.orientation == 'vertical' or self.orientation == 'both'
		let index = list.indexOf globalThis.document.activeElement
		let next = -1
		let forwardKey = if preferences.dir == 'rtl' then 'ArrowLeft' else 'ArrowRight'
		let backKey = if preferences.dir == 'rtl' then 'ArrowRight' else 'ArrowLeft'
		if horizontal and e.key == forwardKey then next = index + 1
		elif horizontal and e.key == backKey then next = index - 1
		elif vertical and e.key == 'ArrowDown' then next = index + 1
		elif vertical and e.key == 'ArrowUp' then next = index - 1
		elif e.key == 'Home' then next = 0
		elif e.key == 'End' then next = list.length - 1
		elif (e.key == 'Enter' or e.key == ' ') and index >= 0
			if self.onActivate
				e.preventDefault!
				self.onActivate list[index]
			return
		else
			return
		e.preventDefault!
		if self.wrap
			next = ((next % list.length) + list.length) % list.length
		else
			next = Math.max(0, Math.min(list.length - 1, next))
		let target = list[next]
		updateTabstops target
		target.focus!

export class FocusTrap
	def constructor container, opts = {}
		self.container = container
		self.onEscape = opts.onEscape or null
		self.restoreTo = null
		self.keydown = do(e) self.handleKey(e)
		self.active = no

	def activate
		if self.active
			return
		self.active = yes
		if globalThis.document
			self.restoreTo = globalThis.document.activeElement
			globalThis.document.addEventListener 'keydown', self.keydown, yes
			let first = firstFocusable!
			if first
				first.focus!
			elif self.container.focus
				self.container.tabIndex = -1
				self.container.focus!

	def deactivate
		unless self.active
			return
		self.active = no
		if globalThis.document
			globalThis.document.removeEventListener 'keydown', self.keydown, yes
		if self.restoreTo and self.restoreTo.focus
			self.restoreTo.focus!

	def focusables
		let out = []
		let nodes = self.container.querySelectorAll 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
		if nodes
			for i in [0 ... nodes.length]
				out.push nodes[i]
		out

	def firstFocusable
		let list = focusables!
		if list.length > 0 then list[0] else null

	def handleKey e
		if e.key == 'Escape'
			if self.onEscape
				e.stopPropagation!
				self.onEscape!
			return
		if e.key != 'Tab'
			return
		let list = focusables!
		if list.length == 0
			e.preventDefault!
			return
		let active = globalThis.document.activeElement
		let idx = list.indexOf active
		let next = 0
		if e.shiftKey
			next = idx <= 0 ? list.length - 1 : idx - 1
		else
			next = idx >= list.length - 1 ? 0 : idx + 1
		if idx < 0
			next = 0
		e.preventDefault!
		list[next].focus!
