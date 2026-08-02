import {bus} from '../core/event-bus'
import {dirtyTracker} from '../core/dirty-tracker'
import {uid} from '../core/id'
import {clamp} from '../core/math'
import {Rect} from '../core/geometry'

export const scrollerRegistry = []

export def notifyScrolled el
	let r = el.getBoundingClientRect!
	dirtyTracker.markBackdrop 'root', new Rect(r.left, r.top, r.width, r.height)
	for entry in scrollerRegistry
		if entry.el == el
			entry.top = el.scrollTop
			entry.leading = el.scrollLeft
	bus.emit 'scroll:updated', {element: el, top: el.scrollTop, leading: el.scrollLeft}

export class ScrollViewModel
	def constructor el
		self.id = uid 'gks'
		self.el = el
		self.top = 0
		self.leading = 0
		self.paging = no
		self.pageSize = 0
		self.scrollEndTimer = null
		self.transformItems = []
		self.raf = null

	def attach
		self.onScroll = do self.handleScroll!
		self.el.addEventListener 'scroll', self.onScroll, {passive: yes}
		scrollerRegistry.push self
		collectTransformItems!

	def detach
		self.el.removeEventListener 'scroll', self.onScroll
		let i = scrollerRegistry.indexOf self
		if i >= 0
			scrollerRegistry.splice i, 1

	def collectTransformItems
		self.transformItems = []
		let nodes = self.el.querySelectorAll '[data-gk-scroll-transform]'
		if nodes
			for i in [0 ... nodes.length]
				self.transformItems.push nodes[i]

	def handleScroll
		self.top = self.el.scrollTop
		self.leading = self.el.scrollLeft
		let r = self.el.getBoundingClientRect!
		dirtyTracker.markBackdrop 'root', new Rect(r.left, r.top, r.width, r.height)
		bus.emit 'scroll:updated', {element: self.el, top: self.top, leading: self.leading}
		if self.raf == null
			self.raf = globalThis.requestAnimationFrame do
				self.raf = null
				self.applyTransforms!
		if self.paging
			scheduleSnap!

	def applyTransforms
		let viewH = self.el.clientHeight
		let viewTop = self.el.getBoundingClientRect!.top
		for item in self.transformItems
			let r = item.getBoundingClientRect!
			let mid = r.top - viewTop + r.height / 2
			let t = clamp (mid - viewH * 0.1) / (viewH * 0.8), 0, 1
			let scale = 0.94 + 0.06 * t
			let ty = (1 - t) * 10
			item.style.transform = "translateY({ty.toFixed(2)}px) scale({scale.toFixed(4)})"
			item.style.opacity = String(0.55 + 0.45 * t)

	def enablePaging pageSizeCss = 0
		self.paging = yes
		self.pageSize = pageSizeCss > 0 ? pageSizeCss : self.el.clientHeight

	def scheduleSnap
		if self.scrollEndTimer != null
			globalThis.clearTimeout self.scrollEndTimer
		self.scrollEndTimer = globalThis.setTimeout (do self.snapToNearestPage!), 120

	def snapToNearestPage
		unless self.paging and self.pageSize > 0
			return
		let target = Math.round(self.el.scrollTop / self.pageSize) * self.pageSize
		if Math.abs(target - self.el.scrollTop) > 2
			if typeof self.el.scrollTo == 'function'
				self.el.scrollTo {top: target, behavior: 'smooth'}

	def setScrollBehavior value
		self.el.style.scrollBehavior = value

tag gk-scroll-view
	prop axis = 'y'

	def mount
		self.scrollModel = new ScrollViewModel self
		self.scrollModel.attach!
		let role = axis == 'x' ? 'horizontal' : 'vertical'
		self.setAttribute 'data-gk-scroll-axis', axis

	def unmount
		self.scrollModel.detach!
		self.scrollModel = null

	get model
		self.scrollModel

	<self>
		<slot>
