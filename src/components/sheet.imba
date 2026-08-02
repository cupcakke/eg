import {applyGlassEffect, removeGlassEffect, GlassEffectHandle} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {Spring} from '../core/spring'
import {scheduler} from '../core/raf-scheduler'
import {preferences} from '../a11y/preferences'
import {clamp} from '../core/math'
import {uid} from '../core/id'
import {DETENT_MEDIUM, DETENT_LARGE} from '../core/constants'
import {FocusTrap} from '../a11y/keyboard-nav'

tag gk-sheet
	prop detents = null
	prop detent = 'medium'
	prop open = no @watch
	prop label = 'Sheet'
	prop dismissible = yes

	def mount
		self.__gkOwnsGlassSurface = yes
		self.sheetId = uid 'gksh'
		self.springY = new Spring(0.42, 1.0, 0)
		self.springY.snapTo 1
		self.dragging = null
		self.trap = null
		self.springSub = scheduler.subscribeSprings do(dt)
			if self.glassHandle == null
				return no
			self.springY.advance dt
			applyTranslate!
			if self.springY.settled
				return no
			yes
		if open
			present!

	def unmount
		self.springSub!
		dismissAll!

	def openDidSet value
		if value then present! else dismissSoft!

	def detentFractions
		let list = []
		let raw = if detents == null then ['medium', 'large'] else (typeof detents == 'string' ? detents.split(',') : detents)
		for d in raw
			if typeof d == 'string'
				d = d.trim!
			if d == 'medium'
				list.push DETENT_MEDIUM
			elif d == 'large'
				list.push DETENT_LARGE
			else
				let n = Number d
				if Number.isFinite(n) and n > 0.05 and n <= 1
					list.push n
		list.sort do(a, b) a - b
		if list.length == 0 then [DETENT_MEDIUM, DETENT_LARGE] else list

	def currentFraction
		let map = {medium: DETENT_MEDIUM, large: DETENT_LARGE}
		let f = map[detent]
		if f != undefined
			return f
		let n = Number detent
		if Number.isFinite(n) then clamp n, 0.05, 1
		else DETENT_MEDIUM

	def present
		if self.glassHandle == null
			self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.concentric(minimum: 12),
				namespace: 'sheets'
				glassId: 'sheet:' + self.sheetId
				transition: 'materialize'
		self.trap = new FocusTrap self, {onEscape: do self.requestClose!}
		self.trap.activate!
		if preferences.reducedMotion
			self.springY.snapTo 0
		else
			self.springY.setTarget -(1 - currentFraction!) - 0.0
		layout!
		scheduler.ensureRunning!

	def dismissSoft
		if self.trap
			self.trap.deactivate!
			self.trap = null
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def dismissAll
		dismissSoft!

	def requestClose
		unless dismissible
			return
		if preferences.reducedMotion
			closeSheet yes
		else
			self.springY.setTarget 1
			globalThis.setTimeout (do closeSheet(yes)), 320

	def closeSheet emitEvent = yes
		if emitEvent
			self.dispatchEvent new CustomEvent 'close', {bubbles: yes}
		dismissSoft!

	def layout
		globalThis.requestAnimationFrame do
			let vh = globalThis.window.innerHeight
			let fraction = currentFraction!
			let targetHeight = Math.round(vh * fraction)
			self.style.height = "{targetHeight}px"
			let full = fraction >= 0.92
			if full
				self.setAttribute 'data-full', '1'
			else
				self.removeAttribute 'data-full'
			applyTranslate!

	def applyTranslate
		let vh = globalThis.window.innerHeight
		let fraction = currentFraction!
		let h = self.getBoundingClientRect!.height or (vh * fraction)
		let t = self.springY.value
		let hidden = h + 24
		let shown = 0
		let y = shown + t * hidden
		self.style.transform = "translateY({y.toFixed(1)}px)"

	def onGrabberDown e
		unless dismissible
			return
		e.preventDefault!
		let startY = e.clientY
		let startT = self.springY.value
		self.dragging = {lastY: e.clientY, lastTime: Date.now!, velocity: 0}
		let move = do(ev)
			let st = self.dragging
			if st == null then return
			let vh = globalThis.window.innerHeight
			let h = self.getBoundingClientRect!.height
			let now = Date.now!
			let dt = Math.max 1, now - st.lastTime
			st.velocity = st.velocity * 0.7 + ((ev.clientY - st.lastY) / dt) * 0.3
			st.lastY = ev.clientY
			st.lastTime = now
			let delta = (ev.clientY - startY) / Math.max(1, h)
			self.springY.snapTo clamp(startT + delta, 0.0, 1.2)
			applyTranslate!
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
			let st = self.dragging
			self.dragging = null
			if st == null then return
			let v = st.velocity
			let t = self.springY.value
			if t > 0.65 or (t > 0.3 and v > 0.55)
				requestClose!
			elif t > 0.08 and v > 0.9
				requestClose!
			else
				self.springY.setTarget 0
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def render
		<self role='dialog' aria-modal='true' aria-label=label style=(open ? '' : 'display:none')>
			<div .gk-grabber role='separator' aria-label='Resize sheet' tabindex='-1' @pointerdown=onGrabberDown @click=(do if self.springY.value > 0.5 then requestClose!)>
			<slot>
