import {FIXED_TIMESTEP, MAX_FRAME_STEPS, QUALITY_TIERS, TIER_DEGRADE_MS, TIER_RESTORE_MS} from './constants'
import {clamp, lerp} from './math'
import {requestFrame, cancelFrame, isBrowser} from './env'

const QUALITY_TABLE = [
	{tier: 0, dprScale: 1.0, blurScale: 1.0, chromatic: yes, rim: yes, specular: yes, shadow: yes, extraPasses: yes}
	{tier: 1, dprScale: 1.0, blurScale: 0.75, chromatic: yes, rim: yes, specular: yes, shadow: yes, extraPasses: yes}
	{tier: 2, dprScale: 0.85, blurScale: 0.5, chromatic: no, rim: yes, specular: yes, shadow: yes, extraPasses: no}
	{tier: 3, dprScale: 0.66, blurScale: 0.4, chromatic: no, rim: no, specular: no, shadow: no, extraPasses: no}
]

export class RafScheduler
	prop budgetMs

	def constructor
		self.springFns = []
		self.updateFns = []
		self.renderFn = null
		self.dirtyProbe = null
		self.running = no
		self.handle = null
		self.lastTime = 0
		self.accumulator = 0
		self.frame = 0
		self.budgetMs = 16.7
		self.frameAvg = 16.7
		self.tier = 0
		self.tierLock = null
		self.overMs = 0
		self.underMs = 0
		self.qualityListeners = []
		self.springActive = no
		self.renderRequested = no
		self.time = 0
		self.tick = do(t) self.frameTick(t)
		self.onVisibility = do
			if isBrowser and globalThis.document.hidden
				self.pause!
			elif isBrowser
				self.resume!
		if isBrowser
			globalThis.document.addEventListener 'visibilitychange', self.onVisibility

	get quality
		if self.tierLock != null
			QUALITY_TABLE[self.tierLock]
		else
			QUALITY_TABLE[self.tier]

	def setQuality tierOrNull
		if tierOrNull == null
			self.tierLock = null
			return
		let t = clamp Math.floor(tierOrNull), 0, QUALITY_TIERS - 1
		self.tierLock = t
		notifyQuality!

	def onQualityChange fn
		self.qualityListeners.push fn
		do
			let i = self.qualityListeners.indexOf(fn)
			if i >= 0
				self.qualityListeners.splice i, 1

	def notifyQuality
		let q = quality
		for fn in self.qualityListeners
			fn q

	def subscribeSprings fn
		self.springFns.push fn
		do
			let i = self.springFns.indexOf(fn)
			if i >= 0
				self.springFns.splice i, 1

	def subscribe fn
		self.updateFns.push fn
		do
			let i = self.updateFns.indexOf(fn)
			if i >= 0
				self.updateFns.splice i, 1

	def onRender fn, dirtyProbe = null
		self.renderFn = fn
		self.dirtyProbe = dirtyProbe
		start!

	def requestRender
		self.renderRequested = yes

	def springsSettled
		self.springActive = no

	def springsActive
		self.springActive = yes

	def start
		unless self.running
			self.running = yes
			self.lastTime = 0
			self.handle = requestFrame self.tick
		self

	def stop
		self.running = no
		if self.handle != null
			cancelFrame self.handle
			self.handle = null
		self

	def pause
		stop!

	def resume
		unless isBrowser and globalThis.document.hidden
			start!

	def step dtMs
		frameTick (self.time + dtMs), yes

	get needsFrame
		self.renderRequested or self.springActive or (self.dirtyProbe != null and self.dirtyProbe())

	def frameTick timestamp, manual = no
		if self.lastTime == 0
			self.lastTime = timestamp
		let dtMs = clamp timestamp - self.lastTime, 0, 100
		self.lastTime = timestamp
		self.time = timestamp
		let dt = dtMs / 1000
		self.accumulator += dt
		let steps = 0
		while self.accumulator >= FIXED_TIMESTEP and steps < MAX_FRAME_STEPS
			for fn in self.springFns
				fn FIXED_TIMESTEP
			self.accumulator -= FIXED_TIMESTEP
			steps += 1
		if steps == MAX_FRAME_STEPS
			self.accumulator = 0
		for fn in self.updateFns
			fn dt, timestamp
		let shouldRender = needsFrame
		if shouldRender and self.renderFn
			self.renderFn dt
			self.renderRequested = no
		trackBudget dtMs
		self.frame += 1
		if self.running and !manual
			if self.springFns.length > 0 or self.updateFns.length > 0 or shouldRender or self.springActive
				self.handle = requestFrame self.tick
			else
				self.running = no

	def ensureRunning
		unless self.running or (self.springFns.length == 0 and self.updateFns.length == 0 and self.renderFn == null)
			start!

	def trackBudget dtMs
		if dtMs > 0.01
			self.frameAvg = lerp self.frameAvg, Math.min(dtMs, 100), 0.08
		if self.tierLock != null
			return
		let budget = self.budgetMs + 0.5
		if self.frameAvg > budget
			self.overMs += dtMs
			self.underMs = 0
		else
			self.underMs += dtMs
			self.overMs = 0
		if self.overMs > TIER_DEGRADE_MS and self.tier < QUALITY_TIERS - 1
			self.tier += 1
			self.overMs = 0
			notifyQuality!
		elif self.underMs > TIER_RESTORE_MS and self.tier > 0
			self.tier -= 1
			self.underMs = 0
			notifyQuality!

export const scheduler = new RafScheduler
