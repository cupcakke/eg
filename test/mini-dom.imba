let idCounter = 0

export def selectorMatch el, selector
	if selector == '*'
		return yes
	if selector.charAt(0) == '.'
		return el.classList.contains selector.slice(1)
	if selector.indexOf(',') >= 0
		for part in selector.split(',')
			if selectorMatch el, part.trim!
				return yes
		return no
	let m = /^\[data-([a-z0-9-]+)\]$/.exec selector
	if m
		return el.hasAttribute "data-{m[1]}"
	el.tagName == selector.toUpperCase!

export class FakeClassList
	def constructor el
		self.el = el

	def add cls
		let parts = self.el.attributes.class or ''
		let set = new Set parts.split(' ').filter do(p) p != ''
		set.add cls
		self.el.attributes.class = Array.from(set).join ' '

	def remove cls
		let parts = self.el.attributes.class or ''
		let set = new Set parts.split(' ').filter do(p) p != ''
		set.delete cls
		self.el.attributes.class = Array.from(set).join ' '

	def contains cls
		let parts = self.el.attributes.class or ''
		parts.split(' ').indexOf(cls) >= 0

export class FakeStyle
	def setProperty name, value
		self[name] = value

	def removeProperty name
		delete self[name]

	def getPropertyValue name
		self[name] or ''

export class FakeElement
	prop tagName

	def constructor tag = 'div'
		self.tagName = tag.toUpperCase!
		self.uid = 'fake-{idCounter += 1}'
		self.attributes = {}
		self.children = []
		self.parentNode = null
		self.listeners = {}
		self.rect = {left: 0, top: 0, width: 100, height: 40, right: 100, bottom: 40}
		self.style = new FakeStyle
		self.classList = new FakeClassList self
		self.tabIndex = 0
		self.textContent = ''
		self.focused = no
		self.removed = no

	get classListValue
		self.attributes.class or ''

	def setAttribute name, value
		self.attributes[name] = String value

	def getAttribute name
		if self.attributes.hasOwnProperty(name) then self.attributes[name] else null

	def hasAttribute name
		self.attributes.hasOwnProperty name

	def removeAttribute name
		delete self.attributes[name]

	def appendChild child
		child.parentNode = self
		self.children.push child
		child

	def removeChild child
		let i = self.children.indexOf child
		if i >= 0
			self.children.splice i, 1
			child.parentNode = null
		child

	def remove
		self.removed = yes
		if self.parentNode != null
			self.parentNode.removeChild self

	def addEventListener type, fn, opts = null
		let list = self.listeners[type]
		if list == null
			list = self.listeners[type] = []
		list.push fn

	def removeEventListener type, fn, opts = null
		let list = self.listeners[type]
		if list == null
			return
		let i = list.indexOf fn
		if i >= 0
			list.splice i, 1

	def listenerCount type
		let list = self.listeners[type]
		list == null ? 0 : list.length

	def totalListeners
		let total = 0
		for own type, list of self.listeners
			total += list.length
		total

	def dispatchEvent ev
		let list = self.listeners[ev.type]
		if list == null
			return yes
		for fn in list.slice(0)
			fn.call self, ev
		yes

	def getBoundingClientRect
		self.rect

	def setRect x, y, w, h
		self.rect = {left: x, top: y, width: w, height: h, right: x + w, bottom: y + h}
		self

	def focus
		self.focused = yes

	def blur
		self.focused = no

	def contains other
		let node = other
		while node != null
			if node == self
				return yes
			node = node.parentNode
		no

	def querySelectorAll selector
		let out = []
		let walk = do(node)
			for child in node.children
				if selectorMatch child, selector
					out.push child
				walk child
		walk self
		out

	def querySelector selector
		let all = querySelectorAll selector
		all.length > 0 ? all[0] : null

export def fakeEl tag = 'div', x = 10, y = 10, w = 100, h = 40
	let el = new FakeElement tag
	el.setRect x, y, w, h
	el

export def fakeEvent type, extra = {}
	let ev = {type: type, defaultPrevented: no, target: null}
	ev.preventDefault = do ev.defaultPrevented = yes
	ev.stopPropagation = do null
	for own k, v of extra
		ev[k] = v
	ev
