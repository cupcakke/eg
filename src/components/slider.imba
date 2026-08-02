import {applyGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {preferences} from '../a11y/preferences'
import {clamp, roundTo} from '../core/math'

tag gk-slider
	prop value = 0
	prop valueEnd = null
	prop min = 0
	prop max = 100
	prop step = 0
	prop ticks = no
	prop range = no
	prop vertical = no
	prop label = 'Slider'
	prop showValue = no
	prop disabled = no

	def mount
		self.railEl = null
		self.thumbA = null
		self.thumbB = null
		self.dragState = null

	get clampedMin
		Number(min) or 0

	get clampedMax
		let m = Number(max)
		if isNaN(m) then 100 else m

	def quantize v
		let s = Number(step) or 0
		if s > 0
			clamp roundTo(v, s), clampedMin, clampedMax
		else
			clamp v, clampedMin, clampedMax

	def ratioFor v
		(v - clampedMin) / Math.max 1e-9, clampedMax - clampedMin

	def valueForRatio r
		quantize clampedMin + clamp(r, 0, 1) * (clampedMax - clampedMin)

	def emitChange which
		let ev = new CustomEvent 'change', {bubbles: yes, detail: {value: value, valueEnd: valueEnd, thumb: which}}
		self.dispatchEvent ev

	def valueAtEvent e
		let rect = self.railRect
		if vertical
			return valueForRatio 1 - (e.clientY - rect.top) / Math.max(1, rect.height)
		let r = (e.clientX - rect.left) / Math.max(1, rect.width)
		if preferences.dir == 'rtl'
			r = 1 - r
		valueForRatio r

	def onRailDown e
		if disabled
			return
		e.preventDefault!
		self.railRect = self.railEl.getBoundingClientRect!
		let v = valueAtEvent e
		let which = 'a'
		if range and valueEnd != null
			let dA = Math.abs(v - value)
			let dB = Math.abs(v - valueEnd)
			which = dB < dA ? 'b' : 'a'
			if valueEnd < value
				let tmp = value
				value = valueEnd
				valueEnd = tmp
		setThumbValue which, v
		activateThumbGlass which
		self.dragState = {which: which, active: yes, startV: v, velocity: 0, lastX: e.clientX, lastT: Date.now!}
		self.setAttribute 'data-active', '1'
		let move = do(ev)
			let st = self.dragState
			if st == null then return
			let now = Date.now!
			let dt = Math.max 1, now - st.lastT
			st.velocity = st.velocity * 0.75 + (Math.abs(ev.clientX - st.lastX) / dt) * 0.25
			st.lastX = ev.clientX
			st.lastT = now
			setThumbValue st.which, valueAtEvent(ev)
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
			self.removeAttribute 'data-active'
			releaseThumbGlass!
			emitChange (self.dragState != null ? self.dragState.which : 'a')
			self.dragState = null
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def setThumbValue which, v
		if which == 'b'
			let lo = value
			let hi = v
			if hi < lo
				self.dragState.which = 'a'
				valueEnd = lo
				value = quantize hi
			else
				valueEnd = quantize v
		else
			if range and valueEnd != null and v > valueEnd
				self.dragState.which = 'b'
				let old = value
				value = valueEnd
				valueEnd = quantize v
			else
				value = quantize v
		self.setAttribute 'aria-valuenow', String(value)

	def activateThumbGlass which
		let el = which == 'b' ? self.thumbB : self.thumbA
		if el == null or preferences.reducedTransparency
			return
		el.setAttribute 'data-gk-transient-knob', '1'
		self.thumbGlass = applyGlassEffect el, Glass.clear.interactive(yes), Shape.circle!

	def releaseThumbGlass
		if self.thumbGlass != null
			let handle = self.thumbGlass
			self.thumbGlass = null
			globalThis.setTimeout (do handle.dispose!), 260

	def onThumbKey which, e
		if disabled
			return
		let delta = 0
		let s = (Number(step) or 0) > 0 ? Number(step) : (clampedMax - clampedMin) / 100
		let fwd = if preferences.dir == 'rtl' then 'ArrowLeft' else 'ArrowRight'
		let bck = if preferences.dir == 'rtl' then 'ArrowRight' else 'ArrowLeft'
		if e.key == fwd or e.key == 'ArrowUp' then delta = s
		elif e.key == bck or e.key == 'ArrowDown' then delta = -s
		elif e.key == 'PageUp' then delta = s * 10
		elif e.key == 'PageDown' then delta = -s * 10
		elif e.key == 'Home' then delta = clampedMin - (which == 'b' ? valueEnd : value)
		elif e.key == 'End' then delta = clampedMax - (which == 'b' ? valueEnd : value)
		else
			return
		e.preventDefault!
		let cur = which == 'b' ? valueEnd : value
		setThumbValue which, cur + delta
		emitChange which

	def tickList
		let out = []
		if ticks and Number(ticks) > 1 and Number(ticks) <= 64
			let n = Number ticks
			for i in [0 ... n]
				out.push i / (n - 1)
		out

	def render
		let r1 = ratioFor value
		let r2 = range and valueEnd != null ? ratioFor(valueEnd) : null
		let fillFrom = r2 != null ? Math.min(r1, r2) : 0
		let fillTo = r2 != null ? Math.max(r1, r2) : r1
		let thumbPct2 = r2 != null ? (r2 * 100) : 0
		<self role=(range ? 'group' : 'slider')
			aria-label=label
			aria-valuemin=clampedMin
			aria-valuemax=clampedMax
			aria-valuenow=(range ? null : value)
			aria-orientation=(vertical ? 'vertical' : 'horizontal')
			data-vertical=(vertical ? '1' : null)
			data-active=(self.dragState != null ? '1' : null)
			tabindex=(disabled or range ? -1 : 0)
			@keydown=(do(e) onThumbKey('a', e))>
			<div .gk-rail$railEl @pointerdown=onRailDown>
				<div .gk-ticks>
					for t in tickList!
						<span .gk-tick style="inset-inline-start:{t * 100}%">
				<div .gk-fill style=(vertical ? "bottom:{fillFrom * 100}%;height:{(fillTo - fillFrom) * 100}%;inset-inline:0" : "inset-inline-start:{fillFrom * 100}%;width:{(fillTo - fillFrom) * 100}%")>
				<div .gk-thumb$thumbA role=(range ? 'slider' : null) aria-label=(range ? "{label} minimum" : label) tabindex=(range and !disabled ? 0 : -1)
					aria-valuenow=(range ? value : null) aria-valuemin=(range ? clampedMin : null) aria-valuemax=(range ? clampedMax : null) aria-orientation=(vertical ? 'vertical' : null)
					style=(vertical ? "bottom:{r1 * 100}%" : "inset-inline-start:{r1 * 100}%")
					@keydown=(do(e) onThumbKey('a', e))>
				if range and valueEnd != null
					<div .gk-thumb$thumbB role='slider' aria-label="{label} maximum" tabindex=(disabled ? -1 : 0)
						aria-valuenow=valueEnd aria-valuemin=clampedMin aria-valuemax=clampedMax aria-orientation=(vertical ? 'vertical' : null)
						style=(vertical ? "bottom:{thumbPct2}%" : "inset-inline-start:{thumbPct2}%")
						@keydown=(do(e) onThumbKey('b', e))>
			if showValue
				<span .gk-value aria-hidden='yes'> (range and valueEnd != null ? "{value}–{valueEnd}" : String(value))
