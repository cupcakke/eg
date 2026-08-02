import {Texture} from './texture'
import {Framebuffer} from './framebuffer'
import {chooseColorFormat, levelsForRadius, lodForRadius, computeGaussianWeights, gaussianSigmaForRadius} from './gl-utils'

export class BlurPipeline
	def constructor gl, isGL2, quad, programs, shaderSrc
		self.gl = gl
		self.isGL2 = isGL2
		self.quad = quad
		self.programs = programs
		self.shaders = shaderSrc
		self.format = chooseColorFormat gl, isGL2, {hasFloatBuffers: yes, hasHalfFloatBuffers: yes}
		self.width = 0
		self.height = 0
		self.maxLevels = 6
		self.chainA = []
		self.chainB = []
		self.mipTex = null
		self.mipFb = null
		self.gaussA = null
		self.gaussB = null
		self.kawaseA = []
		self.kawaseB = []
		self.lastAlgorithm = 'chain'
		self.dirty = yes

	def configure hasFloatBuffers, hasHalfFloatBuffers
		self.format = chooseColorFormat self.gl, self.isGL2, {hasFloatBuffers: hasFloatBuffers, hasHalfFloatBuffers: hasHalfFloatBuffers}

	def ensureSize w, h
		w = Math.max 2, Math.floor(w)
		h = Math.max 2, Math.floor(h)
		if w == self.width and h == self.height
			return
		releaseChain!
		self.width = w
		self.height = h
		let opts =
			width: w
			height: h
			internalFormat: self.format.internalFormat
			format: self.format.format
			type: self.format.type
			filter: 'linear'
			wrap: 'clamp'
		for i in [0 ... self.maxLevels]
			let levelOpts = Object.assign({}, opts, {width: Math.max(1, w >>> i), height: Math.max(1, h >>> i)})
			self.chainA.push new Framebuffer(self.gl, levelOpts)
			self.chainB.push new Framebuffer(self.gl, levelOpts)
		if self.isGL2
			self.mipTex = new Texture self.gl, Object.assign({}, opts, {mips: self.maxLevels})
			self.mipFb = new Framebuffer self.gl, Object.assign({}, opts)
		self.dirty = yes

	def releaseChain
		for fb in self.chainA
			fb.dispose!
		for fb in self.chainB
			fb.dispose!
		self.chainA = []
		self.chainB = []
		if self.mipFb
			self.mipFb.dispose!
			self.mipFb = null
		if self.mipTex
			self.mipTex.destroy!
			self.mipTex = null
		if self.gaussA
			self.gaussA.dispose!
			self.gaussA = null
		if self.gaussB
			self.gaussB.dispose!
			self.gaussB = null
		for fb in self.kawaseA
			fb.dispose!
		for fb in self.kawaseB
			fb.dispose!
		self.kawaseA = []
		self.kawaseB = []

	get maxLod
		self.maxLevels - 1

	def program name
		let dir = if self.isGL2 then '' else 'es100/'
		self.programs.get name, self.shaders[dir + 'quad.vert'], self.shaders[dir + name + '.frag']

	def pass prog, srcTexture, targetFb, level = 0
		let gl = self.gl
		targetFb.bind level
		gl.disable gl.BLEND
		prog.use!
		prog.u2f 'uResolution', targetFb.width >>> Math.max(0, level), targetFb.height >>> Math.max(0, level)
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.uTexture 'uSource', srcTexture, 0
		prog.drawQuad self.quad
		targetFb.unbind!

	def downsamplePass src, srcLevel, dstChain, dstIndex
		let gl = self.gl
		let fb = dstChain[dstIndex]
		let prog = program 'downsample'
		fb.bind 0
		prog.use!
		prog.u2f 'uResolution', fb.width, fb.height
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.u2f 'uTexel', 1 / Math.max(1, src.width >>> Math.max(0, srcLevel)), 1 / Math.max(1, src.height >>> Math.max(0, srcLevel))
		prog.uTexture 'uSource', src, 0
		prog.drawQuad self.quad
		fb.unbind!

	def upsamplePass src, dstFb
		let gl = self.gl
		let prog = program 'upsample'
		dstFb.bind 0
		prog.use!
		prog.u2f 'uResolution', dstFb.width, dstFb.height
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.u2f 'uTexel', 1 / src.width, 1 / src.height
		prog.uTexture 'uSource', src, 0
		prog.drawQuad self.quad
		dstFb.unbind!

	def copyToMipLevels chain
		let gl = self.gl
		let prog = program 'composite'
		for level in [0 ... self.maxLevels]
			self.mipFb.attachLevel level
			gl.disable gl.BLEND
			prog.use!
			prog.u2f 'uResolution', Math.max(1, self.width >>> level), Math.max(1, self.height >>> level)
			prog.u4f 'uDrawRect', 0, 0, 0, 0
			prog.u1f 'uOpacity', 1
			prog.u1f 'uDither', 0
			prog.u1i 'uEncode', 0
			prog.uTexture 'uSource', chain[level].texture, 0
			prog.drawQuad self.quad
		self.mipFb.unbind!

	def runChain backdropTexture, qualityScale = 1
		let levels = Math.max 2, Math.round(levelsForRadius(96 * qualityScale, self.height))
		levels = Math.min levels, self.maxLevels
		let gl = self.gl
		let halfProg = program 'downsample'
		self.chainA[0].bind 0
		halfProg.use!
		halfProg.u2f 'uResolution', self.width, self.height
		halfProg.u4f 'uDrawRect', 0, 0, 0, 0
		halfProg.u2f 'uTexel', 1 / backdropTexture.width, 1 / backdropTexture.height
		halfProg.uTexture 'uSource', backdropTexture, 0
		halfProg.drawQuad self.quad
		self.chainA[0].unbind!
		for i in [1 ... levels]
			downsamplePass self.chainA[i - 1].texture, 0, self.chainA, i
		if self.isGL2
			copyToMipLevels self.chainA
		self.lastAlgorithm = 'chain'
		self.dirty = no

	def runKawase backdropTexture, iterations = 3
		let gl = self.gl
		let prog = program 'kawase-blur'
		while self.kawaseA.length < iterations
			self.kawaseA.push new Framebuffer(self.gl, {width: self.width, height: self.height, internalFormat: self.format.internalFormat, format: self.format.format, type: self.format.type})
			self.kawaseB.push new Framebuffer(self.gl, {width: self.width, height: self.height, internalFormat: self.format.internalFormat, format: self.format.format, type: self.format.type})
		let src = backdropTexture
		for i in [0 ... iterations]
			let dst = self.kawaseA[i]
			dst.bind 0
			prog.use!
			prog.u2f 'uResolution', dst.width, dst.height
			prog.u4f 'uDrawRect', 0, 0, 0, 0
			prog.u2f 'uTexel', 1 / src.width, 1 / src.height
			prog.u1f 'uSpread', i
			prog.uTexture 'uSource', src, 0
			prog.drawQuad self.quad
			dst.unbind!
			src = dst.texture
		for i in [0 ... iterations - 1]
			let dst = self.kawaseB[i]
			dst.bind 0
			prog.use!
			prog.u2f 'uResolution', dst.width, dst.height
			prog.u4f 'uDrawRect', 0, 0, 0, 0
			prog.u2f 'uTexel', 1 / src.width, 1 / src.height
			prog.u1f 'uSpread', iterations - 2 - i
			prog.uTexture 'uSource', src, 0
			prog.drawQuad self.quad
			dst.unbind!
			src = dst.texture
		self.lastAlgorithm = 'kawase'
		self.dirty = no
		src

	def runGaussian backdropTexture, radius
		let gl = self.gl
		if self.gaussA == null
			let opts = {width: Math.max(1, self.width / 2), height: Math.max(1, self.height / 2), internalFormat: self.format.internalFormat, format: self.format.format, type: self.format.type}
			self.gaussA = new Framebuffer(self.gl, Object.assign({}, opts))
			self.gaussB = new Framebuffer(self.gl, Object.assign({}, opts))
		downsamplePass backdropTexture, 0, [self.gaussA], 0
		let sigma = gaussianSigmaForRadius radius / 2
		let weights = computeGaussianWeights sigma
		let prog = program 'gaussian-blur'
		self.gaussB.bind 0
		prog.use!
		prog.u2f 'uResolution', self.gaussB.width, self.gaussB.height
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.u2f 'uDirection', 1 / self.gaussA.width, 0
		prog.u1fv 'uWeights', weights
		prog.uTexture 'uSource', self.gaussA.texture, 0
		prog.drawQuad self.quad
		self.gaussB.unbind!
		self.gaussA.bind 0
		prog.use!
		prog.u2f 'uDirection', 0, 1 / self.gaussB.height
		prog.uTexture 'uSource', self.gaussB.texture, 0
		prog.drawQuad self.quad
		self.gaussA.unbind!
		self.lastAlgorithm = 'gaussian'
		self.dirty = no
		self.gaussA.texture

	def selectAlgorithm radius, performanceClass = 'medium', override = 'auto'
		if override != 'auto'
			return override
		if radius <= 8
			'gaussian'
		elif radius <= 18 and performanceClass != 'low'
			'kawase'
		else
			'chain'

	def blur backdropTexture, maxRadius, qualityScale, performanceClass, override = 'auto'
		let algo = selectAlgorithm maxRadius, performanceClass, override
		if algo == 'kawase'
			let tex = runKawase backdropTexture, 3
			return {mode: 'single', texture: tex, maxLod: 0}
		elif algo == 'gaussian'
			let tex = runGaussian backdropTexture, Math.max(4, maxRadius * qualityScale)
			return {mode: 'single', texture: tex, maxLod: 0}
		runChain backdropTexture, qualityScale
		if self.isGL2
			{mode: 'lod', texture: self.mipTex, maxLod: self.maxLod}
		else
			{mode: 'levels', levels: self.chainA, maxLod: self.maxLod}

	def levelPair lodFloat
		let lo = Math.min self.maxLod, Math.floor(lodFloat)
		let hi = Math.min self.maxLod, lo + 1
		{lo: lo, hi: hi, mix: lodFloat - lo}

	def dispose
		releaseChain!
