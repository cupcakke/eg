import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {FocusTrap} from '../a11y/keyboard-nav'
import {announce} from '../a11y/aria'
import {uid} from '../core/id'

tag gk-alert
	prop title = ''
	prop message = ''
	prop actions = []
	prop open = no @watch

	def mount
		self.__gkOwnsGlassSurface = yes
		self.alertId = uid 'gkalert'
		self.trap = null
		if open
			present!

	def unmount
		dismissAll!

	def openDidSet value
		if value then present! else dismissAll!

	def actionsList
		let list = typeof actions == 'string' ? JSON.parse(actions or '[]') : actions
		let result = (list or []).slice(0, 3)
		if result.length == 0
			result.push {title: 'OK', role: 'cancel'}
		result

	def present
		if self.glassHandle == null
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.rect(cornerRadius: 20),
				namespace: 'alerts'
				transition: 'materialize'
		self.trap = new FocusTrap self, {onEscape: do self.triggerAction(-1)}
		self.trap.activate!
		announce title

	def dismissAll
		if self.trap
			self.trap.deactivate!
			self.trap = null
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def alertKey e
		if e.key == 'Escape'
			e.preventDefault!
			triggerAction -1

	def triggerAction index
		let list = actionsList!
		let action = if index < 0 then list.find(do(a) a.role == 'cancel') else list[index]
		self.dispatchEvent new CustomEvent 'close', {bubbles: yes, detail: {action: (action ? action.title : null), index: index}}

	def render
		let list = actionsList!
		<self role='alertdialog' aria-modal='true' aria-label=title style=(open ? '' : 'display:none') @keydown=(do self.alertKey(e))>
			<div .gk-title> title
			if message != ''
				<div .gk-message> message
			<div .gk-actions>
				for action, i in list
					<button data-role=(action.role or null) @click=(do triggerAction(i))>
						action.title
