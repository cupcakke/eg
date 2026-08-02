import {isBrowser} from './env'
import {now} from './env'

export class Capabilities
	prop hasWebGL2
	prop hasWebGL1
	prop hasFloatBuffers
	prop hasHalfFloatBuffers
	prop hasDerivatives
	prop hasParallelCompile
	prop hasFloatTextures
	prop maxTextureSize
	prop maxUniformVectors
	prop performanceClass
	prop estimatedRefreshRate
	prop colorSpace

	def constructor
		self.hasWebGL2 = no
		self.hasWebGL1 = no
		self.hasFloatBuffers = no
		self.hasHalfFloatBuffers = no
		self.hasDerivatives = no
		self.hasParallelCompile = no
		self.hasFloatTextures = no
		self.maxTextureSize = 0
		self.maxUniformVectors = 0
		self.performanceClass = 'medium'
		self.estimatedRefreshRate = 60
		self.colorSpace = 'srgb'

	static def detect canvas = null
		let caps = new Capabilities
		unless isBrowser
			return caps
		let cnv = canvas
		let ownsCanvas = no
		unless cnv
			cnv = globalThis.document.createElement 'canvas'
			ownsCanvas = yes
		let gl2 = null
		try
			gl2 = cnv.getContext 'webgl2', {antialias: no, depth: no, stencil: no, alpha: yes, premultipliedAlpha: yes, powerPreference: 'low-power'}
		catch e
			gl2 = null
		if gl2
			caps.hasWebGL2 = yes
			caps.hasFloatBuffers = gl2.getExtension('EXT_color_buffer_float') != null
			caps.hasHalfFloatBuffers = caps.hasFloatBuffers or gl2.getExtension('EXT_color_buffer_half_float') != null
			caps.hasDerivatives = yes
			caps.hasParallelCompile = gl2.getExtension('KHR_parallel_shader_compile') != null
			caps.hasFloatTextures = gl2.getExtension('OES_texture_float_linear') != null
			caps.maxTextureSize = gl2.getParameter gl2.MAX_TEXTURE_SIZE
			caps.maxUniformVectors = gl2.getParameter gl2.MAX_FRAGMENT_UNIFORM_VECTORS
			caps.loseIt gl2
		else
			let gl1 = null
			try
				gl1 = cnv.getContext('webgl', {antialias: no, depth: no, stencil: no, alpha: yes, premultipliedAlpha: yes, powerPreference: 'low-power'}) or cnv.getContext('experimental-webgl')
			catch e
				gl1 = null
			if gl1
				caps.hasWebGL1 = yes
				caps.hasDerivatives = gl1.getExtension('OES_standard_derivatives') != null
				caps.hasFloatTextures = gl1.getExtension('OES_texture_float') != null
				caps.hasHalfFloatBuffers = gl1.getExtension('OES_texture_half_float') != null
				caps.hasFloatBuffers = gl1.getExtension('WEBGL_color_buffer_float') != null
				caps.maxTextureSize = gl1.getParameter gl1.MAX_TEXTURE_SIZE
				caps.maxUniformVectors = gl1.getParameter gl1.MAX_FRAGMENT_UNIFORM_VECTORS
				caps.loseIt gl1
		caps.performanceClass = caps.classifyPerformance!
		caps

	def classifyPerformance
		let hc = if isBrowser then (globalThis.navigator.hardwareConcurrency or 4) else 4
		let mem = if isBrowser then (globalThis.navigator.deviceMemory or 4) else 4
		let score = 0
		if self.hasWebGL2
			score += 2
		elif self.hasWebGL1
			score += 1
		if self.hasFloatBuffers
			score += 1
		if hc >= 8
			score += 1
		if mem >= 8
			score += 1
		if self.maxTextureSize >= 8192
			score += 1
		if score >= 5
			'high'
		elif score >= 3
			'medium'
		else
			'low'

	def loseIt gl
		let ext = gl.getExtension 'WEBGL_lose_context'
		if ext
			ext.loseContext!

	def measureRefreshRate callback, frames = 24
		unless isBrowser
			callback 60
			return
		let w = globalThis.window
		let samples = []
		let last = 0
		let count = 0
		let tick = do(t)
			if last > 0
				samples.push t - last
			last = t
			count += 1
			if count < frames
				w.requestAnimationFrame tick
			else
				samples.sort do(a, b) a - b
				let median = samples[Math.floor(samples.length / 2)] or 16.7
				self.estimatedRefreshRate = if median > 0 then Math.round(1000 / median) else 60
				callback self.estimatedRefreshRate
		w.requestAnimationFrame tick

export let capabilities = null

export def detectCapabilities
	if capabilities == null
		capabilities = Capabilities.detect!
	capabilities

export def resetCapabilitiesForTests
	capabilities = null
