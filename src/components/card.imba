import {applyGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {logger} from '../core/logger'

tag gk-card
	prop title = ''
	prop subtitle = ''
	prop glass = no
	prop tint = null
	prop interactive = no
	prop href = null
	prop padding = 'regular'

	def mount
		self.glassHandle = null
		refreshGlass!
		if glass and self.querySelector('[data-gk-media-layer]') != null
			logger.warnOnce 'card-media-over-glass', 'gk-card: place media outside the glass-treated container fill — content belongs to the content layer above glass, not merged into the material'

	def unmount
		releaseGlass!

	def refreshGlass
		unless glass
			return
		releaseGlass!
		let value = Glass.regular
		if tint != null
			value = value.tint tint, 0.32
		value = value.interactive interactive
		self.glassHandle = applyGlassEffect self, value, Shape.rect(cornerRadius: 16),
			namespace: 'cards'
			transition: 'materialize'

	def glassDidSet value
		if self.glassHandle == null
			refreshGlass!
		elif !value
			releaseGlass!

	def releaseGlass
		if self.glassHandle != null
			self.glassHandle.dispose!
			self.glassHandle = null

	def activate e
		if href != null
			let nav = new CustomEvent 'cardnavigate', {bubbles: yes, cancelable: yes, detail: {href: href}}
			self.dispatchEvent nav
			if nav.defaultPrevented == no
				globalThis.location.href = href

	def onKeydown e
		if (e.key == 'Enter' or e.key == ' ') and (href != null or interactive)
			e.preventDefault!
			activate e

	def render
		let linky = href != null
		<self role=(linky ? 'link' : 'group')
			tabindex=(linky or interactive ? 0 : null)
			data-interactive=(interactive ? '1' : null)
			data-padding=padding
			data-glass=(glass ? '1' : null)
			@click=activate
			@keydown=onKeydown>
			<slot name='media'>
			<div .gk-card-body>
				if title != ''
					<div .gk-card-title> title
				if subtitle != ''
					<div .gk-card-subtitle> subtitle
				<slot>
			<slot name='footer'>
