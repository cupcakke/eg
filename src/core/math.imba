export const TAU = (Math.PI * 2)
export const HALF_PI = (Math.PI / 2)

export def clamp value, min, max
	if value < min
		min
	elif value > max
		max
	else
		value

export def saturate value
	clamp value, 0, 1

export def lerp a, b, t
	a + (b - a) * t

export def unlerp a, b, value
	if a == b
		0
	else
		(value - a) / (b - a)

export def remap inMin, inMax, outMin, outMax, value
	lerp outMin, outMax, saturate(unlerp(inMin, inMax, value))

export def fract value
	value - Math.floor(value)

export def smoothstep edge0, edge1, value
	let t = saturate(unlerp(edge0, edge1, value))
	t * t * (3 - 2 * t)

export def smootherstep edge0, edge1, value
	let t = saturate(unlerp(edge0, edge1, value))
	t * t * t * (t * (t * 6 - 15) + 10)

export def gauss x, sigma
	let s = Math.max 1e-6, sigma
	Math.exp(-(x * x) / (2 * s * s))

export def expDecay lambda, dt
	1 - Math.exp(-lambda * dt)

export def damp current, target, smoothing, dt
	lerp current, target, expDecay(1 / Math.max(1e-6, smoothing), dt)

export def approxEqual a, b, eps = 1e-4
	Math.abs(a - b) <= eps

export def isFiniteNumber v
	typeof v == 'number' and Number.isFinite(v)

export def length2 x, y
	Math.sqrt(x * x + y * y)

export def distance2 x1, y1, x2, y2
	length2 x2 - x1, y2 - y1

export def dot2 ax, ay, bx, byy
	ax * bx + ay * byy

export def normalize2 x, y
	let l = length2 x, y
	if l < 1e-9
		[0, 0]
	else
		[x / l, y / l]

export def signNonZero v
	if v < 0 then -1 else 1

export def roundTo value, step
	if step <= 0
		value
	else
		Math.round(value / step) * step

export def snapDpr dpr, snaps = [1, 1.5, 2, 3]
	let best = snaps[0]
	let bestDist = Math.abs(dpr - best)
	for s in snaps
		let d = Math.abs(dpr - s)
		if d < bestDist
			best = s
			bestDist = d
	best

export def solveContrastLift backdropLum, textLum, target
	let lighter = textLum >= backdropLum
	let lo = 0
	let hi = 1
	let best = 0
	for i in [0 ... 24]
		let mid = (lo + hi) / 2
		let lifted = if lighter then backdropLum + (1 - backdropLum) * mid else backdropLum * (1 - mid)
		let l1 = Math.max lifted, textLum
		let l2 = Math.min lifted, textLum
		let ratio = (l1 + 0.05) / (l2 + 0.05)
		if ratio >= target
			best = mid
			hi = mid
		else
			lo = mid
	best
