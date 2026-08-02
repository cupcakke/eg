import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {logger} from '../core/logger'

tag gk-toolbar-group
	prop gap = 2
	prop glass = yes

	def mount
		if glass
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 12),
				namespace: 'toolbar'
				transition: 'materialize'
		checkItemMix!

	def unmount
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def checkItemMix
		globalThis.setTimeout (do
			let hasIconOnly = no
			let hasText = no
			for child in self.querySelectorAll 'gk-toolbar-item'
				let btn = child.querySelector 'button[data-icon-only]'
				if btn != null and btn.getAttribute('data-icon-only') == '1'
					hasIconOnly = yes
				else
					hasText = yes
			if hasIconOnly and hasText
				logger.warnOnce "toolbar-mix:{self.tagName}", 'A toolbar group with a shared glass background mixes text-labeled and icon-only items. Use either all icon-only or all text-labeled items inside one gk-toolbar-group.'
		), 60

	<self role='group' style="gap:{Number(gap) or 2}px">
		<slot>
