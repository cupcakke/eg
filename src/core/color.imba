import {clamp, saturate, lerp} from './math'

export def srgbToLinearChannel c
	if c <= 0.04045
		c / 12.92
	else
		Math.pow((c + 0.055) / 1.055, 2.4)

export def linearToSrgbChannel c
	if c <= 0.0031308
		12.92 * c
	else
		1.055 * Math.pow(c, 1 / 2.4) - 0.055

export def srgbToLinear c
	[srgbToLinearChannel(c[0]), srgbToLinearChannel(c[1]), srgbToLinearChannel(c[2]), c[3]]

export def linearToSrgb c
	[linearToSrgbChannel(c[0]), linearToSrgbChannel(c[1]), linearToSrgbChannel(c[2]), c[3]]

export def parseColor input
	if Array.isArray(input)
		let r = input[0] or 0
		let g = input[1] or 0
		let b = input[2] or 0
		let a = input[3] == undefined ? 1 : input[3]
		if r > 1 or g > 1 or b > 1
			[r / 255, g / 255, b / 255, a]
		else
			[r, g, b, a]
	elif typeof input == 'string'
		parseString input.trim!
	else
		[0, 0, 0, 1]

def parseString s
	if s[0] == '#'
		parseHex s.slice(1)
	elif s.slice(0, 4) == 'rgb(' or s.slice(0, 5) == 'rgba('
		let open = s.indexOf('(')
		let close = s.indexOf(')')
		let inner = s.slice(open + 1, close)
		let parts = inner.split(',').map do(p) Number(p)
		let r = (parts[0] or 0) / 255
		let g = (parts[1] or 0) / 255
		let b = (parts[2] or 0) / 255
		let a = parts.length > 3 ? clamp(parts[3], 0, 1) : 1
		[r, g, b, a]
	else
		[0, 0, 0, 1]

def parseHex h
	if h.length == 3 or h.length == 4
		let r = parseInt(h[0] + h[0], 16) / 255
		let g = parseInt(h[1] + h[1], 16) / 255
		let b = parseInt(h[2] + h[2], 16) / 255
		let a = h.length == 4 ? parseInt(h[3] + h[3], 16) / 255 : 1
		[r, g, b, a]
	elif h.length == 6 or h.length == 8
		let r = parseInt(h.slice(0, 2), 16) / 255
		let g = parseInt(h.slice(2, 4), 16) / 255
		let b = parseInt(h.slice(4, 6), 16) / 255
		let a = h.length == 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1
		[r, g, b, a]
	else
		[0, 0, 0, 1]

export def toHex c
	let r = Math.round(clamp(c[0], 0, 1) * 255)
	let g = Math.round(clamp(c[1], 0, 1) * 255)
	let b = Math.round(clamp(c[2], 0, 1) * 255)
	let s = '#' + toPart(r) + toPart(g) + toPart(b)
	if c[3] != undefined and c[3] < 1
		s += toPart Math.round(clamp(c[3], 0, 1) * 255)
	s

def toPart v
	let s = v.toString(16)
	if s.length < 2 then '0' + s else s

export def linearSrgbToOklab r, g, b
	let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	let l_ = Math.cbrt l
	let m_ = Math.cbrt m
	let s_ = Math.cbrt s
	let L = 0.2104542553 * l_ + 0.793617785 * m_ - 0.0040720468 * s_
	let a = 1.9779984951 * l_ - 2.428592205 * m_ + 0.4505937099 * s_
	let bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.808675766 * s_
	[L, a, bb]

export def oklabToLinearSrgb L, a, bb
	let l_ = L + 0.3963377774 * a + 0.2158037573 * bb
	let m_ = L - 0.1055613458 * a - 0.0638541728 * bb
	let s_ = L - 0.0894841775 * a - 1.291485548 * bb
	let l = l_ * l_ * l_
	let m = m_ * m_ * m_
	let s = s_ * s_ * s_
	let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	let b = -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s
	[r, g, b]

export def srgbToOklab c
	let lin = srgbToLinear c
	linearSrgbToOklab lin[0], lin[1], lin[2]

export def oklabToSrgb lab
	let rgb = oklabToLinearSrgb lab[0], lab[1], lab[2]
	linearToSrgb [rgb[0], rgb[1], rgb[2], 1]

export def relativeLuminance c
	let r = srgbToLinearChannel c[0]
	let g = srgbToLinearChannel c[1]
	let b = srgbToLinearChannel c[2]
	0.2126 * r + 0.7152 * g + 0.0722 * b

export def contrastRatio c1, c2
	let l1 = relativeLuminance c1
	let l2 = relativeLuminance c2
	let hi = Math.max l1, l2
	let lo = Math.min l1, l2
	(hi + 0.05) / (lo + 0.05)

export def premultiply c
	[c[0] * c[3], c[1] * c[3], c[2] * c[3], c[3]]

export def unpremultiply c
	if c[3] <= 0
		[0, 0, 0, 0]
	else
		[c[0] / c[3], c[1] / c[3], c[2] / c[3], c[3]]

export def mix a, b, t
	[lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t)]

export def mixOklab a, b, t
	let la = srgbToOklab a
	let lb = srgbToOklab b
	let out = oklabToSrgb [lerp(la[0], lb[0], t), lerp(la[1], lb[1], t), lerp(la[2], lb[2], t)]
	out[3] = lerp a[3], b[3], t
	out

export def applyTint backdrop, tint, strength
	let s = saturate strength
	if s <= 0
		return [backdrop[0], backdrop[1], backdrop[2], backdrop[3]]
	let lb = srgbToOklab backdrop
	let lt = srgbToOklab tint
	let out = oklabToSrgb [lb[0], lerp(lb[1], lt[1], s), lerp(lb[2], lt[2], s)]
	out[3] = backdrop[3]
	out

export def withAlpha c, alpha
	[c[0], c[1], c[2], alpha]

export def luminanceAdjustColor c, amount
	if approxZero amount
		return [c[0], c[1], c[2], c[3]]
	let lab = srgbToOklab c
	let L = if amount >= 0 then lab[0] + (1 - lab[0]) * amount else lab[0] * (1 + amount)
	let out = oklabToSrgb [clamp(L, 0, 1), lab[1], lab[2]]
	out[3] = c[3]
	out

def approxZero v
	Math.abs(v) < 1e-6
