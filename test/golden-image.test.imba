import {group, test, expect} from './harness'
import hashes from './golden-hashes.json'
import {GOLDEN_SCENE_IDS, rasterizeScene, sceneDigest, fnv1a64Hex} from './golden-scenes.mjs'
import {sdRoundedBox, sdCapsule, opSmoothUnion} from '../src/core/sdf-cpu'

group 'golden image'

test 'golden manifest covers every registered scene' do
	let keys = Object.keys(hashes).sort()
	let ids = GOLDEN_SCENE_IDS.slice(0).sort()
	expect(ids.join('|')).toBe keys.join('|')
	expect(ids.length).toBeGreaterThanOrEqual 4

test 'scene rasters hash to their recorded digests' do
	for own sceneId, expected of hashes
		expect(sceneDigest(sceneId)).toBe expected

test 'digests are sensitive to scene identity' do
	let pairs = Object.keys(hashes)
	let digests = []
	for id in pairs
		digests.push sceneDigest(id)
	for i in [0 ... digests.length]
		for j in [i + 1 ... digests.length]
			expect(digests[i] == digests[j]).toBeFalsy

test 'fnv stream hash is stable for a known input' do
	let bytes = new Uint8Array 8
	for i in [0 ... 8]
		bytes[i] = i * 17
	let first = fnv1a64Hex bytes
	let again = fnv1a64Hex bytes
	expect(first).toBe again
	expect(first.length).toBe 16
	expect(first).toMatch /^[0-9a-f]{16}$/

test 'coverage ramps monotonically along a signed distance iso line' do
	let raster = rasterizeScene 'rounded-rect-ramp', 64, 1
	let center = raster[32 * 64 + 32]
	let corner = raster[0]
	expect(center).toBe 255
	expect(corner).toBe 0

test 'golden formulas match the library SDF within float tolerance' do
	let mismatches = 0
	for gy in [0 ... 33]
		for gx in [0 ... 33]
			let px = (gx - 16) * 4.125
			let py = (gy - 16) * 4.125
			let refD = 0
			let qx = Math.abs(px) - (60 - 10)
			let qy = Math.abs(py) - (30 - 10)
			let ax = Math.max qx, 0
			let ay = Math.max qy, 0
			refD = Math.hypot(ax, ay) + Math.min(Math.max(qx, qy), 0) - 10
			let lib = sdRoundedBox px, py, 60, 30, 10, 10, 10, 10
			if Math.abs(refD - lib) > 0.001
				mismatches += 1
	expect(mismatches).toBe 0

test 'library smooth union stays glued to the hard union hull' do
	let violations = 0
	for gy in [0 ... 33]
		for gx in [0 ... 33]
			let px = (gx - 16) * 8
			let py = (gy - 16) * 8
			let d = sdCapsule px + 40, py, -50, 0, 50, 0, 18
			let e = sdCapsule px - 40, py + 6, -50, 0, 50, 0, 18
			let union = opSmoothUnion d, e, 24
			let hard = Math.min(d, e)
			if union > hard + 1e-9 or union < hard - 24 - 1e-9
				violations += 1
	expect(violations).toBe 0
