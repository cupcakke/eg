import {announce} from '../a11y/aria'
import {clamp} from '../core/math'

tag gk-stepper
	prop value = 0 @watch
	prop min = -Infinity
	prop max = Infinity
	prop step = 1
	prop label = 'Value'
	prop disabled = no

	def valueDidSet value
		self.setAttribute 'aria-valuenow', String(value)

	def changeBy delta, repeat = no
		if disabled
			return
		let next = clamp value + delta * step, (if min == -Infinity then -1e12 else min), (if max == Infinity then 1e12 else max)
		if next != value
			value = next
			let ev = new CustomEvent 'change', {bubbles: yes, detail: {value: next}}
			self.dispatchEvent ev
		unless repeat
			announce "{label}: {value}"

	def holdStart dirn, e
		e.preventDefault!
		changeBy dirn
		let count = 0
		self.holdTimer = globalThis.setInterval (do
			count += 1
			changeBy dirn * (if count > 8 then 5 else 1), yes
		), 90
		let up = do
			if self.holdTimer
				globalThis.clearInterval self.holdTimer
				self.holdTimer = null
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def onKeydown e
		if e.key == 'ArrowUp' or e.key == 'ArrowRight'
			e.preventDefault!
			changeBy 1
		elif e.key == 'ArrowDown' or e.key == 'ArrowLeft'
			e.preventDefault!
			changeBy -1

	def render
		<self role='spinbutton' tabindex=(disabled ? -1 : 0)
			aria-valuenow=value
			aria-valuemin=(min == -Infinity ? null : min)
			aria-valuemax=(max == Infinity ? null : max)
			aria-label=label
			aria-disabled=(disabled ? 'true' : null)
			@keydown=onKeydown>
			<button aria-label='Decrement' tabindex='-1' @pointerdown=(do(e) holdStart(-1, e)) disabled=disabled>
				<gk-icon name='minus' scale='small'>
			<span .gk-divider aria-hidden='yes'>
			<span .gk-count aria-hidden='yes'> value
			<span .gk-divider aria-hidden='yes'>
			<button aria-label='Increment' tabindex='-1' @pointerdown=(do(e) holdStart(1, e)) disabled=disabled>
				<gk-icon name='plus' scale='small'>
