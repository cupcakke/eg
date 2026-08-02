import {registry} from '../material/glass-registry'
import {preferences} from '../a11y/preferences'
import {settings} from '../core/settings'
import {isBrowser} from '../core/env'
import {bus} from '../core/event-bus'
import {dirtyTracker} from '../core/dirty-tracker'

export class CssFallbackRenderer
	def constructor
		self.running = no
		self.unsubscribers = []
		self.rafHandle = null
		self.edgeBands = new Map
		self.bgExtensions = new Map

	def start renderer
		unless isBrowser
			return
		self.running = yes
		globalThis.document.documentElement.setAttribute 'data-gk-renderer-mode', 'css'
		self.unsubscribers.push bus.on('registry:changed', do self.syncAll!)
		self.unsubscribers.push preferences.subscribe do self.syncAll!
		self.unsubscribers.push settings.subscribe do self.syncAll!
		let w = globalThis.window
		self.onScroll = do self.requestSync!
		w.addEventListener 'scroll', self.onScroll, {capture: yes, passive: yes}
		syncAll!

	def requestSync
		if self.rafHandle == null
			self.rafHandle = globalThis.requestAnimationFrame do
				self.rafHandle = null
				self.syncAll!

	def syncAll
		unless self.running
			return
		for entry in registry.entries
			syncEntry entry

	def syncEntry entry
		let el = entry.element
		let d = entry.cssDescriptor
		el.setAttribute 'data-gk-cf-glass', d.variant
		el.style.setProperty '--gk-cf-blur', d.blur
		el.style.setProperty '--gk-cf-tint', d.tintCss
		el.style.setProperty '--gk-cf-tint-strength', d.tintStrength
		el.style.setProperty '--gk-cf-radii', d.radiiCss
		el.style.setProperty '--gk-cf-dimming', d.dimming
		el.style.setProperty '--gk-cf-shadow', d.shadowCss
		el.style.setProperty '--gk-cf-border-alpha', d.borderAlpha
		if d.interactive and !entry.fallbackInteractiveBound
			entry.fallbackInteractiveBound = yes
			bindFallbackInteraction entry

	def bindFallbackInteraction entry
		let el = entry.element
		el.addEventListener 'pointerdown', do
			el.setAttribute 'data-gk-cf-pressed', '1'
		el.addEventListener 'pointerup', do
			el.removeAttribute 'data-gk-cf-pressed'
		el.addEventListener 'pointercancel', do
			el.removeAttribute 'data-gk-cf-pressed'
		el.addEventListener 'pointerenter', do
			el.setAttribute 'data-gk-cf-hover', '1'
		el.addEventListener 'pointerleave', do
			el.removeAttribute 'data-gk-cf-hover'

	def syncEdgeEffect effect, barEl
		if barEl == null
			return
		let id = effect.id
		if !self.edgeBands.has(id)
			let band = globalThis.document.createElement 'div'
			band.setAttribute 'data-gk-cf-edge-band', effect.edge
			barEl.appendChild band
			self.edgeBands.set id, band
		let band = self.edgeBands.get id
		band.style.setProperty '--gk-cf-edge-strength', String(effect.strength)
		band.setAttribute 'data-gk-cf-edge-style', effect.style

	def stop
		self.running = no
		if isBrowser
			globalThis.document.documentElement.removeAttribute 'data-gk-renderer-mode'
			globalThis.window.removeEventListener 'scroll', self.onScroll, {capture: yes}
		for entry in registry.entries
			cleanupEntry entry
		self.edgeBands.forEach do(band)
			if band.parentNode
				band.parentNode.removeChild band
		self.edgeBands.clear
		self.bgExtensions.clear
		for unsub in self.unsubscribers
			unsub!
		self.unsubscribers = []

	def cleanupEntry entry
		let el = entry.element
		el.removeAttribute 'data-gk-cf-glass'
		for prop in ['--gk-cf-blur', '--gk-cf-tint', '--gk-cf-tint-strength', '--gk-cf-radii', '--gk-cf-dimming', '--gk-cf-shadow', '--gk-cf-border-alpha']
			el.style.removeProperty prop
