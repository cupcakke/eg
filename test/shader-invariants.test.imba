import {group, test, expect} from './harness'
import shaderMaps from '../src/render/shaders.gen.mjs'
import {MAX_SHAPES} from '../src/core/constants'

group 'shader invariants'

def uniformNames src
	let out = []
	let decls = src.match(/uniform\s+(?:highp\s+|mediump\s+|lowp\s+)?(?:float|int|bool|vec2|vec3|vec4|ivec2|ivec4|sampler2D|samplerCube|mat3|mat4)\s+[^;{]+;/g)
	if decls == null
		return out
	for decl in decls
		let body = decl.replace(/^uniform\s+(?:highp\s+|mediump\s+|lowp\s+)?(?:float|int|bool|vec2|vec3|vec4|ivec2|ivec4|sampler2D|samplerCube|mat3|mat4)\s+/, '').replace(/;$/, '')
		for part in body.split(',')
			let name = part.trim().replace(/\[[^\]]*\]/, '').split('=')[0].trim()
			if name.length > 0
				out.push name
	out

def occurrencesOf src, name
	let re = new RegExp("\\b" + name + "\\b", 'g')
	let hits = src.match(re)
	hits == null ? 0 : hits.length

test 'es300 and es100 maps ship all 18 roots in both naming schemes' do
	let a = Object.keys(shaderMaps.gl2).sort()
	let plain = []
	for key in Object.keys(shaderMaps.gl1)
		if key.indexOf('/') < 0
			plain.push key
	plain = plain.sort()
	expect(a.length).toBe 18
	expect(plain.length).toBe 18
	expect(a.join('|')).toBe plain.join('|')
	for key in a
		expect(shaderMaps.gl1.hasOwnProperty("es100/{key}")).toBeTruthy
		expect(shaderMaps.gl1["es100/{key}"]).toBe shaderMaps.gl1[key]

test 'es300 sources carry the 300 es version directive first' do
	for own name, src of shaderMaps.gl2
		expect(src.indexOf('#version 300 es\n')).toBe 0

test 'es100 sources carry the 100 version directive first' do
	for own name, src of shaderMaps.gl1
		expect(src.indexOf('#version 100\n')).toBe 0

test 'includes are fully resolved and comments stripped' do
	for own name, src of shaderMaps.gl2
		expect(src.indexOf('#include') < 0).toBeTruthy
		expect(src.indexOf('/*') < 0).toBeTruthy
		expect(src.indexOf('//') < 0).toBeTruthy
	for own name, src of shaderMaps.gl1
		expect(src.indexOf('#include') < 0).toBeTruthy
		expect(src.indexOf('/*') < 0).toBeTruthy
		expect(src.indexOf('//') < 0).toBeTruthy

test 'no template interpolation residue survives inlining' do
	for own name, src of shaderMaps.gl2
		expect(src.indexOf('${') < 0).toBeTruthy
		expect(src.indexOf('__GK_') < 0).toBeTruthy
	for own name, src of shaderMaps.gl1
		expect(src.indexOf('${') < 0).toBeTruthy

test 'es300 glass shader uses std140 uniform blocks for shape data' do
	let src = shaderMaps.gl2['glass.frag']
	expect(src.indexOf('layout(std140) uniform GlassBlock') >= 0).toBeTruthy
	expect(src.indexOf('layout(std140) uniform PolyBlock') >= 0).toBeTruthy
	expect(src.indexOf("GK_MAX_SHAPES = {MAX_SHAPES}") >= 0).toBeTruthy
	expect(src.indexOf('uShape[GK_MAX_SHAPES * GK_VECS_PER_SHAPE]') >= 0).toBeTruthy

test 'es100 glass shader falls back to data textures for shape data' do
	let src = shaderMaps.gl1['glass.frag']
	expect(src.indexOf('uniform sampler2D uShapeTex;') >= 0).toBeTruthy
	expect(src.indexOf('uniform sampler2D uPolyTex;') >= 0).toBeTruthy
	expect(src.indexOf('uShapeCount') >= 0).toBeTruthy
	expect(src.indexOf('GL_OES_standard_derivatives') >= 0).toBeTruthy
	expect(src.indexOf("#define GK_MAX_SHAPES {MAX_SHAPES}") >= 0).toBeTruthy

test 'root-only uniforms are consumed by their shader body' do
	for own name, src of shaderMaps.gl2
		if /\.(frag|vert)$/.test(name) == no
			continue
		let chunkUniforms = new Set
		for own chunkName, chunkSrc of shaderMaps.gl2
			if /\.(frag|vert)$/.test(chunkName) == no
				for u in uniformNames(chunkSrc)
					chunkUniforms.add u
		for u in uniformNames(src)
			if chunkUniforms.has(u)
				continue
			expect(occurrencesOf(src, u)).toBeGreaterThanOrEqual 2
	for own name, src of shaderMaps.gl1
		if /\.(frag|vert)$/.test(name) == no
			continue
		let chunkUniforms = new Set
		for own chunkName, chunkSrc of shaderMaps.gl1
			if /\.(frag|vert)$/.test(chunkName) == no
				for u in uniformNames(chunkSrc)
					chunkUniforms.add u
		for u in uniformNames(src)
			if chunkUniforms.has(u)
				continue
			expect(occurrencesOf(src, u)).toBeGreaterThanOrEqual 2

test 'tight loop cap matches the shared shape budget' do
	for own name, src of shaderMaps.gl1
		if src.indexOf('uShapeCount') >= 0
			expect(src.indexOf("GK_MAX_SHAPES {64}") >= 0).toBeTruthy

test 'vertex stage is present in both dialects' do
	expect(shaderMaps.gl2['quad.vert'].indexOf('gl_Position') >= 0).toBeTruthy
	expect(shaderMaps.gl1['quad.vert'].indexOf('gl_Position') >= 0).toBeTruthy

test 'sdf chunk ships analytic primitives in both dialects' do
	for name in ['common', 'sdf', 'glass-body']
		expect(typeof shaderMaps.gl2[name]).toBe 'string'
		expect(typeof shaderMaps.gl1[name]).toBe 'string'
		expect(shaderMaps.gl2[name].length).toBeGreaterThan 100
		expect(shaderMaps.gl1[name].length).toBeGreaterThan 100
	expect(shaderMaps.gl2['sdf'].indexOf('sdRound') >= 0).toBeTruthy
