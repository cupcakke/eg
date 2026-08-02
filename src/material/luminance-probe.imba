import {Texture} from '../render/texture'
import {Framebuffer} from '../render/framebuffer'
import {HISTOGRAM_BINS, BRIGHT_LUM_THRESHOLD, DEFAULT_DIMMING, LUM_SMOOTHING_TAU} from '../core/constants'
import {relativeLuminance, contrastRatio, linearToSrgbChannel, luminanceAdjustColor} from '../core/color'
import {clamp} from '../core/math'
import {settings} from '../core/settings'
import {preferences} from '../a11y/preferences'
import {logger} from '../core/logger'
import {bus} from '../core/event-bus'

const DARK_TEXT = [0.11, 0.11, 0.13, 1]
const LIGHT_TEXT = [0.96, 0.96, 0.97, 1]

export def histogramFromLuminance samples, count, bins = HISTOGRAM_BINS
	let hist = new Uint32Array bins
	for i in [0 ... count]
		let v = clamp samples[i], 0, 1
		let bin = Math.min bins - 1, Math.floor(v * bins)
		hist[bin] += 1
	hist

export def percentileFromHistogram hist, total, p
	let bins = hist.length
	let target = Math.max 0, p * total - 0.5
	let cum = 0
	for i in [0 ... bins]
		cum += hist[i]
		if cum > target
			let prev = cum - hist[i]
			let frac = hist[i] > 0 ? (target - prev) / hist[i] : 0
			return (i + clamp(frac, 0, 1)) / bins
	1

export def meanLuminance samples, count
	let sum = 0
	for i in [0 ... count]
		sum += samples[i]
	count > 0 ? sum / count : 0

def surfaceAtAdjust linearLum, adjust
	let srgb = linearToSrgbChannel clamp(linearLum, 0, 1)
	let lifted = luminanceAdjustColor [srgb, srgb, srgb, 1], adjust
	relativeLuminance lifted

export def solveLuminosityAdjust linearLum, textColor, target
	let ratioAt = do(adj)
		let L = surfaceAtAdjust linearLum, adj
		(L + 0.05) / (relativeLuminance(textColor) + 0.05) >= target or (relativeLuminance(textColor) + 0.05) / (L + 0.05) >= target
	if ratioAt(0)
		return 0
	let lightFirst = relativeLuminance(textColor) >= linearLum
	let lo = 0
	let hi = 1
	for i in [0 ... 28]
		let mid = (lo + hi) / 2
		let adj = lightFirst ? -mid : mid
		if ratioAt(adj)
			hi = mid
		else
			lo = mid
	let adj = lightFirst ? -hi : hi
	Math.round(adj * 1000) / 1000

export def solveLegibility meanLum, p10, p90, clearVariant = no, increaseContrast = no
	let target = if increaseContrast then settings.contrastHigh else settings.minContrast
	let working = clearVariant ? p10 * 0.4 + meanLum * 0.6 : meanLum
	let srgb = linearToSrgbChannel clamp(working, 0, 1)
	let surface = [srgb, srgb, srgb, 1]
	let darkRatio = contrastRatio surface, DARK_TEXT
	let lightRatio = contrastRatio surface, LIGHT_TEXT
	let useDark = darkRatio >= lightRatio
	let text = useDark ? DARK_TEXT : LIGHT_TEXT
	let adjust = solveLuminosityAdjust working, text, target
	let effectiveSurface = luminanceAdjustColor surface, adjust
	let finalRatio = contrastRatio effectiveSurface, text
	let dimming = 0
	if clearVariant and meanLum > BRIGHT_LUM_THRESHOLD
		dimming = DEFAULT_DIMMING
	let detail = p90 - p10
	{
		adjust: adjust
		dimming: dimming
		onGlassColor: (useDark ? DARK_TEXT : LIGHT_TEXT)
		onGlassCss: (useDark ? 'rgb(28, 28, 33)' : 'rgb(245, 245, 247)')
		measuredContrast: finalRatio
		target: target
		detail: detail
		lowDetail: detail < 0.015
	}

export class LuminanceProbe
	def constructor gl, env
		self.gl = gl
		self.env = env
		self.atlasFb = null
		self.readBuffer = new Uint8Array 8 * 8 * 4 * 16
		self.lums = new Float32Array 64
		self.hist = new Uint32Array HISTOGRAM_BINS
		self.cols = 4
		self.smoothing = LUM_SMOOTHING_TAU

	def ensureAtlas cells
		let cols = self.cols
		let rows = Math.ceil cells / cols
		let w = 8 * cols
		let h = 8 * rows
		if self.atlasFb == null or self.atlasFb.width != w or self.atlasFb.height != Math.max(8, h)
			if self.atlasFb != null
				self.atlasFb.dispose!
			self.atlasFb = new Framebuffer self.gl,
				width: w
				height: Math.max(8, h)
				internalFormat: self.gl.RGBA
				format: self.gl.RGBA
				type: self.gl.UNSIGNED_BYTE

	def run env, containers
		let gl = self.gl
		if gl == null
			return
		let jobs = []
		for container in containers
			if container.offScreen
				continue
			for i in [0 ... container.entryCount]
				let entry = container.entryAt i
				if entry != null and entry.rectGL != null and !entry.state.noProbe
					jobs.push entry
			if jobs.length >= 16
				break
		if jobs.length == 0
			return
		ensureAtlas jobs.length
		let prog = env.programs.get 'luminance-reduce', env.shaderFor('quad.vert'), env.shaderFor('luminance-reduce.frag')
		prog.use!
		let rows = Math.ceil jobs.length / self.cols
		self.atlasFb.bind 0
		gl.disable gl.BLEND
		for j in [0 ... jobs.length]
			let entry = jobs[j]
			let rect = entry.rectGL
			let cx = j % self.cols
			let cy = Math.floor(j / self.cols)
			gl.viewport cx * 8, cy * 8, 8, 8
			gl.scissor cx * 8, cy * 8, 8, 8
			gl.enable gl.SCISSOR_TEST
			prog.u2f 'uResolution', self.atlasFb.width, self.atlasFb.height
			prog.u4f 'uDrawRect', cx * 8, cy * 8, 8, 8
			prog.uTexture 'uBackdrop', env.captureTexture, 0
			prog.u4f 'uRegion', rect.x / env.width, rect.y / env.height, (rect.x + rect.w) / env.width, (rect.y + rect.h) / env.height
			prog.u2f 'uOutSize', 8, 8
			prog.drawQuad env.quad
		gl.disable gl.SCISSOR_TEST
		self.atlasFb.unbind!
		let w = self.atlasFb.width
		let h = Math.max 8, rows * 8
		gl.bindFramebuffer gl.FRAMEBUFFER, self.atlasFb.handle
		gl.readPixels 0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, self.readBuffer
		gl.bindFramebuffer gl.FRAMEBUFFER, null
		let warnedLowDetail = no
		for j in [0 ... jobs.length]
			let entry = jobs[j]
			let cx = j % self.cols
			let cy = Math.floor(j / self.cols)
			for py in [0 ... 8]
				for px in [0 ... 8]
					let si = ((cy * 8 + py) * w + cx * 8 + px) * 4
					let r = self.readBuffer[si] / 255
					let g = self.readBuffer[si + 1] / 255
					let b = self.readBuffer[si + 2] / 255
					self.lums[py * 8 + px] = 0.2126 * r + 0.7152 * g + 0.0722 * b
			self.hist.fill 0
			for i in [0 ... 64]
				let bin = Math.min HISTOGRAM_BINS - 1, Math.floor(self.lums[i] * HISTOGRAM_BINS)
				self.hist[bin] += 1
			let mean = meanLuminance self.lums, 64
			let p10 = percentileFromHistogram self.hist, 64, 0.10
			let p90 = percentileFromHistogram self.hist, 64, 0.90
			let clearV = entry.glassVariantId == 1
			let solved = solveLegibility mean, p10, p90, clearV, preferences.increaseContrast
			let st = entry.state
			let prevAdjust = st.luminosityAdjust
			let alpha = clamp(self.smoothing * 4, 0.12, 1)
			st.luminosityAdjust = prevAdjust + (solved.adjust - prevAdjust) * alpha
			if Math.abs(st.luminosityAdjust) < 0.005 and Math.abs(solved.adjust) < 0.005
				st.luminosityAdjust = solved.adjust
			st.dimmingOpacity = solved.dimming
			st.measuredContrast = solved.measuredContrast
			st.detail = solved.detail
			entry.applyOnGlass solved.onGlassCss
			if clearV and solved.lowDetail and logger.devEnabled and !warnedLowDetail
				warnedLowDetail = yes
				logger.recordViolation 'clear-over-flat', "The clear variant is used over a low-detail backdrop (detail {solved.detail.toFixed(3)}). Consider the regular variant for better legibility. Element: <{entry.element.tagName.toLowerCase()}>", {element: entry.element}
		jobs.length

	def dispose
		if self.atlasFb != null
			self.atlasFb.dispose!
			self.atlasFb = null
