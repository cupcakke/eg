import {compileShader, linkProgram} from './gl-utils'
import {bus} from '../core/event-bus'

const stats = {created: 0, disposed: 0, alive: 0}

export def programStats
	{created: stats.created, disposed: stats.disposed, alive: stats.alive}

export def resetProgramStats
	stats.created = 0
	stats.disposed = 0
	stats.alive = 0

let blockBindingCounter = 0
const FIXED_BINDINGS = {GlassBlock: 0, PolyBlock: 1}

export class ShaderProgram
	prop gl
	prop handle
	prop name

	def constructor gl, name, vertSrc, fragSrc, defines = {}
		self.gl = gl
		self.name = name
		let src = buildSource vertSrc, defines, yes
		let fsrc = buildSource fragSrc, defines, no
		self.vert = compileShader gl, gl.VERTEX_SHADER, src, "{name}.vert"
		self.frag = compileShader gl, gl.FRAGMENT_SHADER, fsrc, "{name}.frag"
		self.handle = linkProgram gl, name, self.vert, self.frag
		gl.deleteShader self.vert
		gl.deleteShader self.frag
		self.vert = null
		self.frag = null
		self.uniforms = new Map
		self.blocksBound = no
		self.disposed = no
		bindBlocks 'GlassBlock'
		bindBlocks 'PolyBlock'
		stats.created += 1
		stats.alive += 1

	def buildSource src, defines, isVert
		let defs = ''
		for own key, value of defines
			defs += "#define {key} {value}\n"
		defs + src

	def bindBlocks blockName
		let gl = self.gl
		unless gl.getUniformBlockIndex
			return
		let idx = gl.getUniformBlockIndex self.handle, blockName
		if idx != gl.INVALID_INDEX
			let binding = FIXED_BINDINGS[blockName]
			if binding == undefined
				binding = 2 + (blockBindingCounter % 6)
				blockBindingCounter += 1
			gl.uniformBlockBinding self.handle, idx, binding
			self["binding" + blockName] = binding

	def blockBinding blockName
		self["binding" + blockName] or 0

	def use
		self.gl.useProgram self.handle
		self

	def loc name
		if self.uniforms.has(name)
			self.uniforms.get name
		else
			let l = self.gl.getUniformLocation self.handle, name
			self.uniforms.set name, l
			l

	def u1f name, v
		let l = loc name
		if l != null
			self.gl.uniform1f l, v
		self

	def u2f name, x, y
		let l = loc name
		if l != null
			self.gl.uniform2f l, x, y
		self

	def u3f name, x, y, z
		let l = loc name
		if l != null
			self.gl.uniform3f l, x, y, z
		self

	def u4f name, x, y, z, w
		let l = loc name
		if l != null
			self.gl.uniform4f l, x, y, z, w
		self

	def u1i name, v
		let l = loc name
		if l != null
			self.gl.uniform1i l, v | 0
		self

	def u1fv name, arr
		let l = loc name
		if l != null
			self.gl.uniform1fv l, arr
		self

	def u2fv name, arr
		let l = loc name
		if l != null
			self.gl.uniform2fv l, arr
		self

	def u4fv name, arr
		let l = loc name
		if l != null
			self.gl.uniform4fv l, arr
		self

	def uTexture name, texture, unit
		let gl = self.gl
		gl.activeTexture gl.TEXTURE0 + unit
		gl.bindTexture gl.TEXTURE_2D, texture.handle
		let l = loc name
		if l != null
			gl.uniform1i l, unit
		self

	def drawQuad quad
		quad.draw 'aPos', self.handle

	def dispose
		if self.disposed
			return
		self.disposed = yes
		self.gl.deleteProgram self.handle
		self.handle = null
		stats.disposed += 1
		stats.alive -= 1

export class ProgramCache
	def constructor gl
		self.gl = gl
		self.map = new Map
		self.parallelExt = gl.getExtension 'KHR_parallel_shader_compile'

	def key name, definesList
		let parts = [name]
		for own k, v of definesList
			parts.push "{k}={v}"
		parts.join '|'

	def get name, vertSrc, fragSrc, definesList = {}
		let k = key name, definesList
		let prog = self.map.get k
		unless prog
			prog = new ShaderProgram(self.gl, name, vertSrc, fragSrc, definesList)
			self.map.set k, prog
		prog

	def warm entries, done
		let progs = []
		for entry in entries
			progs.push get(entry.name, entry.vert, entry.frag, entry.defines or {})
		if self.parallelExt
			let check = do
				let ready = yes
				for p in progs
					if !self.gl.getProgramParameter(p.handle, self.parallelExt.COMPLETION_STATUS_KHR)
						ready = no
				if ready
					done progs
				else
					globalThis.setTimeout check, 8
			globalThis.setTimeout check, 0
		else
			done progs

	def disposeAll
		self.map.forEach do(prog)
			prog.dispose!
		self.map.clear

	get count
		self.map.size
