import {applyGlassEffect, removeGlassEffect, GlassEffectHandle} from '../material/glass-effect'
import {buttonGlassFor, buttonShapeFor, isGlassButtonStyle} from './button-styles'
import {logger} from '../core/logger'
import {announce} from '../a11y/aria'

tag gk-button
	prop label = ''
	prop variant = 'bordered'
	prop size = 'regular'
	prop icon = null
	prop trailingIcon = null
	prop loading = no
	prop disabled = no
	prop tint = null
	prop glassId = null
	prop glassNamespace = 'buttons'

	def mount
		refreshGlass!
		if icon != null and trailingIcon == null and label == '' and self.textContent.trim! == ''
			let ariaName = self.getAttribute 'aria-label'
			logger.require ariaName != null and ariaName != '', "An icon-only gk-button requires an accessibility label — set aria-label or the label attribute on <{self.tagName.toLowerCase()}>"

	def unmount
		releaseGlass!

	def refreshGlass
		let glass = buttonGlassFor variant, tint
		if glass == null
			releaseGlass!
			return
		let shape = buttonShapeFor variant
		self.glassHandle = applyGlassEffect self, glass.interactive(yes), shape,
			namespace: glassNamespace or 'buttons'
			glassId: glassId
			transition: 'materialize'

	def releaseGlass
		if self.glassHandle != null
			self.glassHandle.dispose!
			self.glassHandle = null

	def variantDidSet value
		if self.glassHandle != null or isGlassButtonStyle(value)
			releaseGlass!
			refreshGlass!

	def activate e
		if disabled or loading
			if e and e.preventDefault
				e.preventDefault!
				e.stopPropagation!
			return no
		let ev = new CustomEvent 'activate', {bubbles: yes, detail: {source: self}}
		self.dispatchEvent ev
		yes

	def onKeydown e
		if e.key == 'Enter' or e.key == ' '
			e.preventDefault!
			activate e

	def render
		let iconOnly = icon != null and trailingIcon == null and label == ''
		<self role='button'
			tabindex=(disabled ? -1 : 0)
			aria-disabled=(disabled ? 'true' : null)
			aria-busy=(loading ? 'true' : null)
			data-size=size
			data-style=variant
			data-loading=(loading ? '1' : null)
			@keydown=onKeydown
			@click=activate>
			if loading
				<span .gk-spinner aria-hidden='yes'>
			elif icon != null
				<gk-icon name=icon>
			<slot>
			if label != ''
				<span> label
			if trailingIcon != null and loading == no
				<gk-icon name=trailingIcon>
