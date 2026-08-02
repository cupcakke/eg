import {ResizeController, collapseColumns} from './resize-controller'
import {uid} from '../core/id'
import {preferences} from '../a11y/preferences'
import {clamp} from '../core/math'

export class SplitViewModel
	def constructor el, opts = {}
		self.id = uid 'gksv'
		self.el = el
		self.columns = []
		self.controller = null
		self.handles = []
		self.collapsed = []
		self.activeWidths = []
		self.collapseMode = no

	def configure columns
		self.columns = columns
		self.controller = new ResizeController columns: columns
		compute!

	def compute
		let total = self.el.clientWidth or 1024
		let result = collapseColumns total, self.columns, 9
		self.activeWidths = result.widths
		self.collapsed = result.collapsed
		self.collapseMode = result.collapsed.length > 0
		{active: result.active, collapsed: result.collapsed, widths: result.widths}

tag gk-pane
	prop minWidth = 160
	prop priority = 1
	prop collapsible = yes

	def mount
		self.setAttribute 'data-gk-pane', ''
		self.style.setProperty '--gk-pane-min-width', "{Number(minWidth) or 160}px"

	<self>
		<slot>

tag gk-split-view
	prop columns = 2
	prop showInspector = no

	def mount
		self.splitModel = new SplitViewModel self
		self.resizeObserver = new globalThis.ResizeObserver do self.layout!
		self.resizeObserver.observe self
		layout!

	def unmount
		if self.resizeObserver
			self.resizeObserver.disconnect!

	get model
		self.splitModel

	def paneMinWidthFor pane, index
		let minWidthAttr = pane.getAttribute('min-width') or pane.minWidth
		Number(minWidthAttr) or 160

	def layout
		let panes = []
		for child in self.children
			panes.push child
		let defs = []
		for i in [0 ... panes.length]
			let pane = panes[i]
			let stored = pane.__gkWidth or pane.getBoundingClientRect!.width or 220
			defs.push
				width: stored
				min: paneMinWidthFor(pane, i)
				priority: Number(pane.getAttribute('priority')) or (i + 1)
				collapsible: pane.getAttribute('collapsible') != 'no'
				flex: 1
				collapseBelow: Number(pane.getAttribute('collapse-below')) or 0
		if defs.length == 0
			return
		if self.splitModel.controller == null or self.splitModel.columns.length != defs.length
			self.splitModel.configure defs
		else
			for i in [0 ... defs.length]
				self.splitModel.columns[i].min = defs[i].min
				self.splitModel.columns[i].priority = defs[i].priority
			self.splitModel.columns = self.splitModel.columns.slice(0, defs.length)
			while self.splitModel.columns.length < defs.length
				self.splitModel.columns.push defs[self.splitModel.columns.length]
		let total = self.clientWidth or 1
		self.splitModel.controller.setTotal total
		let result = self.splitModel.compute!
		let w = result.widths
		let activeIdx = 0
		for i in [0 ... panes.length]
			let pane = panes[i]
			if i < w.length
				pane.style.width = "{w[i].toFixed(1)}px"
				pane.style.display = ''
			else
				pane.style.display = 'none'
		syncHandles panes, result

	def syncHandles panes, result
		let handles = self.querySelectorAll '[data-gk-split-handle]'
		let panesCount = panes.length
		for h in [0 ... handles.length]
			handles[h].__gkPaneIndex = h
		if handles.length == 0 and panesCount > 1
			buildHandles panes

	def buildHandles panes
		for i in [0 ... panes.length - 1]
			let handle = globalThis.document.createElement 'div'
			handle.setAttribute 'data-gk-split-handle', String(i)
			handle.setAttribute 'role', 'separator'
			handle.setAttribute 'aria-orientation', 'vertical'
			handle.setAttribute 'tabindex', '0'
			let idx = i
			handle.addEventListener 'pointerdown', do(e)
				e.preventDefault!
				let startX = e.clientX
				let panesHere = self.children
				let left = panesHere[idx]
				let startW = left.getBoundingClientRect!.width
				let move = do(ev)
					let delta = ev.clientX - startX
					if preferences.dir == 'rtl'
						delta = -delta
					if self.splitModel.controller
						self.splitModel.columns[idx].width = startW
						self.splitModel.controller.drag idx, delta
						applyWidth idx
				let up = do(ev)
					handle.removeEventListener 'pointermove', move
					handle.removeEventListener 'pointerup', up
					handle.removeEventListener 'pointercancel', up
				handle.addEventListener 'pointermove', move
				handle.addEventListener 'pointerup', up
				handle.addEventListener 'pointercancel', up
			handle.addEventListener 'keydown', do(e)
				if self.splitModel.controller == null
					return
				let delta = 0
				if e.key == 'ArrowLeft' then delta = -12
				if e.key == 'ArrowRight' then delta = 12
				if preferences.dir == 'rtl' then delta = -delta
				if delta != 0
					e.preventDefault!
					self.splitModel.controller.drag idx, delta
					applyWidth idx
			self.insertBefore handle, panes[i + 1]

	def applyWidth idx
		let panesHere = self.children
		let widths = self.splitModel.controller.widths
		if widths and widths[idx]
			panesHere[idx].style.width = "{widths[idx].toFixed(1)}px"

	<self>
		<slot>
