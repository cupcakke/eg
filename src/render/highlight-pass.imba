export class HighlightPass
	def constructor
		self.focusColor = [0.22, 0.5, 0.95, 0.95]

	def programFor env
		env.programs.get 'highlight', env.shaderFor('quad.vert'), env.shaderFor('highlight.frag')

	def render gl, env, container
		if container.shapeCount == 0
			return no
		let hasHover = container.anyInteractive or container.focusedIndex >= 0
		unless hasHover
			return no
		let prog = programFor env
		prog.use!
		env.bindGlassUniforms prog, container
		if env.isGL2
			prog.u1i 'uFocusIndex', container.focusedIndex
		else
			prog.u1f 'uFocusIndexF', container.focusedIndex
		prog.u1f 'uFocusRingWidth', container.focusRingWidth * env.dpr
		prog.u4fv 'uFocusColor', self.focusColor
		env.drawContainerQuad prog, container
		yes
