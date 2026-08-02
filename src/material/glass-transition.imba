import {Spring} from '../core/spring'
import {scheduler} from '../core/raf-scheduler'
import {preferences} from '../a11y/preferences'
import {ANIM_CROSS_DISSOLVE_MS} from '../core/constants'
import {dirtyTracker} from '../core/dirty-tracker'

const activeTransitions = new Set
let transitionsSubscribed = no

def ensureTransitionPool
	unless transitionsSubscribed
		transitionsSubscribed = yes
		scheduler.subscribeSprings do(dt)
			let anyActive = no
			activeTransitions.forEach do(t)
				if t.step(dt)
					anyActive = yes
			if anyActive
				scheduler.springsActive!
			else
				scheduler.springsSettled!

def lerpN a, b, t
	a + (b - a) * t

export class TransitionSpec
	prop kind
	prop builder

	def constructor kind, builder = null
		self.kind = kind
		self.builder = builder

export const GlassTransition =
	matchedGeometry: new TransitionSpec 'matched'
	materialize: new TransitionSpec 'materialize'
	identity: new TransitionSpec 'identity'
	custom: do(builder)
		if typeof builder != 'function'
			throw new Error 'GlassKit: GlassTransition.custom(builder) requires a function (entry, phase) => partial state'
		new TransitionSpec 'custom', builder

export def resolveTransitionSpec value
	if value isa TransitionSpec
		return value
	if value == 'matchedGeometry' or value == 'matched'
		return GlassTransition.matchedGeometry
	if value == 'materialize'
		return GlassTransition.materialize
	if value == 'identity'
		return GlassTransition.identity
	null

export class TransitionDriver
	def constructor entry, spec, fromSnapshot = null
		self.entry = entry
		self.spec = spec
		self.from = fromSnapshot
		self.progress = new Spring(0.42, 0.92, 0)
		self.progress.snapTo 0
		self.done = no
		self.elapsed = 0
		ensureTransitionPool!
		let state = entry.state
		state.transitionActive = yes
		if preferences.reducedMotion
			if spec.kind == 'identity'
				self.done = yes
				state.transitionActive = no
			else
				self.dissolveStart = -1
				self.progress = null
		else
			self.progress.setTarget 1
			activeTransitions.add self
			scheduler.ensureRunning!

	def step dt
		if self.done
			return no
		self.elapsed += dt
		let st = self.entry.state
		if self.progress == null
			let t = Math.min 1, (self.elapsed * 1000) / ANIM_CROSS_DISSOLVE_MS
			st.transitionPhase = t
			if t >= 1
				finish!
				return no
			markDirty!
			return yes
		self.progress.advance dt
		st.transitionPhase = Math.max 0, self.progress.value
		markDirty!
		if self.progress.settled
			finish!
			return no
		yes

	def finish
		self.done = yes
		activeTransitions.delete self
		let st = self.entry.state
		st.transitionPhase = 1
		st.transitionActive = no
		markDirty!

	def markDirty
		if self.entry.rectCss != null
			dirtyTracker.markShape (self.entry.container != null ? self.entry.container.id : 'root'), self.entry.rectCss
		dirtyTracker.markAnimation yes
		scheduler.requestRender!

	get phase
		if self.progress == null
			return self.entry.state.transitionPhase
		self.entry.state.transitionPhase

	def applyToRecord record
		if self.done
			return record
		let phase = Math.max 0, Math.min 1.2, self.entry.state.transitionPhase
		if self.spec.kind == 'identity'
			return record
		if self.spec.kind == 'custom' and self.spec.builder != null
			let partial = self.spec.builder self.entry, phase
			if partial != null
				if partial.opacity != undefined then record.alphaScale *= partial.opacity
				if partial.scale != undefined then record.scale *= partial.scale
				if partial.dx != undefined then record.x += partial.dx
				if partial.dy != undefined then record.y += partial.dy
				if partial.blurBoost != undefined then record.blurRadius += partial.blurBoost
			return record
		if self.spec.kind == 'matched' and self.from != null
			let t = phase
			record.x = lerpN self.from.x, record.x, t
			record.y = lerpN self.from.y, record.y, t
			record.w = lerpN self.from.w, record.w, t
			record.h = lerpN self.from.h, record.h, t
			for i in [0 ... 4]
				record.radii[i] = lerpN self.from.radii[i], record.radii[i], t
				record.tint[i] = lerpN self.from.tint[i], record.tint[i], t
			return record
		if self.spec.kind == 'materialize'
			let t = phase
			record.scale *= 0.8 + 0.2 * t
			record.alphaScale *= Math.min 1, t * 1.4
			record.blurRadius = record.blurRadius + (1 - Math.min(1, t)) * 20
			return record
		record

export def snapshotEntry entry
	{
		x: entry.rectCss.x
		y: entry.rectCss.y
		w: entry.rectCss.w
		h: entry.rectCss.h
		radii: entry.lastRadii.slice(0)
		tint: entry.lastTint.slice(0)
	}
