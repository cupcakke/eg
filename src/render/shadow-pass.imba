export class ShadowPass
	def programFor env
		env.programs.get 'shadow', env.shaderFor('quad.vert'), env.shaderFor('shadow.frag')

	def render gl, env, container
		if container.shapeCount == 0 or container.hasShadow == no
			return no
		unless env.shadowEnabled
			return no
		let prog = programFor env
		prog.use!
		env.bindGlassUniforms prog, container
		env.drawContainerQuad prog, container
		yes
