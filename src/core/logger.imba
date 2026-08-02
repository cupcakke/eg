import {settings} from './settings'

const MAX_VIOLATIONS = 200

export class Logger
	def constructor
		self.seen = new Set
		self.violations = []

	get devEnabled
		settings.devDiagnostics

	def emit level, msg
		if typeof globalThis.console != 'undefined'
			let fn = globalThis.console[level] or globalThis.console.log
			fn.call globalThis.console, "[GlassKit] {msg}"

	def warn msg
		if devEnabled
			emit 'warn', msg

	def warnOnce key, msg
		if devEnabled and !self.seen.has(key)
			self.seen.add key
			emit 'warn', msg

	def info msg
		if settings.debugMode
			emit 'info', msg

	def error msg
		emit 'error', msg

	def devAssert condition, msg
		unless condition
			if devEnabled
				emit 'warn', "Assertion failed — {msg}"
			return no
		yes

	def require condition, msg
		unless condition
			if devEnabled
				let err = new Error "[GlassKit] {msg}"
				emit 'error', msg
				throw err
		yes

	def recordViolation kind, message, details = null
		if self.violations.length >= MAX_VIOLATIONS
			self.violations.shift!
		self.violations.push
			kind: kind
			message: message
			details: details
			time: Date.now!
		if devEnabled
			emit 'warn', "[{kind}] {message}"

	def clearViolations
		self.violations = []

	get currentViolations
		self.violations.slice(0)

export const logger = new Logger
