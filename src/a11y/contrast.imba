import {parseColor, contrastRatio, relativeLuminance, srgbToOklab, oklabToSrgb} from '../core/color'
import {clamp} from '../core/math'
import {CONTRAST_TARGET, CONTRAST_TARGET_HIGH} from '../core/constants'

export def contrastOf fg, bg
	let a = if Array.isArray(fg) then fg else parseColor(fg)
	let b = if Array.isArray(bg) then bg else parseColor(bg)
	contrastRatio a, b

export def meetsContrast fg, bg, target = CONTRAST_TARGET
	contrastOf(fg, bg) >= target

export def ensureContrast fg, bg, target = CONTRAST_TARGET, maxSteps = 12
	let a = if Array.isArray(fg) then fg.slice(0) else parseColor(fg)
	let b = if Array.isArray(bg) then bg else parseColor(bg)
	if contrastRatio(a, b) >= target
		return a
	let bgLum = relativeLuminance b
	let lab = srgbToOklab a
	let dir = if bgLum > 0.5 then -1 else 1
	let lo = 0
	let hi = 1
	let bestL = clamp(lab[0] + dir * 1, 0, 1)
	for i in [0 ... 24]
		let mid = (lo + hi) / 2
		let L = clamp(lab[0] + dir * mid, 0, 1)
		let candidate = oklabToSrgb [L, lab[1], lab[2]]
		candidate[3] = a[3]
		if contrastRatio(candidate, b) >= target
			bestL = L
			hi = mid
		else
			lo = mid
	let out = oklabToSrgb [bestL, lab[1], lab[2]]
	out[3] = a[3]
	out

export def textColorForSurface surfaceColor
	let c = if Array.isArray(surfaceColor) then surfaceColor else parseColor(surfaceColor)
	let lum = relativeLuminance c
	if lum > 0.36
		[0.11, 0.11, 0.13, 1]
	else
		[0.97, 0.97, 0.98, 1]

export def requiredTarget increaseContrast = no
	if increaseContrast then CONTRAST_TARGET_HIGH else CONTRAST_TARGET
