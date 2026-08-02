import {clamp, saturate} from './math'

const NEWTON_ITERATIONS = 8
const NEWTON_MIN_SLOPE = 0.001
const SUBDIVISION_PRECISION = 1e-7
const SUBDIVISION_MAX_ITERATIONS = 32
const SPLINE_TABLE_SIZE = 11

export class CubicBezier
	prop x1
	prop y1
	prop x2
	prop y2

	def constructor x1 = 0.25, y1 = 0.1, x2 = 0.25, y2 = 1
		self.x1 = clamp x1, 0, 1
		self.y1 = y1
		self.x2 = clamp x2, 0, 1
		self.y2 = y2
		self.samples = new Float64Array SPLINE_TABLE_SIZE
		if self.x1 != self.y1 or self.x2 != self.y2
			for i in [0 ... SPLINE_TABLE_SIZE]
				self.samples[i] = calcSample(self.x1, self.x2, i / (SPLINE_TABLE_SIZE - 1))

	def calcA a1, a2
		1 - 3 * a2 + 3 * a1

	def calcB a1, a2
		3 * a2 - 6 * a1

	def calcC a1
		3 * a1

	def calcSample a1, a2, t
		((calcA(a1, a2) * t + calcB(a1, a2)) * t + calcC(a1)) * t

	def calcDerivative a1, a2, t
		3 * calcA(a1, a2) * t * t + 2 * calcB(a1, a2) * t + calcC(a1)

	def solveX x
		if self.x1 == self.y1 and self.x2 == self.y2
			return x
		let t = x
		for i in [0 ... NEWTON_ITERATIONS]
			let err = calcSample(self.x1, self.x2, t) - x
			if Math.abs(err) < SUBDIVISION_PRECISION
				return t
			let slope = calcDerivative(self.x1, self.x2, t)
			if Math.abs(slope) < NEWTON_MIN_SLOPE
				break
			t -= err / slope
		if t <= 0
			return 0
		if t >= 1
			return 1
		let lo = 0
		let hi = 1
		let mid = t
		for i in [0 ... SUBDIVISION_MAX_ITERATIONS]
			mid = (lo + hi) / 2
			let v = calcSample(self.x1, self.x2, mid)
			if Math.abs(v - x) < SUBDIVISION_PRECISION
				return mid
			if v < x
				lo = mid
			else
				hi = mid
		mid

	def at t
		if t <= 0
			0
		elif t >= 1
			1
		else
			calcSample(self.y1, self.y2, solveX(t))

export const easeLinear = new CubicBezier(0, 0, 1, 1)
export const easeIn = new CubicBezier(0.42, 0, 1, 1)
export const easeOut = new CubicBezier(0.25, 0.1, 0.25, 1)
export const easeInOut = new CubicBezier(0.42, 0, 0.58, 1)
export const easeStandard = easeInOut
export const easeEmphasized = new CubicBezier(0.2, 0, 0, 1)
export const easeDecelerate = new CubicBezier(0.05, 0.7, 0.1, 1)
export const easeAccelerate = new CubicBezier(0.3, 0, 1, 1)
export const easeOvershoot = new CubicBezier(0.175, 0.885, 0.32, 1.275)

export def steps count, position = 'end'
	let n = Math.max 1, Math.floor(count)
	let jumpStart = position == 'start' or position == 'jump-start'
	let jumpNone = position == 'jump-none'
	let jumpBoth = position == 'jump-both'
	do(t)
		let x = saturate t
		if jumpBoth
			Math.floor(x * (n + 1)) / n
		elif jumpNone
			if x <= 0
				0
			elif x >= 1
				1
			else
				Math.floor(x * n) / (n - 1)
		elif jumpStart
			Math.min(Math.floor(x * n) + 1, n) / n
		else
			Math.floor(x * n) / n

export class PhaseAnimator
	prop phases
	prop phaseDuration
	prop easing
	prop loop

	def constructor phases = [], options = {}
		self.phases = phases
		self.phaseDuration = options.phaseDuration or 0.6
		self.easing = options.easing or easeInOut
		self.loop = options.loop !== no
		self.index = 0
		self.time = 0
		self.playing = no

	def play
		self.playing = yes
		self

	def stop
		self.playing = no
		self

	def reset
		self.index = 0
		self.time = 0
		self

	get currentPhase
		self.phases[self.index % self.phases.length]

	get progress
		if self.phaseDuration <= 0
			1
		else
			saturate(self.time / self.phaseDuration)

	def update dt, apply = null
		unless self.playing
			return no
		self.time += dt
		while self.time >= self.phaseDuration and self.phaseDuration > 0
			self.time -= self.phaseDuration
			self.index += 1
			if self.index >= self.phases.length
				if self.loop
					self.index = 0
				else
					self.index = self.phases.length - 1
					self.playing = no
					break
		if apply
			apply self.phases[self.index % self.phases.length], self.easing.at(progress), self.index
		self.playing

export class KeyframeTrack
	prop property
	prop frames

	def constructor property, frames
		self.property = property
		self.frames = frames.slice(0)
		self.frames.sort do(a, b) a.offset - b.offset
		for f in self.frames
			if f.easing == undefined
				f.easing = easeInOut

	def valueAt time
		let fs = self.frames
		if fs.length == 0
			return undefined
		if time <= fs[0].offset
			return fs[0].value
		if time >= fs[fs.length - 1].offset
			return fs[fs.length - 1].value
		for i in [0 ... fs.length - 1]
			let a = fs[i]
			let b = fs[i + 1]
			if time >= a.offset and time <= b.offset
				let span = Math.max 1e-9, b.offset - a.offset
				let t = b.easing.at((time - a.offset) / span)
				if typeof a.value == 'number'
					return a.value + (b.value - a.value) * t
				elif Array.isArray(a.value)
					let out = new Array a.value.length
					for k in [0 ... a.value.length]
						out[k] = a.value[k] + (b.value[k] - a.value[k]) * t
					return out
				else
					return if t < 1 then a.value else b.value
		fs[fs.length - 1].value

export class KeyframeAnimator
	prop tracks
	prop duration
	prop loop

	def constructor durationMs, trackDefs = {}, options = {}
		self.duration = Math.max 1, durationMs
		self.loop = options.loop or no
		self.tracks = []
		for own key, frames of trackDefs
			self.tracks.push new KeyframeTrack(key, frames)
		self.time = 0
		self.playing = no
		self.flipped = no

	def play
		self.playing = yes
		self.time = 0
		self

	def stop
		self.playing = no
		self

	get normalizedTime
		saturate(self.time / self.duration)

	def valuesAt time
		let out = {}
		for track in self.tracks
			out[track.property] = track.valueAt(time)
		out

	def update dt, apply = null
		unless self.playing
			return no
		self.time += dt * 1000
		if self.time >= self.duration
			if self.loop
				self.time = self.time % self.duration
			else
				self.time = self.duration
				self.playing = no
		if apply
			apply valuesAt(self.time)
		self.playing
