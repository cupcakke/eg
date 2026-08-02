import {matchMedia, isBrowser} from '../core/env'
import {EventBus} from '../core/event-bus'

const QUERIES =
	reducedMotion: '(prefers-reduced-motion: reduce)'
	reducedTransparency: '(prefers-reduced-transparency: reduce)'
	increaseContrast: '(prefers-contrast: more)'
	forcedColors: '(forced-colors: active)'
	darkScheme: '(prefers-color-scheme: dark)'

export class Preferences
	prop reducedMotion
	prop reducedTransparency
	prop increaseContrast
	prop forcedColors
	prop darkScheme
	prop dir

	def constructor
		self.reducedMotion = no
		self.reducedTransparency = no
		self.increaseContrast = no
		self.forcedColors = no
		self.darkScheme = no
		self.dir = 'ltr'
		self.overrides = {}
		self.events = new EventBus
		self.mqls = {}
		if isBrowser
			detectInitial!
			attachListeners!

	def detectInitial
		let w = globalThis.window
		for own key, query of QUERIES
			let mq = matchMedia query
			if mq
				self.mqls[key] = mq
				applyMedia key, mq.matches
		let doc = globalThis.document
		if doc and doc.documentElement
			let d = doc.documentElement.getAttribute('dir') or doc.dir
			self.dir = if d == 'rtl' then 'rtl' else 'ltr'

	def attachListeners
		for own key, mq of self.mqls
			let handler = do(e)
				self.onMediaChange key, e.matches
			if mq.addEventListener
				mq.addEventListener 'change', handler
			elif mq.addListener
				mq.addListener handler
		let w = globalThis.window
		if w.matchMedia
			let dirObserver = new globalThis.MutationObserver do
				let doc = globalThis.document
				let d = (doc.documentElement.getAttribute('dir') or 'ltr')
				if d != self.dir
					self.dir = d == 'rtl' ? 'rtl' : 'ltr'
					notify 'dir'
			dirObserver.observe globalThis.document.documentElement, {attributes: yes, attributeFilter: ['dir']}

	def applyMedia key, matches
		if self.overrides.hasOwnProperty(key)
			return
		if key == 'reducedMotion'
			self.reducedMotion = matches
		elif key == 'reducedTransparency'
			self.reducedTransparency = matches
		elif key == 'increaseContrast'
			self.increaseContrast = matches
		elif key == 'forcedColors'
			self.forcedColors = matches
		elif key == 'darkScheme'
			self.darkScheme = matches

	def onMediaChange key, matches
		applyMedia key, matches
		notify key

	get colorScheme
		if self.overrides.hasOwnProperty('darkScheme')
			return if self.overrides.darkScheme then 'dark' else 'light'
		if self.darkScheme then 'dark' else 'light'

	def setOverride key, value
		if value == null
			delete self.overrides[key]
			if self.mqls[key]
				applyMedia key, self.mqls[key].matches
		else
			self.overrides[key] = value
			if key == 'reducedMotion'
				self.reducedMotion = value
			elif key == 'reducedTransparency'
				self.reducedTransparency = value
			elif key == 'increaseContrast'
				self.increaseContrast = value
			elif key == 'forcedColors'
				self.forcedColors = value
			elif key == 'darkScheme'
				self.darkScheme = value
		notify key

	def clearOverrides
		let keys = []
		for own key of self.overrides
			keys.push key
		for key in keys
			setOverride key, null

	def notify key
		self.events.emit 'changed', self
		self.events.emit "changed:{key}", self

	def subscribe fn
		self.events.on 'changed', fn

export const preferences = new Preferences
