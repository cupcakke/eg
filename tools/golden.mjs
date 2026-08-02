import {readFileSync, writeFileSync, existsSync} from 'node:fs'
import {join, dirname, resolve} from 'node:path'
import {fileURLToPath} from 'node:url'
import {GOLDEN_SCENE_IDS, sceneDigest} from '../test/golden-scenes.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const hashFile = join(root, 'test', 'golden-hashes.json')
const update = process.argv.includes('--update')

function currentHashes() {
	const out = {}
	for (const id of GOLDEN_SCENE_IDS) out[id] = sceneDigest(id)
	return out
}

if (update) {
	writeFileSync(hashFile, JSON.stringify(currentHashes(), null, 2) + '\n')
	console.log(`[golden] regenerated ${GOLDEN_SCENE_IDS.length} scene hashes -> test/golden-hashes.json`)
	process.exit(0)
}

if (!existsSync(hashFile)) {
	console.error('[golden] test/golden-hashes.json missing — run `npm run golden -- --update` to generate')
	process.exit(1)
}

const stored = JSON.parse(readFileSync(hashFile, 'utf8'))
const current = currentHashes()
let failed = 0
for (const id of GOLDEN_SCENE_IDS) {
	if (stored[id] !== current[id]) {
		console.error(`[golden] mismatch: ${id}  stored=${stored[id]}  current=${current[id]}`)
		failed++
	}
}
for (const id of Object.keys(stored)) {
	if (!(id in current)) {
		console.error(`[golden] stored hash has no matching scene: ${id}`)
		failed++
	}
}
if (failed > 0) {
	console.error(`[golden] ${failed} mismatch(es) — if the change is intentional, regenerate with npm run golden -- --update`)
	process.exit(1)
}
console.log(`[golden] ${GOLDEN_SCENE_IDS.length} scene digests verified`)
