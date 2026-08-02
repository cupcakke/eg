import {readFileSync, readdirSync, statSync, existsSync} from 'node:fs'
import {join, dirname, resolve, relative} from 'node:path'
import {fileURLToPath} from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const errors = []
const warnings = []

function walk(dir, pred) {
	const out = []
	if (!existsSync(dir)) return out
	for (const name of readdirSync(dir).sort()) {
		const full = join(dir, name)
		const st = statSync(full)
		if (st.isDirectory()) {
			if (name === 'node_modules' || name === 'dist' || name === '.test-build') continue
			out.push(...walk(full, pred))
		} else if (pred(name)) out.push(full)
	}
	return out
}

const codeFiles = [...walk(join(root, 'src'), n => /\.(imba|glsl|css)$/.test(n)), ...walk(join(root, 'demo'), n => n.endsWith('.imba')), ...walk(join(root, 'test'), n => /\.(imba|mjs)$/.test(n))]

const BANNED = [
	{re: /\b(TODO|FIXME|XXX|HACK|WIP)\b/, msg: 'leftover work marker'},
	{re: /\bconsole\.log\b/, msg: 'console.log (use the GlassKit logger)', except: rel => rel.endsWith('test/harness.imba') || rel.endsWith('src/core/logger.imba') || rel.endsWith('test/run.imba')},
	{re: /implementation left as an exercise|as an exercise to the reader/i, msg: 'non-real implementation note'},
	{re: /lorem ipsum/i, msg: 'lorem ipsum placeholder'}
]

for (const file of codeFiles) {
	const rel = relative(root, file)
	if (rel.endsWith('shaders.gen.imba') || rel.endsWith('shaders.gen.mjs')) continue
	const src = readFileSync(file, 'utf8')
	for (const b of BANNED) {
		if (b.except && b.except(rel)) continue
		if (b.re.test(src)) errors.push(`${rel}: ${b.msg}`)
	}
}

const componentFiles = walk(join(root, 'src', 'components'), n => n.endsWith('.imba'))
const allTags = []
for (const file of componentFiles) {
	const src = readFileSync(file, 'utf8')
	const found = [...src.matchAll(/^tag\s+(gk-[a-z0-9-]+)/gm)].map(m => m[1])
	if (found.length === 0 && !file.endsWith('-styles.imba')) errors.push(`${relative(root, file)}: no gk-* tag declared`)
	allTags.push(...found)
}
const css = existsSync(join(root, 'src', 'styles', 'components.css')) ? readFileSync(join(root, 'src', 'styles', 'components.css'), 'utf8') : ''
for (const tag of allTags) {
	if (!css.includes(tag)) warnings.push(`components.css: no styles for <${tag}>`)
}

const structRequired = ['src/render/shaders/common.glsl', 'src/render/shaders/es100/common.glsl', 'src/core/constants.imba', 'src/material/glass-registry.imba']
for (const rel of structRequired) {
	if (!existsSync(join(root, rel))) errors.push(`required file missing: ${rel}`)
}

for (const w of warnings) console.warn(`[lint] warning: ${w}`)
for (const e of errors) console.error(`[lint] error: ${e}`)
if (errors.length > 0) {
	console.error(`[lint] ${errors.length} error(s)`)
	process.exit(1)
}
console.log(`[lint] clean — ${codeFiles.length} files, ${allTags.length} tags`)
