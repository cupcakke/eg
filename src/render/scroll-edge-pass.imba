export class ScrollEdgePass
	def programFor env
		env.programs.get 'scroll-edge', env.shaderFor('quad.vert'), env.shaderFor('scroll-edge.frag')

	def render gl, env, effects
		if effects.length == 0
			return 0
		let prog = programFor env
		let ran = 0
		prog.use!
		for effect in effects
			if effect.strength <= 0.004 or effect.style == 'hidden'
				continue
			let rect = effect.rectGL
			let axis = effect.edge == 'top' or effect.edge == 'bottom' ? 0 : 1
			let start = 0.0
			let dir = -1
			if effect.edge == 'top'
				start = rect.y + effect.bandSizeGL
				dir = -1
			elif effect.edge == 'bottom'
				start = rect.y + rect.h - effect.bandSizeGL
				dir = 1
			elif effect.edge == 'leading'
				start = rect.x + rect.w - effect.bandSizeGL
				dir = 1
			else
				start = rect.x + effect.bandSizeGL
				dir = -1
			prog.u1i 'uShapeCount', 0
			prog.u2f 'uResolution', env.width, env.height
			prog.u4f 'uDrawRect', rect.x, rect.y, rect.w, rect.h
			prog.u1f 'uBlurMaxLod', env.blurMaxLod
			prog.u1f 'uAAWidth', 1.0
			prog.u1f 'uSpacing', 0
			prog.u3f 'uLightDir', env.lightDir[0], env.lightDir[1], env.lightDir[2]
			prog.u1f 'uTime', env.time
			prog.u1f 'uDpr', env.dpr
			prog.u1i 'uFlags', env.flags
			prog.u1f 'uBandStart', start
			prog.u1f 'uBandDir', dir
			prog.u1f 'uBandSize', effect.bandSizeGL
			prog.u1f 'uStrength', effect.strength
			if env.isGL2
				prog.u1i 'uEdgeAxis', axis
				prog.u1i 'uEdgeStyle', (effect.style == 'hard' ? 1 : 0)
			else
				prog.u1f 'uEdgeAxisF', axis
				prog.u1f 'uEdgeStyleF', (effect.style == 'hard' ? 1 : 0)
			if env.isGL2
				env.bindBlurLod prog
			else
				env.bindBlurPair prog
			env.quad.draw 'aPos', prog.handle
			ran += 1
		ran
