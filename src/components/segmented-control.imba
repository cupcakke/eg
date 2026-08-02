import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {RovingGroup} from '../a11y/keyboard-nav'
import {setSelected} from '../a11y/aria'
import {uid} from '../core/id'

tag gk-segmented-control
	prop items = []
	prop selected = 0
	prop label = 'Options'
	prop glassId = null

	def mount
		self.group = new RovingGroup self, '[data-gk-segment]', {orientation: 'horizontal', onActivate: do(el) self.activateElement(el)}
		self.group.attach!
		self.glassEntry = applyGlassEffect self, Glass.regular.interactive(no), Shape.rect(cornerRadius: 10),
			namespace: 'segmented'
			glassId: glassId
			transition: 'materialize'
		self.setAttribute 'role', 'tablist'
		updateIndicator!

	def unmount
		self.group.detach!
		if self.glassEntry
			removeGlassEffect self

	def itemsList
		if typeof items == 'string'
			items.split(',').map do(s) s.trim!
		else
			items

	def selectIndex i, focus = no
		let list = itemsList!
		if i < 0 or i >= list.length
			return
		if selected != i
			selected = i
			let ev = new CustomEvent 'change', {bubbles: yes, detail: {index: i, value: list[i]}}
			self.dispatchEvent ev
		updateIndicator!
		if focus
			let seg = self.querySelector "[data-gk-segment='{i}']"
			if seg then seg.focus!

	def activateElement el
		let idx = Number el.getAttribute('data-gk-segment')
		if Number.isFinite idx
			selectIndex idx

	def updateIndicator
		globalThis.requestAnimationFrame do
			let seg = self.querySelector "[data-gk-segment='{selected}']"
			let ind = self.querySelector '.gk-indicator'
			if seg == null or ind == null
				return
			leftSeries seg, ind

	def leftSeries seg, ind
		let hostRect = self.getBoundingClientRect!
		let r = seg.getBoundingClientRect!
		ind.style.width = "{r.width.toFixed(1)}px"
		ind.style.insetInlineStart = "{(r.left - hostRect.left - 2).toFixed(1)}px"

	def render
		let list = itemsList!
		<self role='tablist' aria-label=label>
			<div .gk-indicator aria-hidden='yes'>
			for item, i in list
				<button .gk-segment role='tab' data-gk-segment=i
					aria-selected=(i == selected ? 'true' : 'false')
					tabindex=(i == selected ? 0 : -1)
					@click=(do selectIndex(i))>
					item
