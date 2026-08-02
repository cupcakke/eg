export class CompositePass
	def constructor
		self.blitCount = 0

	def programFor env
		env.programs.get 'composite', env.shaderFor('quad.vert'), env.shaderFor('composite.frag')

	def blitToScreen env, srcTexture, opacity = 1, encode = 1, dither = 0, targetFb = null
		let gl = env.gl
		let prog = programFor env
		if targetFb != null
			targetFb.bind 0
		else
			gl.bindFramebuffer gl.FRAMEBUFFER, null
			gl.viewport 0, 0, env.width, env.height
		gl.disable gl.BLEND
		prog.use!
		prog.u2f 'uResolution', (targetFb != null ? targetFb.width : env.width), (targetFb != null ? targetFb.height : env.height)
		prog.u4f 'uDrawRect', 0, 0, 0, 0
		prog.u1f 'uOpacity', opacity
		prog.u1f 'uDither', dither
		if env.isGL2
			prog.u1i 'uEncode', encode
		else
			prog.u1f 'uEncodeF', encode
		prog.uTexture 'uSource', srcTexture, 0
		prog.drawQuad env.quad
		if targetFb != null
			targetFb.unbind!
		self.blitCount += 1
		yes
