export class GlassPass
	def constructor
		self.lastProg = null

	def programFor env, allClear
		let name = allClear ? 'glass-clear.frag' : 'glass.frag'
		env.programs.get "glass:{name}", env.shaderFor('quad.vert'), env.shaderFor(name)

	def render gl, env, container
		if container.shapeCount == 0
			return no
		let prog = programFor env, container.allClear
		prog.use!
		env.bindGlassUniforms prog, container
		env.drawContainerQuad prog, container
		self.lastProg = prog
		yes
