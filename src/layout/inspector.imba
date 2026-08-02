import {uid} from '../core/id'
import {bus} from '../core/event-bus'

export class InspectorModel
	def constructor el
		self.id = uid 'gkin'
		self.el = el
		self.collapsed = no
		self.width = 260

	def toggle
		self.collapsed = !self.collapsed
		applyState!
		bus.emit 'inspector:toggled', {id: self.id, collapsed: self.collapsed}

	def applyState
		if self.collapsed
			self.el.setAttribute 'data-gk-collapsed', '1'
		else
			self.el.removeAttribute 'data-gk-collapsed'

	def setWidth w
		self.width = Math.max 200, w
		self.el.style.width = "{self.width.toFixed(1)}px"

tag gk-inspector
	prop title = 'Inspector'

	def mount
		self.inspectorModel = new InspectorModel self
		self.setAttribute 'data-gk-inspector', ''
		self.setAttribute 'role', 'complementary'
		if title
			self.setAttribute 'aria-label', title

	def unmount
		self.inspectorModel = null

	get model
		self.inspectorModel

	<self>
		<div data-gk-inspector-header>
			<span> title
			<slot name='actions'>
		<div data-gk-inspector-body>
			<slot>
