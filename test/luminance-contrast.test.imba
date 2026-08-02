import {group, test, expect} from './harness'
import {histogramFromLuminance, percentileFromHistogram, meanLuminance, solveLuminosityAdjust, solveLegibility} from '../src/material/luminance-probe'
import {ensureContrast, contrastOf, textColorForSurface} from '../src/a11y/contrast'
import {relativeLuminance, contrastRatio, srgbToLinearChannel, linearToSrgbChannel, srgbToOklab, oklabToSrgb, premultiply, unpremultiply, mixOklab} from '../src/core/color'
import {HISTOGRAM_BINS} from '../src/core/constants'

group 'luminance'

test 'histogram bins cover full range' do
	let samples = new Float32Array 256
	for i in [0 ... 256]
		samples[i] = i / 255
	let hist = histogramFromLuminance samples, 256
	let total = 0
	for b in [0 ... HISTOGRAM_BINS]
		total += hist[b]
	expect(total).toBe 256

test 'percentiles land on correct bins' do
	let samples = new Float32Array 100
	for i in [0 ... 100]
		samples[i] = i / 100
	let hist = histogramFromLuminance samples, 100
	let p10 = percentileFromHistogram hist, 100, 0.10
	let p90 = percentileFromHistogram hist, 100, 0.90
	expect(p10).toBeCloseTo 0.10, 0.05
	expect(p90).toBeCloseTo 0.90, 0.05

test 'mean matches analytic mean' do
	let samples = new Float32Array [0.25, 0.25, 0.75, 0.75]
	let m = meanLuminance samples, 4
	expect(m).toBeCloseTo 0.5

test 'luminosity adjust grows when the surface sits further from target' do
	let darkText = [0.11, 0.11, 0.13, 1]
	let near = solveLuminosityAdjust 0.2, darkText, 4.5
	let far = solveLuminosityAdjust 0.05, darkText, 4.5
	expect(near > 0).toBeTruthy
	expect(far > near).toBeTruthy

test 'luminosity adjust is zero when target already met' do
	let darkText = [0.11, 0.11, 0.13, 1]
	expect(solveLuminosityAdjust(0.6, darkText, 4.5)).toBeCloseTo 0, 1e-9

group 'contrast-matrix'

test 'legibility solver holds target across backdrop grid' do
	let failures = []
	for step in [0 ... 25]
		let meanLum = 0.02 + step * 0.038
		for clearVariant in [no, yes]
			for increaseContrast in [no, yes]
				let p10 = Math.max 0, meanLum - 0.08
				let p90 = Math.min 1, meanLum + 0.08
				let r = solveLegibility meanLum, p10, p90, clearVariant, increaseContrast
				let target = increaseContrast ? 7.0 : 4.5
				if r.measuredContrast < target - 0.06 and r.lowDetail == no
					failures.push [meanLum, clearVariant, increaseContrast, r.measuredContrast]
	expect(failures.length).toBe 0

test 'clear variant over bright backdrop engages dimming' do
	let r = solveLegibility 0.9, 0.85, 0.95, yes, no
	expect(r.dimming > 0.2).toBeTruthy

test 'regular variant over bright backdrop keeps dimming off' do
	let r = solveLegibility 0.9, 0.85, 0.95, no, no
	expect(r.dimming).toBe 0

test 'on-glass css is one of two reading colors' do
	let r1 = solveLegibility 0.05, 0.02, 0.09, no, no
	let r2 = solveLegibility 0.95, 0.9, 0.99, no, no
	expect(r1.onGlassCss).toBe 'rgb(245, 245, 247)'
	expect(r2.onGlassCss).toBe 'rgb(28, 28, 33)'

test 'ensureContrast reaches target or saturates gracefully' do
	for step in [0 ... 11]
		let bgV = step / 10
		let bg = [bgV, bgV, bgV, 1]
		let fg = [0.5, 0.5, 0.5, 1]
		let out = ensureContrast fg, bg, 4.5
		let c = contrastOf out, bg
		let bestDark = contrastOf [0, 0, 0, 1], bg
		let bestLight = contrastOf [1, 1, 1, 1], bg
		let best = Math.max bestDark, bestLight
		expect(c >= Math.min(4.5, best) - 0.05).toBeTruthy

test 'textColorForSurface flips around the midpoint' do
	expect(textColorForSurface([0.95, 0.95, 0.95, 1])[0] < 0.5).toBeTruthy
	expect(textColorForSurface([0.05, 0.05, 0.05, 1])[0] > 0.5).toBeTruthy

group 'color-math'

test 'srgb linear roundtrip' do
	for v in [0, 0.0031308, 0.04, 0.5, 1]
		expect(linearToSrgbChannel(srgbToLinearChannel(v))).toBeCloseTo v, 1e-9

test 'oklab roundtrip is near-exact' do
	for rgb in [[1, 0, 0], [0, 1, 0], [0, 0, 1], [0.25, 0.5, 0.75], [0.9, 0.87, 0.2]]
		let lab = srgbToOklab rgb
		let back = oklabToSrgb lab
		for i in [0 ... 3]
			expect(back[i]).toBeCloseTo rgb[i], 0.002

test 'contrast ratio is symmetric and ratio scale' do
	let c = contrastRatio [0, 0, 0, 1], [1, 1, 1, 1]
	expect(c).toBeCloseTo 21, 0.05
	expect(c).toBeCloseTo contrastRatio([1, 1, 1, 1], [0, 0, 0, 1]), 1e-9

test 'relative luminance of primaries sums to one' do
	let r = relativeLuminance [1, 0, 0, 1]
	let g = relativeLuminance [0, 1, 0, 1]
	let b = relativeLuminance [0, 0, 1, 1]
	expect(r + g + b).toBeCloseTo 1, 1e-6

test 'premultiply roundtrip' do
	let c = [0.5, 0.25, 0.125, 0.5]
	let back = unpremultiply premultiply(c)
	for i in [0 ... 3]
		expect(back[i]).toBeCloseTo c[i], 1e-9

test 'oklab mix at endpoints returns inputs' do
	let a = [0.2, 0.4, 0.6, 1]
	let b = [0.8, 0.7, 0.1, 1]
	let m0 = mixOklab a, b, 0
	let m1 = mixOklab a, b, 1
	for i in [0 ... 3]
		expect(m0[i]).toBeCloseTo a[i], 0.004
		expect(m1[i]).toBeCloseTo b[i], 0.004
