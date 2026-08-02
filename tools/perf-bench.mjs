import {readFileSync, writeFileSync, existsSync} from 'node:fs'
import {join, dirname, resolve} from 'node:path'
import {fileURLToPath} from 'node:url'
import {rasterizeScene, sdRoundBox, sdCircle, sminPoly} from '../test/golden-scenes.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const budgetFile = join(root, 'tools', 'perf-budgets.json')
const update = process.argv.includes('--update')

function time(fn, iterations) {
	fn(3)
	const t0 = process.hrtime.bigint()
	for (let i = 0; i < iterations; i++) fn(i)
	const t1 = process.hrtime.bigint()
	return Number(t1 - t0) / 1e6 / iterations
}

function benchSdf24() {
	const shapes = []
	for (let i = 0; i < 24; i++) {
		shapes.push({x: ((i * 97) % 220) - 110, y: ((i * 61) % 160) - 80, hw: 20 + (i % 5) * 8, hh: 14 + (i % 3) * 10, r: 6 + (i % 4) * 4})
	}
	return time(() => {
		const W = 96
		let acc = 0
		for (let y = 0; y < W; y++) {
			for (let x = 0; x < W; x++) {
				const px = x - W / 2
				const py = y - W / 2
				let d = 1e9
				for (const s of shapes) d = sminPoly(d, sdRoundBox(px - s.x, py - s.y, s.hw, s.hh, s.r), 18)
				acc += d
			}
		}
		return acc
	}, 40)
}

function benchHistogram() {
	const buf = new Float32Array(64 * 64)
	for (let i = 0; i < buf.length; i++) buf[i] = ((i * 2654435761) % 1024) / 1024
	return time(() => {
		const hist = new Uint32Array(32)
		for (let i = 0; i < buf.length; i++) {
			const lum = buf[i]
			const bin = Math.min(31, (lum * 32) | 0)
			hist[bin]++
		}
		let p10 = 0
		let acc = 0
		for (let b = 0; b < 32; b++) {
			acc += hist[b]
			if (p10 === 0 && acc >= buf.length * 0.1) p10 = b / 31
		}
		return p10
	}, 2000)
}

function benchPack() {
	const out = new Float32Array(64 * 48)
	return time(() => {
		for (let s = 0; s < 64; s++) {
			const o = s * 48
			out[o] = s * 10
			out[o + 1] = (s * 7) % 300
			out[o + 2] = 120
			out[o + 3] = 44
			out[o + 16] = 0.12
			out[o + 40] = 1
			out[o + 41] = s % 4
		}
		return out[0]
	}, 20000)
}

function benchGoldenRaster() {
	return time(() => rasterizeScene('capsule-union', 64, 1), 200)
}

const results = {
	'sdf-24shapes-96px-ms': benchSdf24(),
	'histogram-4k-texels-ms': benchHistogram(),
	'shape-pack-64-ms': benchPack(),
	'golden-scene-raster-ms': benchGoldenRaster()
}

if (update) {
	const budgets = {}
	for (const [k, v] of Object.entries(results)) budgets[k] = Math.ceil(v * 1.6 * 100) / 100
	writeFileSync(budgetFile, JSON.stringify(budgets, null, 2) + '\n')
	console.log('[bench] budgets regenerated:')
	for (const [k, v] of Object.entries(results)) console.log(`  ${k}: ${v.toFixed(3)} ms  (budget ${budgets[k]})`)
	process.exit(0)
}

if (!existsSync(budgetFile)) {
	console.error('[bench] tools/perf-budgets.json missing — run `npm run bench -- --update`')
	process.exit(1)
}
const budgets = JSON.parse(readFileSync(budgetFile, 'utf8'))
let failed = 0
for (const [k, v] of Object.entries(results)) {
	const b = budgets[k]
	const ok = b != null && v <= b
	if (!ok) failed++
	console.log(`[bench] ${k}: ${v.toFixed(3)} ms   budget ${b} ms  ${ok ? 'OK' : 'OVER'}`)
}
if (failed > 0) {
	console.error(`[bench] ${failed} benchmark(s) over budget`)
	process.exit(1)
}
console.log('[bench] all within budget')
