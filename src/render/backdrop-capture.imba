import {Texture} from './texture'
import {Rect} from '../core/geometry'
import {isBrowser} from '../core/env'
import {logger} from '../core/logger'

export class BackdropCapture
	def constructor gl, opts = {}
		self.gl = gl
		self.staging = null
		self.stagingCtx = null
		self.stripCanvas = null
		self.stripCtx = null
		self.backdropTex = null
		self.stripTex = null
		self.sources = new Map
		self.readBuffer = null
		self.readBufferSize = 0
		self.width = 0
		self.height = 0
		if isBrowser
			self.staging = globalThis.document.createElement 'canvas'
			self.stagingCtx = self.staging.getContext '2d', {alpha: no, desynchronized: yes}
			self.stripCanvas = globalThis.document.createElement 'canvas'
			self.stripCtx = self.stripCanvas.getContext '2d', {alpha: no}

	def ensureSize w, h
		w = Math.max 2, Math.floor(w)
		h = Math.max 2, Math.floor(h)
		if w == self.width and h == self.height and self.backdropTex != null
			return
		self.width = w
		self.height = h
		if self.staging
			self.staging.width = w
			self.staging.height = h
		if self.backdropTex == null
			self.backdropTex = Texture.acquire self.gl,
				width: w
				height: h
				internalFormat: self.gl.RGBA
				format: self.gl.RGBA
				type: self.gl.UNSIGNED_BYTE
				filter: 'linear'
				wrap: 'clamp'
		else
			self.backdropTex.resize w, h

	get texture
		self.backdropTex

	def registerSource id, type, element, rect
		unless rect isa Rect
			rect = new Rect(rect.x, rect.y, rect.w, rect.h)
		self.sources.set id,
			type: type
			element: element
			rect: rect
			ready: yes
		id

	def unregisterSource id
		self.sources.delete id

	def clearSources
		self.sources.clear

	def updateSourceRect id, rect
		let s = self.sources.get id
		if s
			s.rect.copyFrom rect

	get sourceCount
		self.sources.size

	def capture dpr = 1
		if self.staging == null or self.stagingCtx == null
			return self.backdropTex
		ensureSize self.width, self.height
		let ctx = self.stagingCtx
		ctx.save!
		ctx.globalCompositeOperation = 'copy'
		ctx.fillStyle = '#000000'
		ctx.fillRect 0, 0, self.width, self.height
		self.sources.forEach do(src)
			let el = src.element
			let r = src.rect
			let dx = r.x * dpr
			let dy = r.y * dpr
			let dw = r.w * dpr
			let dh = r.h * dpr
			if dw < 1 or dh < 1
				return
			try
				if src.type == 'texture'
					copyTextureSource src, dpr
					return
				if src.type == 'video'
					if el.readyState >= 2 and el.videoWidth > 0
						drawCover ctx, el, el.videoWidth, el.videoHeight, dx, dy, dw, dh
				elif src.type == 'image'
					if el.complete and el.naturalWidth > 0
						drawCover ctx, el, el.naturalWidth, el.naturalHeight, dx, dy, dw, dh
				elif src.type == 'canvas' or src.type == 'snapshot'
					ctx.drawImage el, dx, dy, dw, dh
				else
					ctx.drawImage el, dx, dy, dw, dh
			catch e
				logger.warnOnce "capture:{src.type}", "Backdrop source of type '{src.type}' could not be drawn — {e.message}"
		ctx.restore!
		self.backdropTex.uploadSource self.staging
		self.backdropTex

	def drawCover ctx, el, sw, sh, dx, dy, dw, dh
		let sa = sw / sh
		let da = dw / dh
		let cw = sw
		let ch = sh
		let cx = 0
		let cy = 0
		if sa > da
			cw = sh * da
			cx = (sw - cw) / 2
		else
			ch = sw / da
			cy = (sh - ch) / 2
		ctx.drawImage el, cx, cy, cw, ch, dx, dy, dw, dh

	def copyTextureSource src, dpr
		let gl = self.gl
		let tex = src.element
		unless tex and tex.handle
			return
		let r = src.rect
		let w = Math.min Math.floor(r.w * dpr), tex.width
		let h = Math.min Math.floor(r.h * dpr), tex.height
		if w < 1 or h < 1
			return
		let bytes = w * h * 4
		if self.readBuffer == null or self.readBufferSize < bytes
			self.readBuffer = new Uint8Array bytes
			self.readBufferSize = bytes
		let fb = gl.createFramebuffer!
		gl.bindFramebuffer gl.FRAMEBUFFER, fb
		gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex.handle, 0
		gl.readPixels 0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, self.readBuffer
		gl.bindFramebuffer gl.FRAMEBUFFER, null
		gl.deleteFramebuffer fb
		let x = Math.floor r.x * dpr
		let yTop = Math.floor r.y * dpr
		let y = self.height - yTop - h
		gl.bindTexture gl.TEXTURE_2D, self.backdropTex.handle
		gl.texSubImage2D gl.TEXTURE_2D, 0, x, y, w, h, gl.RGBA, gl.UNSIGNED_BYTE, self.readBuffer
		gl.bindTexture gl.TEXTURE_2D, null

	def captureStrip rectCss, dpr, outW = 128, outH = 128
		if self.stripCanvas == null or self.stripCtx == null or self.staging == null
			return null
		self.stripCanvas.width = outW
		self.stripCanvas.height = outH
		let sx = rectCss.x * dpr
		let sy = rectCss.y * dpr
		let sw = Math.max 1, rectCss.w * dpr
		let sh = Math.max 1, rectCss.h * dpr
		self.stripCtx.drawImage self.staging, sx, sy, sw, sh, 0, 0, outW, outH
		if self.stripTex == null
			self.stripTex = Texture.acquire self.gl,
				width: outW
				height: outH
				internalFormat: self.gl.RGBA
				format: self.gl.RGBA
				type: self.gl.UNSIGNED_BYTE
				filter: 'linear'
				wrap: 'clamp'
		else
			self.stripTex.resize outW, outH
		self.stripTex.uploadSource self.stripCanvas
		self.stripTex

	def dispose
		if self.backdropTex
			self.backdropTex.release!
			self.backdropTex = null
		if self.stripTex
			self.stripTex.release!
			self.stripTex = null
		self.readBuffer = null
		self.sources.clear
