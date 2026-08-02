import {logger} from '../core/logger'
import {setPressed} from '../a11y/aria'

tag gk-toolbar-item
	prop icon = null
	prop iconOnly = no
	prop label = ''
	prop pressed = null
	prop disabled = no
	prop action = null

	def mount
		if (iconOnly or (icon != null and label == ''))
			let ariaName = label or self.getAttribute('aria-label')
			logger.require ariaName != null and ariaName != '',
				"An icon-only gk-toolbar-item requires an accessibility label at construction — pass label='...' or aria-label='...'"

	def activate e
		if disabled
			return
		if pressed != null
			pressed = !pressed
		self.dispatchEvent new CustomEvent 'activate', {bubbles: yes, detail: {action: action, pressed: pressed, source: self}}

	def render
		let only = iconOnly or (icon != null and label == '')
		<self>
			<button role=(pressed != null ? 'button' : 'button')
				aria-label=(only ? (label or icon) : null)
				aria-pressed=(pressed != null ? (pressed ? 'true' : 'false') : null)
				aria-disabled=(disabled ? 'true' : null)
				data-icon-only=(only ? '1' : null)
				@click=activate>
				if icon != null
					<gk-icon name=icon label=(only ? null : null)>
				if only == no and label != ''
					<span> label
				<slot>
