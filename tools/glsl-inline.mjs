import {readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync} from 'node:fs'
import {join, dirname, resolve} from 'node:path'
import {fileURLToPath} from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const shaderRoot = join(root, 'src', 'render', 'shaders')
const outFile = join(root, 'src', 'render', 'shaders.gen.mjs')
const outImba = join(root, 'src', 'render', 'shaders.gen.imba')

const ES3_HEADER = `#version 300 es
precision highp float;
precision highp int;
`
const ES100_HEADER = `#version 100
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
`
const INCLUDE_RE = /^\s*#include\s+([A-Za-z0-9_\-./]+)\s*$/
const UNIFORM_RE = /^\s*uniform\s+(?:highp\s+|mediump\s+|lowp\s+)?(sampler2D|samplerCube|float|int|bool|vec2|vec3|vec4|mat2|mat3|mat4)\s+([A-Za-z0-9_]+)(\s*\[\s*\d+\s*\])?\s*;/m

function stripComments(src) {
	src = src.replace(/\/\*[\s\S]*?\*\//g, '')
	src = src.replace(/(^|[^:])\/\/[^\n]*/g, '$1')
	return src
}

function readGlsl(file, stack, errors) {
	if (stack.includes(file)) {
		errors.push(`include cycle: ${[...stack, file].map(f => f.split('/shaders/')[1]).join(' -> ')}`)
		return ''
	}
	if (!existsSync(file)) {
		errors.push(`missing include: ${file} (from ${stack[stack.length - 1]})`)
		return ''
	}
	const dir = dirname(file)
	let src = readFileSync(file, 'utf8')
	const lines = src.split('\n')
	const out = []
	const nextStack = [...stack, file]
	for (const line of lines) {
		const m = INCLUDE_RE.exec(line)
		if (m) {
			const name = m[1].endsWith('.glsl') ? m[1] : `${m[1]}.glsl`
			out.push(readGlsl(join(dir, name), nextStack, errors))
		} else {
			out.push(line)
		}
	}
	return out.join('\n')
}

function liftDirectives(body) {
	const extensions = []
	const defines = []
	const rest = []
	for (const rawLine of body.split('\n')) {
		const line = rawLine.trim()
		if (line.startsWith('#extension ')) extensions.push(line)
		else if (line.startsWith('#version ')) continue
		else rest.push(rawLine)
	}
	return {extensions, defines, rest: rest.join('\n')}
}

function checkUniforms(rootSource, fullSource, fileLabel, errors) {
	const lines = rootSource.split('\n')
	for (const line of lines) {
		const trimmed = line.trim()
		if (INCLUDE_RE.test(trimmed)) continue
		const m = new RegExp(UNIFORM_RE.source).exec(trimmed)
		if (m) {
			const name = m[2]
			const uses = fullSource.split(new RegExp(`\\b${name}\\b`, 'g')).length - 1
			if (uses < 2) errors.push(`${fileLabel}: uniform '${name}' is declared but never used`)
		}
	}
}

function collectGlsl(dir) {
	if (!existsSync(dir)) return []
	return readdirSync(dir).filter(f => f.endsWith('.glsl')).sort()
}

function buildSet(dirName, header, errors, warnings) {
	const dir = dirName ? join(shaderRoot, dirName) : shaderRoot
	const prefix = dirName ? `${dirName}/` : ''
	const map = {}
	for (const file of collectGlsl(dir)) {
		const full = join(dir, file)
		const label = `${prefix}${file}`
		const rootSource = readFileSync(full, 'utf8')
		let body = readGlsl(full, [], errors)
		body = stripComments(body)
		const {extensions, rest} = liftDirectives(body)
		const flat = [header.replace(/\n$/, ''), ...extensions, rest].join('\n').replace(/\n{3,}/g, '\n\n').trim() + '\n'
		const isMain = /\.(frag|vert)\.glsl$/.test(file)
		if (isMain && !/void\s+main\s*\(/.test(flat)) errors.push(`${label}: no void main() found`)
		if (isMain) checkUniforms(rootSource, rest, label, errors)
		const key = file.replace(/\.glsl$/, '')
		map[key] = flat
	}
	return map
}

function imbaString(s) {
	return `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\r/g, '\\r').replace(/\n/g, '\\n').replace(/\t/g, '\\t')}'`
}

function toModule(map, imbaMode = false) {
	const lines = ['{']
	for (const key of Object.keys(map).sort()) {
		const k = imbaMode ? imbaString(key) : JSON.stringify(key)
		const v = imbaMode ? imbaString(map[key]) : JSON.stringify(map[key])
		lines.push(`${k}: ${v},`)
	}
	lines.push('}')
	return lines.join('\n')
}

const errors = []
const warnings = []
const es3 = buildSet('', ES3_HEADER, errors, warnings)
const es100 = buildSet('es100', ES100_HEADER, errors, warnings)

if (Object.keys(es3).length !== Object.keys(es100).length) {
	warnings.push(`ES3 set has ${Object.keys(es3).length} files but ES100 set has ${Object.keys(es100).length}`)
}

const shaders100Aug = {}
for (const [k, v] of Object.entries(es100)) {
	shaders100Aug[k] = v
	shaders100Aug[`es100/${k}`] = v
}

const esm = `export const shaders3 = ${toModule(es3)};\nexport const shaders100 = ${toModule(shaders100Aug)};\nexport default {gl2: shaders3, gl1: shaders100};\n`
writeFileSync(outFile, esm)

const imbaSrc = `export const shaders3 = ${toModule(es3, true)}\nexport const shaders100 = ${toModule(shaders100Aug, true)}\n`
writeFileSync(outImba, imbaSrc)

for (const w of warnings) console.warn(`[glsl-inline] warning: ${w}`)
if (errors.length > 0) {
	for (const e of errors) console.error(`[glsl-inline] error: ${e}`)
	console.error(`[glsl-inline] ${errors.length} error(s) — shader generation failed`)
	process.exit(1)
}
console.log(`[glsl-inline] ${Object.keys(es3).length} ES3 + ${Object.keys(es100).length} ES100 shaders -> src/render/shaders.gen.{mjs,imba}`)
