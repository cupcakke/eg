import {applyGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {setChecked, announce} from '../a11y/aria'
import {preferences} from '../a11y/preferences'
import {clamp} from '../core/math'

tag gk-toggle
	prop checked = no @watch
	prop disabled = no
	prop label = ''
	prop kind = 'switch'
	prop indeterminate = no

	def mount
		self.knobEl = null
		self.dragState = null

	def checkedDidSet value
		setChecked self, indeterminate ? 'mixed' : value

	def release e
		let st = self.dragState
		self.dragState = null
		if st == null
			return
		if self.knobEl != null
			self.knobEl.style.transform = ''
		releaseKnobGlass!
		let moved = st.moved
		let velocity = st.velocity
		if moved
			let rect = st.trackRect
			let ratio = (st.lastX - rect.left) / Math.max 1, rect.width
			if preferences.dir == 'rtl'
				ratio = 1 - ratio
			if Math.abs(velocity) > 0.5
				let flick = velocity > 0
				if preferences.dir == 'rtl'
					flick = !flick
				toggleValue flick
			else
				toggleValue ratio > 0.5
		elif e and e.detail != 0
			toggleValue !checked

	def toggleValue value
		if disabled
			return
		if checked != value
			checked = value
			let ev = new CustomEvent 'change', {bubbles: yes, detail: {checked: value}}
			self.dispatchEvent ev

	def applyKnobGlass
		if self.knobEl == null or preferences.reducedTransparency
			return
		self.knobEl.setAttribute 'data-gk-transient-knob', '1'
		self.knobGlass = applyGlassEffect self.knobEl, Glass.clear.interactive(yes), Shape.circle!

	def releaseKnobGlass
		if self.knobGlass != null
			let handle = self.knobGlass
			self.knobGlass = null
			globalThis.setTimeout (do handle.dispose!), 240

	def onTrackPointerDown e
		if disabled or kind != 'switch'
			return
		e.preventDefault!
		let trackEl = self.querySelector '.gk-track'
		let rect = trackEl.getBoundingClientRect!
		applyKnobGlass!
		self.dragState =
			pointerId: e.pointerId
			startX: e.clientX
			lastX: e.clientX
			lastT: Date.now!
			velocity: 0
			moved: no
			trackRect: rect
		let move = do(ev)
			let st = self.dragState
			if st == null then return
			let now = Date.now!
			let dt = Math.max 1, now - st.lastT
			st.velocity = st.velocity * 0.7 + ((ev.clientX - st.lastX) / dt) * 0.3
			st.lastX = ev.clientX
			st.lastT = now
			if Math.abs(ev.clientX - st.startX) > 3
				st.moved = yes
				positionKnob ev.clientX
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
			release ev
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def positionKnob x
		let st = self.dragState
		if st == null or self.knobEl == null
			return
		let rect = st.trackRect
		let ratio = clamp (x - rect.left) / Math.max(1, rect.width), 0, 1
		let knobW = rect.height - 4
		let travel = rect.width - knobW - 4
		let px = 2 + ratio * travel
		if preferences.dir == 'rtl'
			self.knobEl.style.transform = "translateX({-Math.round(px)}px)"
		else
			self.knobEl.style.transform = "translateX({Math.round(px)}px)"

	def onClick e
		if self.dragState != null
			return
		if kind != 'switch'
			toggleValue !checked

	def onKeydown e
		if e.key == 'Enter' or e.key == ' '
			e.preventDefault!
			toggleValue !checked

	def render
		let isSwitch = kind == 'switch'
		let role = isSwitch ? 'switch' : (kind == 'checkbox' ? 'checkbox' : 'button')
		<self role=role
			tabindex=(disabled ? -1 : 0)
			aria-checked=(indeterminate ? 'mixed' : (checked ? 'true' : 'false'))
			aria-disabled=(disabled ? 'true' : null)
			aria-pressed=(kind == 'button' ? (checked ? 'true' : 'false') : null)
			data-checked=(checked ? '1' : null)
			data-kind=kind
			@keydown=onKeydown
			@click=onClick>
			if isSwitch
				<span .gk-track @pointerdown=onTrackPointerDown>
					<span .gk-knob$knobEl>
				<span .gk-label> label
				<slot>
			elif kind == 'checkbox'
				<span .gk-track>
					<svg .gk-check viewBox='0 0 24 24' width='14' height='14' style="position:absolute;inset:4px;">
						<path d='M5 12.8l4.5 4.5L19 7.8' fill='none' stroke='currentColor' stroke-width='2.4' stroke-linecap='round'>
				if indeterminate
					<svg viewBox='0 0 24 24' width='14' height='14' style="position:absolute;inset:4px;">
						<path d='M6 12h12' stroke='currentColor' stroke-width='2.4' stroke-linecap='round'>
				<span .gk-label> label
				<slot>
			else
				if label != ''
					<span .gk-label> label
				<slot>
