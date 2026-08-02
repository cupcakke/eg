import {announce} from '../a11y/aria'
import {clamp} from '../core/math'

tag gk-progress
	prop value = null
	prop min = 0
	prop max = 1
	prop label = 'Progress'
	prop kind = 'bar'
	prop size = 44

	def render
		let indeterminate = value == null
		let ratio = indeterminate ? 0 : clamp((value - min) / Math.max(1e-9, max - min), 0, 1)
		let r = size / 2 - 4
		let circumference = 2 * Math.PI * r
		<self role='progressbar'
			aria-label=label
			aria-valuemin=min
			aria-valuemax=max
			aria-valuenow=(indeterminate ? null : Math.round(ratio * 100) / 100)
			data-indeterminate=(indeterminate ? '1' : null)
			data-kind=kind>
			if kind == 'circular'
				<svg width=size height=size viewBox="0 0 {size} {size}" aria-hidden='true'>
					<circle .gk-trackarc cx=(size / 2) cy=(size / 2) r=r fill='none' stroke-width='4'>
					<circle .gk-bararc cx=(size / 2) cy=(size / 2) r=r fill='none' stroke-width='4'
						stroke-dasharray="{(indeterminate ? circumference * 0.35 : circumference * ratio).toFixed(2)} {circumference.toFixed(2)}"
						stroke-dashoffset='0'>
			else
				<div .gk-bar style="width:{(ratio * 100).toFixed(2)}%">
