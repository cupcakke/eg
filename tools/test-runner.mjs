import {spawnSync} from 'node:child_process'
import {existsSync, mkdirSync, watch} from 'node:fs'
import {join, dirname, resolve} from 'node:path'
import {fileURLToPath} from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const buildDir = join(root, '.test-build')
const outFile = join(buildDir, 'run.mjs')
const watchMode = process.argv.includes('--watch')

function imbaBin() {
	const p = join(root, 'node_modules', '.bin', 'imba')
	if (!existsSync(p)) {
		console.error('[test] imba CLI not found — run `npm install` first')
		process.exit(1)
	}
	return p
}

function compile() {
	mkdirSync(buildDir, {recursive: true})
	const res = spawnSync(imbaBin(), ['build', join(root, 'test', 'run.imba'), '--platform', 'node', '--esm', '-o', buildDir], {cwd: root, stdio: 'inherit'})
	if (res.status !== 0) {
		console.error('[test] imba build failed')
		return false
	}
	if (!existsSync(outFile)) {
		console.error(`[test] compiled runner missing at ${outFile}`)
		return false
	}
	return true
}

function runTests() {
	const res = spawnSync(process.execPath, [outFile], {cwd: root, stdio: 'inherit'})
	return res.status === 0
}

const inline = spawnSync(process.execPath, [join(root, 'tools', 'glsl-inline.mjs')], {cwd: root, stdio: 'inherit'})
if (inline.status !== 0) process.exit(1)

if (!compile()) process.exit(1)
const ok = runTests()

if (watchMode) {
	console.log('[test] watching for changes…')
	let timer = null
	const rerun = () => {
		clearTimeout(timer)
		timer = setTimeout(() => {
			const inline2 = spawnSync(process.execPath, [join(root, 'tools', 'glsl-inline.mjs')], {cwd: root, stdio: 'inherit'})
			if (inline2.status !== 0) return
			if (compile()) runTests()
		}, 150)
	}
	watch(join(root, 'src'), {recursive: true}, rerun)
	watch(join(root, 'test'), {recursive: true}, rerun)
} else {
	process.exit(ok ? 0 : 1)
}
