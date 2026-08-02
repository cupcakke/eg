import {logger} from '../core/logger'
import {uid} from '../core/id'

tag gk-form
	prop columns = 'auto'
	prop labelWidth = null

	def mount
		if labelWidth != null
			self.style.setProperty '--gk-form-label-width', "{labelWidth}px"

	def render
		<self role='form' data-columns=columns>
			<slot>

tag gk-form-row
	prop label = ''
	prop hint = ''
	prop align = 'leading'

	def mountControl
		globalThis.setTimeout (do self.wireLabel!), 0

	def wireLabel
		let nodes = self.querySelectorAll 'input, select, textarea, gk-slider, gk-toggle, gk-stepper, gk-segmented-control, [tabindex]'
		if nodes != null and nodes.length > 0
			let control = nodes[0]
			control.setAttribute 'aria-labelledby', self.labelId
			if hint != ''
				control.setAttribute 'aria-describedby', self.hintId

	def mount
		self.labelId = uid 'gkfl'
		self.hintId = uid 'gkfh'
		if label == ''
			logger.warnOnce 'form-row-nolabel', 'gk-form-row requires a label to pair label and control accessibly'
		mountControl!

	def render
		<self .gk-form-row data-align=align>
			<label .gk-form-label id=self.labelId> label
			<div .gk-form-control>
				<slot>
			if hint != ''
				<div .gk-form-hint id=self.hintId> hint
