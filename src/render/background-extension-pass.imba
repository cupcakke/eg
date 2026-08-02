export class BackgroundExtensionPass
	def programFor env
		env.programs.get 'background-extension', env.shaderFor('quad.vert'), env.shaderFor('background-extension.frag')

	def render gl, env, effects
		if effects.length == 0
			return 0
		let prog = programFor env
		let ran = 0
		prog.use!
		for effect in effects
			if effect.strength <= 0.004 or effect.stripTexture == null
				continue
			let rect = effect.bandRectGL
			prog.u2f 'uResolution', env.width, env.height
			prog.u4f 'uDrawRect', rect.x, rect.y, rect.w, rect.h
			prog.uTexture 'uStrip', effect.stripTexture, 0
			prog.u4f 'uStripUv', effect.stripUv[0], effect.stripUv[1], effect.stripUv[2], effect.stripUv[3]
			prog.u4f 'uBandRect', rect.x, rect.y, rect.w, rect.h
			prog.u1f 'uStrength', effect.strength
			prog.u1f 'uSeamPx', effect.seamPxGL
			prog.u1f 'uBandSize', effect.bandSizeGL
			if env.isGL2
				prog.u1i 'uAxis', (effect.axis == 'x' ? 0 : 1)
			else
				prog.u1f 'uAxisF', (effect.axis == 'x' ? 0 : 1)
				prog.u2f 'uStripTexel', 1 / effect.stripTexture.width, 1 / effect.stripTexture.height
			env.quad.draw 'aPos', prog.handle
			ran += 1
		ran
