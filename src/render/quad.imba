const VERTS = new Float32Array [-1, -1, 3, -1, -1, 3]

export class FullscreenQuad
	prop gl
	prop vbo
	prop vao

	def constructor gl
		self.gl = gl
		self.vbo = gl.createBuffer!
		self.vao = null
		self.attribLoc = -1
		gl.bindBuffer gl.ARRAY_BUFFER, self.vbo
		gl.bufferData gl.ARRAY_BUFFER, VERTS, gl.STATIC_DRAW
		gl.bindBuffer gl.ARRAY_BUFFER, null

	def makeVao attribName, program
		let gl = self.gl
		unless gl.createVertexArray
			return null
		let vao = gl.createVertexArray!
		gl.bindVertexArray vao
		gl.bindBuffer gl.ARRAY_BUFFER, self.vbo
		let loc = gl.getAttribLocation program, attribName
		if loc >= 0
			gl.enableVertexAttribArray loc
			gl.vertexAttribPointer loc, 2, gl.FLOAT, no, 0, 0
		gl.bindVertexArray null
		gl.bindBuffer gl.ARRAY_BUFFER, null
		vao

	def draw attribName = 'aPos', program = null, vao = null
		let gl = self.gl
		if vao != null
			gl.bindVertexArray vao
			gl.drawArrays gl.TRIANGLES, 0, 3
			gl.bindVertexArray null
			return
		gl.bindBuffer gl.ARRAY_BUFFER, self.vbo
		let loc = self.attribLoc
		if program != null
			loc = gl.getAttribLocation program, attribName
			self.attribLoc = loc
		if loc >= 0
			gl.enableVertexAttribArray loc
			gl.vertexAttribPointer loc, 2, gl.FLOAT, no, 0, 0
			gl.drawArrays gl.TRIANGLES, 0, 3
			gl.disableVertexAttribArray loc
		gl.bindBuffer gl.ARRAY_BUFFER, null

	def dispose
		let gl = self.gl
		if self.vbo
			gl.deleteBuffer self.vbo
			self.vbo = null
		if self.vao and gl.deleteVertexArray
			gl.deleteVertexArray self.vao
			self.vao = null
