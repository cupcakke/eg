export function sdRoundBox(px, py, hw, hh, r) {
	const qx = Math.abs(px) - (hw - r)
	const qy = Math.abs(py) - (hh - r)
	const ax = Math.max(qx, 0)
	const ay = Math.max(qy, 0)
	return Math.hypot(ax, ay) + Math.min(Math.max(qx, qy), 0) - r
}

export function sdCircle(px, py, r) {
	return Math.hypot(px, py) - r
}

export function sdCapsule(px, py, hw, hh) {
	const r = Math.min(hw, hh)
	return sdRoundBox(px, py, hw, hh, r)
}

export function sminPoly(a, b, k) {
	if (k <= 0) return Math.min(a, b)
	const h = Math.min(Math.max(0.5 + 0.5 * (b - a) / k, 0), 1)
	return b * (1 - h) + a * h - k * h * (1 - h)
}

const SCENES = {
	'rounded-rect-ramp': (x, y) => sdRoundBox(x, y, 60, 30, 10),
	'capsule-union': (x, y) => sminPoly(sdCapsule(x + 40, y, 50, 18), sdCapsule(x - 40, y + 6, 50, 18), 24),
	'circle-grid': (x, y) => {
		let d = 1e9
		for (let gy = -1; gy <= 1; gy++) for (let gx = -1; gx <= 1; gx++) d = Math.min(d, sdCircle(x - gx * 52, y - gy * 52, 16))
		return d
	},
	'ring-aa': (x, y) => Math.abs(sdCircle(x, y, 45)) - 6
}

export const GOLDEN_SCENE_IDS = Object.keys(SCENES)

export function rasterizeScene(sceneId, size = 64, scale = 1) {
	const fn = SCENES[sceneId]
	if (!fn) throw new Error(`unknown golden scene: ${sceneId}`)
	const out = new Uint8Array(size * size)
	for (let y = 0; y < size; y++) {
		for (let x = 0; x < size; x++) {
			const px = (x - size / 2 + 0.5) * scale
			const py = (y - size / 2 + 0.5) * scale
			const d = fn(px, py)
			const cover = 1 - Math.min(Math.max(d + 0.5, 0), 1)
			out[y * size + x] = Math.round(cover * 255)
		}
	}
	return out
}

export function fnv1a64Hex(bytes) {
	let h1 = 0x811c9dc5
	let h2 = 0xcbf29ce4
	for (let i = 0; i < bytes.length; i++) {
		const b = bytes[i]
		h1 = Math.imul(h1 ^ (b & 0x0f), 0x01000193) >>> 0
		h2 = Math.imul(h2 ^ (b >> 4), 0x01000193) >>> 0
		const mix = ((h1 >>> 3) | (h2 << 2)) >>> 0
		h1 = (h1 + mix) >>> 0
		h2 = Math.imul(h2 ^ mix, 0x01000193) >>> 0
	}
	return (h1 >>> 0).toString(16).padStart(8, '0') + (h2 >>> 0).toString(16).padStart(8, '0')
}

export function sceneDigest(sceneId) {
	return fnv1a64Hex(rasterizeScene(sceneId))
}
