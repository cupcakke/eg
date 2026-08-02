import {bus} from '../core/event-bus'
import {logger} from '../core/logger'
import {detectCapabilities} from '../core/capabilities'
import {isBrowser} from '../core/env'

const GL_ATTRS =
	alpha: yes
	depth: no
	stencil: no
	antialias: no
	premultipliedAlpha: yes
	preserveDrawingBuffer: no
	powerPreference: 'high-performance'

export class GLContextHost
	prop gl
	prop mode

	def constructor canvas = null, opts = {}
		self.canvas = canvas
		self.mode = 'css'
		self.gl = null
		self.extensions = {}
		self.lostHandler = do(e)
			if e and e.preventDefault
				e.preventDefault!
			logger.info 'WebGL context lost — pausing renderer'
			bus.emit 'gl:lost'
		self.restoredHandler = do(e)
			logger.info 'WebGL context restored'
			bus.emit 'gl:restored'
		if canvas != null
			acquire canvas, opts

	def acquire canvas, opts = {}
		self.canvas = canvas
		let attrs = Object.assign({}, GL_ATTRS, opts.attributes or {})
		canvas.addEventListener 'webglcontextlost', self.lostHandler
		canvas.addEventListener 'webglcontextrestored', self.restoredHandler
		let gl2 = null
		try
			gl2 = canvas.getContext 'webgl2', attrs
		catch e
			gl2 = null
		if gl2
			self.gl = gl2
			self.mode = 'gl2'
			return gl2
		let gl1 = null
		try
			gl1 = canvas.getContext('webgl', attrs) or canvas.getContext('experimental-webgl', attrs)
		catch e
			gl1 = null
		if gl1
			self.gl = gl1
			self.mode = 'gl1'
			self.extensions.derivatives = gl1.getExtension 'OES_standard_derivatives'
			self.extensions.textureFloat = gl1.getExtension 'OES_texture_float'
			self.extensions.textureFloatLinear = gl1.getExtension 'OES_texture_float_linear'
			self.extensions.textureHalfFloat = gl1.getExtension 'OES_texture_half_float'
			self.extensions.textureHalfFloatLinear = gl1.getExtension 'OES_texture_half_float_linear'
			self.extensions.colorBufferFloat = gl1.getExtension 'WEBGL_color_buffer_float'
			self.extensions.colorBufferHalfFloat = gl1.getExtension 'EXT_color_buffer_half_float'
			let canFloat = self.extensions.textureFloat != null
			globalThis.__GK_FLOAT_TEXTURES__ = canFloat
			return gl1
		self.mode = 'css'
		self.gl = null
		logger.warn 'WebGL is unavailable — using the CSS degradation path'
		null

	get isGL2
		self.mode == 'gl2'

	get isGL1
		self.mode == 'gl1'

	get isCSS
		self.mode == 'css'

	get caps
		detectCapabilities!

	def extension name
		if self.gl == null
			return null
		self.gl.getExtension name

	def dispose
		if self.canvas
			self.canvas.removeEventListener 'webglcontextlost', self.lostHandler
			self.canvas.removeEventListener 'webglcontextrestored', self.restoredHandler
		if self.gl
			let ext = self.gl.getExtension 'WEBGL_lose_context'
			if ext
				ext.loseContext!
		self.gl = null
		self.mode = 'css'
