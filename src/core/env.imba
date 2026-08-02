export const isBrowser = typeof globalThis.window != 'undefined' and typeof globalThis.document != 'undefined'
export const isNode = !isBrowser

export def dpr
	if isBrowser and globalThis.window.devicePixelRatio
		globalThis.window.devicePixelRatio
	else
		1

export def now
	if typeof globalThis.performance != 'undefined' and globalThis.performance.now
		globalThis.performance.now()
	else
		Date.now()

export def requestFrame cb
	if isBrowser
		globalThis.window.requestAnimationFrame cb
	else
		globalThis.setTimeout (do cb(now!)), 16

export def cancelFrame handle
	if isBrowser
		globalThis.window.cancelAnimationFrame handle
	else
		globalThis.clearTimeout handle

export class MemoryStorage
	def constructor
		self.map = new Map

	def getItem key
		if self.map.has(key)
			self.map.get(key)
		else
			null

	def setItem key, value
		self.map.set key, String(value)

	def removeItem key
		self.map.delete key

	def clear
		self.map.clear

def detectStorage
	if isBrowser
		try
			let s = globalThis.window.localStorage
			let probe = '__glasskit_probe__'
			s.setItem probe, '1'
			s.removeItem probe
			return s
		catch e
			return new MemoryStorage
	new MemoryStorage

export const storage = detectStorage()

export def viewportSize
	if isBrowser
		[globalThis.window.innerWidth, globalThis.window.innerHeight]
	else
		[1024, 768]

export def onResize cb
	unless isBrowser
		return do null
	let w = globalThis.window
	w.addEventListener 'resize', cb
	do w.removeEventListener('resize', cb)

export def matchMedia query
	unless isBrowser
		return null
	if globalThis.window.matchMedia
		globalThis.window.matchMedia query
	else
		null
