import {preferences} from './preferences'
import {isBrowser} from '../core/env'
import {dirtyTracker} from '../core/dirty-tracker'

export class FocusRingManager
	def constructor
		self.width = 3
		self.color = [0.22, 0.5, 0.95, 0.95]
		self.attached = no

	def attach
		if self.attached or !isBrowser
			return
		self.attached = yes
		globalThis.document.addEventListener 'keydown', do(e)
			if e.key == 'Tab'
				globalThis.document.documentElement.setAttribute 'data-gk-keyboard-focus', '1'
		globalThis.document.addEventListener 'pointerdown', do
			globalThis.document.documentElement.removeAttribute 'data-gk-keyboard-focus'
		preferences.subscribe do(p)
			self.width = if p.increaseContrast then 4 else 3
			dirtyTracker.markAll!

	get ringWidth
		if preferences.increaseContrast then 4 else 3

	def focusColor
		if preferences.forcedColors
			return [0, 0.47, 1, 1]
		self.color

export const focusRing = new FocusRingManager
