import {isBrowser} from '../core/env'

const POOL = []
const stats = {created: 0, disposed: 0, alive: 0, pooled: 0, uploads: 0}
const MAX_POOLED = 48

export def textureStats
	{created: stats.created, disposed: stats.disposed, alive: stats.alive, pooled: POOL.length, uploads: stats.uploads}

export def resetTextureStats
	stats.created = 0
	stats.disposed = 0
	stats.alive = 0
	stats.uploads = 0
	while POOL.length > 0
		let t = POOL.pop!
		t.destroy!

def poolKey opts
	"{opts.width}x{opts.height}:{opts.internalFormat or 0}:{opts.type or 0}:{opts.filter or 'linear'}:{opts.mips or 0}"

export class Texture
	prop gl
	prop handle
	prop width
	prop height

	def constructor gl, opts
		self.gl = gl
		self.key = poolKey opts
		self.width = opts.width
		self.height = opts.height
		self.filter = opts.filter or 'linear'
		self.wrap = opts.wrap or 'clamp'
		self.internalFormat = opts.internalFormat
		self.format = opts.format or gl.RGBA
		self.type = opts.type or gl.UNSIGNED_BYTE
		self.mips = opts.mips or 0
		self.disposed = no
		self.handle = gl.createTexture!
		stats.created += 1
		stats.alive += 1
		allocate!

	def allocate
		let gl = self.gl
		gl.bindTexture gl.TEXTURE_2D, self.handle
		let filterConst = self.mips > 0 ? gl.LINEAR_MIPMAP_LINEAR : (self.filter == 'nearest' ? gl.NEAREST : gl.LINEAR)
		gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filterConst
		gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, (self.filter == 'nearest' ? gl.NEAREST : gl.LINEAR)
		gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
		gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
		let levels = self.mips > 0 ? self.mips + 1 : 1
		for level in [0 ... levels]
			let w = Math.max 1, self.width >>> level
			let h = Math.max 1, self.height >>> level
			gl.texImage2D gl.TEXTURE_2D, level, self.internalFormat or self.format, w, h, 0, self.format, self.type, null
		gl.bindTexture gl.TEXTURE_2D, null
		self

	def resize w, h
		w = Math.max 1, Math.floor(w)
		h = Math.max 1, Math.floor(h)
		if w == self.width and h == self.height
			return self
		self.width = w
		self.height = h
		let gl = self.gl
		gl.bindTexture gl.TEXTURE_2D, self.handle
		let levels = self.mips > 0 ? self.mips + 1 : 1
		for level in [0 ... levels]
			gl.texImage2D gl.TEXTURE_2D, level, self.internalFormat or self.format, Math.max(1, w >>> level), Math.max(1, h >>> level), 0, self.format, self.type, null
		gl.bindTexture gl.TEXTURE_2D, null
		self

	def bind unit = 0
		let gl = self.gl
		gl.activeTexture gl.TEXTURE0 + unit
		gl.bindTexture gl.TEXTURE_2D, self.handle
		unit

	def unbind unit = 0
		let gl = self.gl
		gl.activeTexture gl.TEXTURE0 + unit
		gl.bindTexture gl.TEXTURE_2D, null

	def uploadSource source
		let gl = self.gl
		gl.bindTexture gl.TEXTURE_2D, self.handle
		gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, 1
		gl.pixelStorei gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0
		gl.texImage2D gl.TEXTURE_2D, 0, self.internalFormat or self.format, self.format, self.type, source
		gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, 0
		gl.bindTexture gl.TEXTURE_2D, null
		stats.uploads += 1
		self

	def uploadData data, level = 0
		let gl = self.gl
		gl.bindTexture gl.TEXTURE_2D, self.handle
		let w = Math.max 1, self.width >>> level
		let h = Math.max 1, self.height >>> level
		gl.texImage2D gl.TEXTURE_2D, level, self.internalFormat or self.format, w, h, 0, self.format, self.type, data
		gl.bindTexture gl.TEXTURE_2D, null
		stats.uploads += 1
		self

	def attachTo fb, level = 0
		let gl = self.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, fb
		gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.handle, level
		gl.bindFramebuffer gl.FRAMEBUFFER, null

	def destroy
		if self.handle != null and self.disposed == no
			self.disposed = yes
			self.gl.deleteTexture self.handle
			self.handle = null
			stats.disposed += 1
			stats.alive -= 1

	def release
		if self.disposed
			return
		if POOL.length < MAX_POOLED
			POOL.push self
			stats.pooled += 1
		else
			destroy!

	static def acquire gl, opts
		let key = poolKey opts
		let i = POOL.length
		while i > 0
			i -= 1
			let cand = POOL[i]
			if cand.key == key and cand.disposed == no
				POOL.splice i, 1
				stats.pooled -= 1
				return cand
		new Texture(gl, opts)

export def createDataTexture gl, width, height, data = null
	let t = new Texture gl,
		width: width
		height: height
		internalFormat: gl.RGBA
		format: gl.RGBA
		type: (if globalThis.__GK_FLOAT_TEXTURES__ === no then gl.UNSIGNED_BYTE else gl.FLOAT)
		filter: 'nearest'
		wrap: 'clamp'
	if data != null
		t.uploadData data
	t
