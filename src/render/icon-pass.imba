import {Texture} from './texture'
import {Framebuffer} from './framebuffer'

export def distanceFieldFromAlpha alpha, w, h, range = 8.0
	let size = w * h
	let inside = new Float64Array size
	let outside = new Float64Array size
	let INF = 1e9
	for i in [0 ... size]
		if alpha[i] > 0.5
			inside[i] = 0
			outside[i] = INF
		else
			inside[i] = INF
			outside[i] = 0
	let distIn = edt2d inside, w, h
	let distOut = edt2d outside, w, h
	let out = new Uint8Array size
	for i in [0 ... size]
		let sd = Math.sqrt(distOut[i]) - Math.sqrt(distIn[i])
		let v = 0.5 - sd / (range * 2)
		out[i] = Math.round(Math.max(0, Math.min(1, v)) * 255)
	out

def edt2d grid, w, h
	let tmp = new Float64Array w * h
	let f = new Float64Array Math.max(w, h)
	let d = new Float64Array Math.max(w, h)
	let v = new Int32Array Math.max(w, h)
	let z = new Float64Array Math.max(w, h) + 1
	for x in [0 ... w]
		for y in [0 ... h]
			f[y] = grid[y * w + x]
		dt1d f, d, v, z, h
		for y in [0 ... h]
			tmp[y * w + x] = d[y]
	for y in [0 ... h]
		for x in [0 ... w]
			f[x] = tmp[y * w + x]
		dt1d f, d, v, z, w
		for x in [0 ... w]
			tmp[y * w + x] = d[x]
	tmp

def dt1d f, d, v, z, n
	let k = 0
	v[0] = 0
	z[0] = -1e20
	z[1] = 1e20
	for q in [1 ... n]
		let s = 0
		let computed = no
		while !computed
			let p = v[k]
			s = ((f[q] + q * q) - (f[p] + p * p)) / (2 * q - 2 * p)
			if s <= z[k]
				k -= 1
				if k < 0
					k = 0
					v[0] = q
					z[0] = -1e20
					z[1] = 1e20
					computed = yes
			else
				k += 1
				v[k] = q
				z[k] = s
				z[k + 1] = 1e20
				computed = yes
	k = 0
	for q in [0 ... n]
		while z[k + 1] < q
			k += 1
		let p = v[k]
		let dx = q - p
		d[q] = dx * dx + f[p]

export class IconPass
	def constructor
		self.scratchA = null
		self.scratchB = null
		self.size = 0
		self.maskTex = null
		self.readBuffer = null

	def ensureSize env, size
		size = Math.max 8, Math.floor(size)
		if size == self.size and self.scratchA != null
			return
		releaseScratch!
		self.size = size
		let opts =
			width: size
			height: size
			internalFormat: env.gl.RGBA
			format: env.gl.RGBA
			type: env.gl.UNSIGNED_BYTE
			filter: 'linear'
			wrap: 'clamp'
		self.scratchA = new Framebuffer(env.gl, Object.assign({}, opts))
		self.scratchB = new Framebuffer(env.gl, Object.assign({}, opts))

	def releaseScratch
		if self.scratchA
			self.scratchA.dispose!
			self.scratchA = null
		if self.scratchB
			self.scratchB.dispose!
			self.scratchB = null

	def programFor env
		env.programs.get 'icon-layer', env.shaderFor('quad.vert'), env.shaderFor('icon-layer.frag')

	def uploadMask env, maskCanvas
		let gl = env.gl
		if self.maskTex == null
			self.maskTex = new Texture gl,
				width: maskCanvas.width
				height: maskCanvas.height
				internalFormat: gl.RGBA
				format: gl.RGBA
				type: gl.UNSIGNED_BYTE
				filter: 'linear'
				wrap: 'clamp'
		else
			self.maskTex.resize maskCanvas.width, maskCanvas.height
		self.maskTex.uploadSource maskCanvas
		self.maskTex

	def renderShadow env, opts
		let gl = env.gl
		let prog = programFor env
		self.scratchA.bind 0
		gl.disable gl.BLEND
		prog.use!
		baseUniforms prog, env, opts
		prog.u1f 'uMode', 1
		prog.u2f 'uShadowOffset', opts.shadowOffset[0], opts.shadowOffset[1]
		prog.u1f 'uShadowRadius', opts.shadowRadius
		prog.u1f 'uShadowOpacity', opts.shadowOpacity
		prog.drawQuad env.quad
		self.scratchA.unbind!

	def renderLayer env, layer, opts
		let gl = env.gl
		let prog = programFor env
		gl.enable gl.BLEND
		gl.blendFunc gl.ONE, gl.ZERO
		self.scratchB.bind 0
		prog.use!
		baseUniforms prog, env, opts
		prog.u1f 'uMode', 0
		prog.u4fv 'uLayerTint', layer.tint
		prog.u1f 'uLayerOpacity', layer.opacity
		prog.u1f 'uLayerSpec', layer.specular
		prog.u1f 'uLayerRefract', layer.refraction
		prog.u1f 'uLayerInnerShadow', layer.innerShadow
		prog.u1f 'uLayerBlur', layer.blur
		prog.uTexture 'uMask', layer.maskTexture, 0
		prog.uTexture 'uBelow', self.scratchA.texture, 1
		prog.drawQuad env.quad
		self.scratchB.unbind!
		let tmp = self.scratchA
		self.scratchA = self.scratchB
		self.scratchB = tmp

	def baseUniforms prog, env, opts
		prog.u2f 'uResolution', self.size, self.size
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.u2f 'uIconPx', self.size, self.size
		prog.u2f 'uMaskPx', opts.maskPx[0], opts.maskPx[1]
		prog.u2f 'uMaskOffset', opts.maskOffset[0], opts.maskOffset[1]
		prog.u4f 'uShapeRect', opts.shapeRect[0], opts.shapeRect[1], opts.shapeRect[2], opts.shapeRect[3]
		prog.u1f 'uShapeRadius', opts.shapeRadius
		prog.u1f 'uShapeType', opts.shapeType
		prog.u3f 'uIconLightDir', opts.lightDir[0], opts.lightDir[1], opts.lightDir[2]

	get resultTexture
		self.scratchA ? self.scratchA.texture : null

	def readToCanvas env, canvasEl
		let gl = env.gl
		let fb = self.scratchA
		if fb == null
			return no
		let size = self.size
		if self.readBuffer == null or self.readBuffer.length != size * size * 4
			self.readBuffer = new Uint8Array size * size * 4
		gl.bindFramebuffer gl.FRAMEBUFFER, fb.handle
		gl.readPixels 0, 0, size, size, gl.RGBA, gl.UNSIGNED_BYTE, self.readBuffer
		gl.bindFramebuffer gl.FRAMEBUFFER, null
		let ctx = canvasEl.getContext '2d'
		let img = ctx.createImageData size, size
		let px = img.data
		for y in [0 ... size]
			let srcY = size - 1 - y
			for x in [0 ... size]
				let si = (srcY * size + x) * 4
				let di = (y * size + x) * 4
				let a = self.readBuffer[si + 3] / 255
				if a > 0.0001
					px[di] = Math.min 255, Math.round(self.readBuffer[si] / a)
					px[di + 1] = Math.min 255, Math.round(self.readBuffer[si + 1] / a)
					px[di + 2] = Math.min 255, Math.round(self.readBuffer[si + 2] / a)
				else
					px[di] = 0
					px[di + 1] = 0
					px[di + 2] = 0
				px[di + 3] = self.readBuffer[si + 3]
		ctx.putImageData img, 0, 0
		yes

	def dispose
		releaseScratch!
		if self.maskTex
			self.maskTex.destroy!
			self.maskTex = null
		self.readBuffer = null
