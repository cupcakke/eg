import {Texture} from './texture'
import {checkGlError} from './gl-utils'
import {logger} from '../core/logger'

const stats = {created: 0, disposed: 0, alive: 0}

export def framebufferStats
	{created: stats.created, disposed: stats.disposed, alive: stats.alive}

export def resetFramebufferStats
	stats.created = 0
	stats.disposed = 0
	stats.alive = 0

export class Framebuffer
	prop gl
	prop handle
	prop texture

	def constructor gl, textureOrOpts
		self.gl = gl
		self.handle = gl.createFramebuffer!
		stats.created += 1
		stats.alive += 1
		if textureOrOpts isa Texture
			self.texture = textureOrOpts
		else
			self.texture = new Texture(gl, textureOrOpts)
		self.disposed = no
		validate!

	def validate
		let gl = self.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, self.handle
		gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.texture.handle, 0
		let status = gl.checkFramebufferStatus gl.FRAMEBUFFER
		gl.bindFramebuffer gl.FRAMEBUFFER, null
		if status != gl.FRAMEBUFFER_COMPLETE
			logger.warnOnce "fbo:{status}", "Framebuffer incomplete (status 0x{status.toString(16)}) — falling back to RGBA8 for this target"
		status == gl.FRAMEBUFFER_COMPLETE

	def attachLevel level
		let gl = self.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, self.handle
		gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.texture.handle, level
		gl.viewport 0, 0, Math.max(1, self.texture.width >>> level), Math.max(1, self.texture.height >>> level)

	def bind level = 0
		let gl = self.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, self.handle
		if level >= 0
			gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.texture.handle, level
		let w = Math.max 1, self.texture.width >>> Math.max(0, level)
		let h = Math.max 1, self.texture.height >>> Math.max(0, level)
		gl.viewport 0, 0, w, h
		self

	def unbind
		self.gl.bindFramebuffer self.gl.FRAMEBUFFER, null

	def clear r = 0, g = 0, b = 0, a = 0
		let gl = self.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, self.handle
		gl.clearColor r, g, b, a
		gl.clear gl.COLOR_BUFFER_BIT

	get width
		self.texture.width

	get height
		self.texture.height

	def dispose pooled = yes
		if self.disposed
			return
		self.disposed = yes
		self.gl.deleteFramebuffer self.handle
		self.handle = null
		stats.disposed += 1
		stats.alive -= 1
		if pooled
			self.texture.release!
		else
			self.texture.destroy!

export def blitFramebuffer gl, src, dst, width, height
	gl.bindFramebuffer gl.READ_FRAMEBUFFER, src
	gl.bindFramebuffer gl.DRAW_FRAMEBUFFER, dst
	gl.blitFramebuffer 0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT, gl.NEAREST
