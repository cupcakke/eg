import {spawnSync} from 'node:child_process'
import {existsSync, mkdirSync, readFileSync, writeFileSync, rmSync, readdirSync} from 'node:fs'
import {join, dirname, resolve} from 'node:path'
import {fileURLToPath} from 'node:url'
import {gzipSync} from 'node:zlib'
import * as esbuild from 'esbuild'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(root, 'dist')
const tmp = join(root, '.build-tmp')

const BUDGETS = [
	{file: 'glasskit.mjs', maxGzip: 180 * 1024, label: 'library ESM'},
	{file: 'glasskit.js', maxGzip: 190 * 1024, label: 'library IIFE'},
	{file: 'glasskit.css', maxGzip: 48 * 1024, label: 'stylesheet'}
]

function imbaBin() {
	const p = join(root, 'node_modules', '.bin', 'imba')
	if (!existsSync(p)) {
		console.error('[build] imba CLI not found — run `npm install` first')
		process.exit(1)
	}
	return p
}

function sh(cmd, args, label) {
	const res = spawnSync(cmd, args, {cwd: root, stdio: 'inherit'})
	if (res.status !== 0) {
		console.error(`[build] ${label} failed (exit ${res.status})`)
		process.exit(1)
	}
}

function buildCss() {
	const dir = join(root, 'src', 'styles')
	const order = ['reset.css', 'tokens.css', 'typography.css', 'components.css', 'fallback.css']
	let out = '@charset "UTF-8";\n'
	for (const name of order) {
		let src = readFileSync(join(dir, name), 'utf8')
		src = src.replace(/\/\*[\s\S]*?\*\//g, '')
		src = src.replace(/(^|[^:])\/\/[^\n]*/g, '$1')
		src = src.replace(/\n\s*\n/g, '\n').trim()
		out += src + '\n'
	}
	writeFileSync(join(dist, 'glasskit.css'), out)
}

function gzipSize(file) {
	return gzipSync(readFileSync(file), {level: 9}).length
}

function fmtBytes(n) {
	return `${(n / 1024).toFixed(1)}kb`
}

rmSync(tmp, {recursive: true, force: true})
rmSync(dist, {recursive: true, force: true})
mkdirSync(dist, {recursive: true})
mkdirSync(tmp, {recursive: true})

sh(process.execPath, [join(root, 'tools', 'glsl-inline.mjs')], 'glsl-inline')
sh(imbaBin(), ['build', join('src', 'index.imba'), '--web', '-o', tmp], 'raw browser bundle')

const manifest = JSON.parse(readFileSync(join(tmp, 'manifest.json'), 'utf8'))
if (!manifest.main) {
	console.error('[build] manifest.json missing "main" entry')
	process.exit(1)
}
const rawEntry = join(tmp, manifest.main)
if (!existsSync(rawEntry)) {
	console.error(`[build] raw bundle not found at ${rawEntry}`)
	process.exit(1)
}

await esbuild.build({
	entryPoints: [rawEntry],
	outfile: join(dist, 'glasskit.mjs'),
	format: 'esm',
	bundle: false,
	minify: true,
	sourcemap: true,
	target: 'es2020',
	logLevel: 'warning'
})

await esbuild.build({
	entryPoints: [rawEntry],
	outfile: join(dist, 'glasskit.js'),
	format: 'iife',
	globalName: 'GlassKit',
	bundle: true,
	minify: true,
	sourcemap: true,
	target: 'es2020',
	logLevel: 'warning'
})

buildCss()

const report = {builtAt: new Date().toISOString(), files: []}
let failed = false
for (const b of BUDGETS) {
	const path = join(dist, b.file)
	if (!existsSync(path)) {
		console.error(`[build] MISSING ${b.file}`)
		failed = true
		continue
	}
	const gz = gzipSize(path)
	const over = gz > b.maxGzip
	if (over) failed = true
	report.files.push({file: b.file, label: b.label, gzipBytes: gz, budgetGzipBytes: b.maxGzip, ok: !over})
	console.log(`[build] ${b.file.padEnd(14)} gzip ${fmtBytes(gz).padStart(8)} / budget ${fmtBytes(b.maxGzip).padStart(8)} ${over ? 'OVER BUDGET' : 'ok'}`)
}
writeFileSync(join(dist, 'report.json'), JSON.stringify(report, null, 2) + '\n')
rmSync(tmp, {recursive: true, force: true})

if (failed) {
	console.error('[build] size budget exceeded')
	process.exit(1)
}
console.log('[build] dist ready: glasskit.mjs, glasskit.js, glasskit.css')
