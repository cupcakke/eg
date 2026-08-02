tag gk-context-menu
	prop items = []
	prop for = null
	prop target = null

	def mount
		self.open = no
		self.pointerPos = [0, 0]
		self.longPressTimer = null
		self.contextHandler = do(e) self.handleContext(e)
		self.pointerDownHandler = do(e) self.handlePointerDown(e)
		attachTarget!

	def unmount
		detachTarget!

	def attachTarget
		let t = resolvedTarget!
		if t
			t.addEventListener 'contextmenu', self.contextHandler
			t.addEventListener 'pointerdown', self.pointerDownHandler

	def detachTarget
		let t = resolvedTarget!
		if t
			t.removeEventListener 'contextmenu', self.contextHandler
			t.removeEventListener 'pointerdown', self.pointerDownHandler
		if self.longPressTimer
			globalThis.clearTimeout self.longPressTimer

	def resolvedTarget
		if target != null
			return target
		if self.for != null
			return globalThis.document.querySelector self.for
		self.parentElement

	def handleContext e
		e.preventDefault!
		openAt e.clientX, e.clientY

	def handlePointerDown e
		if e.pointerType == 'touch'
			self.longPressTimer = globalThis.setTimeout (do openAt(e.clientX, e.clientY)), 500
			let up = do
				if self.longPressTimer
					globalThis.clearTimeout self.longPressTimer
					self.longPressTimer = null
				globalThis.window.removeEventListener 'pointerup', up
				globalThis.window.removeEventListener 'pointercancel', up
			globalThis.window.addEventListener 'pointerup', up
			globalThis.window.addEventListener 'pointercancel', up

	def openAt x, y
		self.open = yes
		self.pointerPos = [x, y]
		imba.commit!
		globalThis.requestAnimationFrame do
			let menu = self.querySelector 'gk-menu'
			if menu
				let mr = menu.getBoundingClientRect!
				let vw = globalThis.window.innerWidth
				let vh = globalThis.window.innerHeight
				let px = self.pointerPos[0]
				let py = self.pointerPos[1]
				if px + mr.width > vw - 8 then px = vw - mr.width - 8
				if py + mr.height > vh - 8 then py = vh - mr.height - 8
				menu.style.left = "{Math.max(4, Math.round(px))}px"
				menu.style.top = "{Math.max(4, Math.round(py))}px"

	def closeMenu
		self.open = no
		imba.commit!

	def onSelect e
		closeMenu!
		self.dispatchEvent new CustomEvent 'select', {bubbles: yes, detail: e.detail}

	def render
		<self style="display:contents;">
			if self.open
				<gk-menu items=items @close=closeMenu @select=onSelect>
