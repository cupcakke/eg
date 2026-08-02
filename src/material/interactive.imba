import {Spring} from '../core/spring'
import {scheduler} from '../core/raf-scheduler'
import {preferences} from '../a11y/preferences'
import {dirtyTracker} from '../core/dirty-tracker'
import {Rect} from '../core/geometry'
import {LARGE_SHAPE_AREA, PRESS_SCALE_SMALL, PRESS_SCALE_LARGE} from '../core/constants'
import {clamp} from '../core/math'

const activeControllers = new Set
let poolSubscribed = no

export def ensureSpringPool
	unless poolSubscribed
		poolSubscribed = yes
		scheduler.subscribeSprings do(dt)
			let anyActive = no
			activeControllers.forEach do(ctrl)
				if ctrl.stepSprings(dt)
					anyActive = yes
			if anyActive
				scheduler.springsActive!
			else
				scheduler.springsSettled!

export class InteractiveController
	def constructor entry
		self.entry = entry
		self.pressSpring = new Spring(0.32, 0.92, 0)
		self.hoverSpring = new Spring(0.4, 1.0, 0)
		self.pointerXSpring = new Spring(0.28, 0.9, 0)
		self.pointerYSpring = new Spring(0.28, 0.9, 0)
		self.jellySpring = new Spring(0.45, 0.55, 0)
		self.pressSpring.snapTo 0
		self.hoverSpring.snapTo 0
		self.pointerXSpring.snapTo 0.5
		self.pointerYSpring.snapTo 0.5
		self.jellySpring.snapTo 0
		self.pressed = no
		self.hovered = no
		self.bound = no
		self.dragVelocity = 0
		self.lastPointer = null
		self.active = no

	def attach
		if self.bound
			return
		self.bound = yes
		ensureSpringPool!
		let el = self.entry.element
		self.onDown = do(e) self.handleDown(e)
		self.onUp = do(e) self.handleUp(e)
		self.onMove = do(e) self.handleMove(e)
		self.onEnter = do(e) self.handleEnter(e)
		self.onLeave = do(e) self.handleLeave(e)
		self.onCancel = do(e) self.handleCancel(e)
		el.addEventListener 'pointerdown', self.onDown
		el.addEventListener 'pointerup', self.onUp
		el.addEventListener 'pointermove', self.onMove
		el.addEventListener 'pointerenter', self.onEnter
		el.addEventListener 'pointerleave', self.onLeave
		el.addEventListener 'pointercancel', self.onCancel

	def detach
		unless self.bound
			return
		self.bound = no
		activeControllers.delete self
		let el = self.entry.element
		el.removeEventListener 'pointerdown', self.onDown
		el.removeEventListener 'pointerup', self.onUp
		el.removeEventListener 'pointermove', self.onMove
		el.removeEventListener 'pointerenter', self.onEnter
		el.removeEventListener 'pointerleave', self.onLeave
		el.removeEventListener 'pointercancel', self.onCancel

	def activate
		activeControllers.add self
		self.active = yes
		scheduler.ensureRunning!

	def deactivate
		activeControllers.delete self
		self.active = no

	get reduceMotion
		preferences.reducedMotion

	def handleDown e
		self.pressed = yes
		updatePointer e
		if reduceMotion
			self.pressSpring.snapTo 1
			markDirty!
			return
		self.pressSpring.setTarget 1
		self.jellySpring.setTarget 0
		activate!

	def handleUp e
		unless self.pressed
			return
		self.pressed = no
		if reduceMotion
			self.pressSpring.snapTo 0
			markDirty!
			return
		self.pressSpring.setTarget 0
		self.jellySpring.snapTo 0
		self.jellySpring.setTarget 1, 2.2
		activate!

	def handleCancel
		self.pressed = no
		self.pressSpring.setTarget 0

	def handleMove e
		updatePointer e

	def handleEnter e
		self.hovered = yes
		updatePointer e
		if reduceMotion
			self.hoverSpring.snapTo 1
		else
			self.hoverSpring.setTarget 1
		activate!
		markDirty!

	def handleLeave
		self.hovered = no
		if reduceMotion
			self.hoverSpring.snapTo 0
		else
			self.hoverSpring.setTarget 0
		self.pressed = no
		self.pressSpring.setTarget 0
		activate!

	def updatePointer e
		let rect = self.entry.rectCss
		if rect == null or rect.w <= 0 or rect.h <= 0
			return
		if self.lastPointer != null
			let dx = e.clientX - self.lastPointer[0]
			let dy = e.clientY - self.lastPointer[1]
			self.dragVelocity = self.dragVelocity * 0.7 + Math.sqrt(dx * dx + dy * dy) * 0.3
		self.lastPointer = [e.clientX, e.clientY]
		let x = clamp (e.clientX - rect.x) / rect.w, 0, 1
		let y = clamp (e.clientY - rect.y) / rect.h, 0, 1
		if reduceMotion
			self.pointerXSpring.snapTo x
			self.pointerYSpring.snapTo y
		else
			self.pointerXSpring.setTarget x
			self.pointerYSpring.setTarget y
		activate!
		markDirty!

	def stepSprings dt
		let alive = no
		for spring in [self.pressSpring, self.hoverSpring, self.pointerXSpring, self.pointerYSpring, self.jellySpring]
			spring.advance dt
			unless spring.settled
				alive = yes
		if alive or self.needsPush
			pushToEntry!
			self.needsPush = no
			markDirty!
		else
			let st = self.entry.state
			if st.press != 0 or st.hover != (if self.hovered then 1 else 0)
				pushToEntry!
		if alive == no and self.active
			deactivate!
		alive

	def pushToEntry
		let st = self.entry.state
		st.press = clamp(self.pressSpring.value, 0, 1)
		st.hover = clamp(self.hoverSpring.value, 0, 1)
		st.pointerX = self.pointerXSpring.value
		st.pointerY = self.pointerYSpring.value
		st.jelly = Math.max 0, self.jellySpring.value

	def pressScale rectCss
		let area = rectCss.w * rectCss.h
		let base = if area >= LARGE_SHAPE_AREA then PRESS_SCALE_LARGE else PRESS_SCALE_SMALL
		1 + (base - 1) * self.entry.state.press

	def jellyOffset time = 0
		let j = self.entry.state.jelly
		if j <= 0.001
			return [1, 1, 0]
		let wobble = Math.sin(j * Math.PI * 4.0) * Math.exp(-j * 2.6) * 0.03
		[1 + wobble, 1 - wobble, 0]

	def markDirty
		let cont = self.entry.container
		if cont != null and self.entry.rectGL != null
			dirtyTracker.markShape cont.id, self.entry.rectCss
		dirtyTracker.markAnimation yes
		scheduler.requestRender!
