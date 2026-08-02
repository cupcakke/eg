import {Rect} from '../core/geometry'
import {uid, namespacedId} from '../core/id'
import {bus} from '../core/event-bus'
import {logger} from '../core/logger'
import {settings} from '../core/settings'
import {preferences} from '../a11y/preferences'
import {dirtyTracker} from '../core/dirty-tracker'
import {isBrowser} from '../core/env'
import {InteractiveController} from './interactive'
import {resolveGlass} from './glass'
import {resolveTransitionSpec, GlassTransition, TransitionDriver, snapshotEntry} from './glass-transition'
import {UnionRegistry} from './glass-union'
import {parseColor, toHex} from '../core/color'
import {WARN_MAX_LOOSE_SHAPES, WARN_MAX_CONTAINERS, WARN_MIN_SURFACE_GAP} from '../core/constants'

const REMOVAL_WINDOW_MS = 450

def liveRegistry
	registry

export class RegistryEntry
	prop id
	prop element
	prop glass
	prop shape
	prop namespace
	prop glassId
	prop unionId

	def constructor el, glass, shape, opts = {}
		self.id = uid 'gke'
		self.element = el
		self.glass = glass
		self.shape = shape
		self.namespace = opts.namespace or 'default'
		self.glassId = opts.glassId or null
		self.unionId = opts.unionId or null
		self.transitionSpec = resolveTransitionSpec(opts.transition)
		self.container = null
		self.interactive = null
		self.seq = liveRegistry!.nextSeq!
		self.rectCss = new Rect
		self.rectGL = new Rect
		self.lastRadii = [0, 0, 0, 0]
		self.lastTint = [0, 0, 0, 0]
		self.focused = no
		self.offScreen = no
		self.state =
			press: 0
			hover: 0
			pointerX: 0.5
			pointerY: 0.5
			jelly: 0
			luminosityAdjust: 0
			dimmingOpacity: 0
			measuredContrast: 0
			detail: 1
			noProbe: no
			transitionActive: no
			transitionPhase: 1
		self.transitionDriver = null
		self.fallbackInteractiveBound = no
		self.onGlassCss = null
		self.cssDirty = yes

	get namespacedId
		if self.glassId == null
			null
		else
			namespacedId self.namespace, self.glassId

	get glassVariantId
		self.glass.resolve!.variantId

	def ensureInteractive
		if self.interactive == null
			self.interactive = new InteractiveController self
			self.interactive.attach!
		self.interactive

	def resolvedGlass
		self.resolvedParams or (self.resolvedParams = self.glass.resolve!)

	def applyOnGlass cssColor
		if self.onGlassCss != cssColor
			self.onGlassCss = cssColor
			let el = self.element
			if el and el.style and el.style.setProperty
				el.style.setProperty '--gk-on-glass', cssColor
				bus.emit 'on-glass:changed', self

	get cssDescriptor
		let params = resolvedGlass!
		let radii = self.shape.resolveRadii self.rectCss, {ltr: preferences.dir != 'rtl'}
		let radiiCss = "{radii[0].toFixed(2)}px {radii[1].toFixed(2)}px {radii[2].toFixed(2)}px {radii[3].toFixed(2)}px"
		if self.shape.type == 0
			radiiCss = '999px'
		let tint = self.glass.tintValue
		{
			variant: self.glass.variantName
			blur: "{(params.blurRadius).toFixed(1)}px"
			tintCss: tint.toCss!
			tintStrength: String(tint.strength)
			radiiCss: radiiCss
			dimming: (self.state.dimmingOpacity > 0 ? "rgba(0,0,0,{self.state.dimmingOpacity})" : 'rgba(0,0,0,0)')
			shadowCss: "0 {8}px {Math.max(4, params.blurRadius * 0.7).toFixed(1)}px rgba(10,10,25,0.22)"
			borderAlpha: (preferences.increaseContrast ? '0.55' : '0.28')
			interactive: params.interactive > 0
		}

	def dispose
		if self.interactive != null
			self.interactive.detach!
		if self.transitionDriver != null
			self.transitionDriver.finish!
			self.transitionDriver = null

export class GlassRegistry
	def constructor
		self.entries = []
		self.byElement = new Map
		self.containers = []
		self.containersByElement = new Map
		self.rootContainer = null
		self.unions = new UnionRegistry
		self.recentRemovals = []
		self.seqCounter = 0
		self.ro = null
		self.io = null
		self.mo = null
		self.attached = no
		self.diagnoseScheduled = no
		self.focusedEntry = null
		self.structureVersion = 0
		self.tempRect = new Rect

	def nextSeq
		self.seqCounter += 1
		self.seqCounter

	def attach doc = null
		if self.attached or !isBrowser
			return
		self.attached = yes
		let reg = liveRegistry!
		let d = doc or globalThis.document
		self.ro = new globalThis.ResizeObserver do(list)
			for item in list
				let el = item.target
				let entry = reg.byElement.get el
				if entry
					reg.measureEntry entry
					dirtyTracker.markShape (entry.container ? entry.container.id : 'root'), entry.rectCss
				else
					let cont = reg.containersByElement.get el
					if cont
						cont.measureAll!
			schedulerRequest!
		self.io = new globalThis.IntersectionObserver do(list)
			for item in list
				let entry = reg.byElement.get item.target
				if entry
					entry.offScreen = item.isIntersecting == no
		self.mo = new globalThis.MutationObserver do(mutations)
			for m in mutations
				if m.type == 'attributes'
					reg.handleAttributeChange m.target, m.attributeName
		self.mo.observe d.documentElement,
			attributes: yes
			attributeFilter: ['glass-id', 'glass-namespace', 'glass-union', 'glass-transition', 'class', 'style']
			subtree: yes
		d.addEventListener 'focusin', do(e)
			reg.handleFocusChange e.target
		d.addEventListener 'focusout', do(e)
			reg.handleFocusChange null
		let w = globalThis.window
		self.measureScheduled = no
		let scrollHandler = do
			if reg.measureScheduled == no
				reg.measureScheduled = yes
				globalThis.requestAnimationFrame do
					reg.measureScheduled = no
					for entry in reg.entries
						reg.measureEntry entry
			dirtyTracker.markAll!
		w.addEventListener 'scroll', scrollHandler, {capture: yes, passive: yes}

	def schedulerRequest
		dirtyTracker.markAll!

	def register el, glass, shape, opts = {}
		let existing = self.byElement.get el
		if existing
			existing.glass = glass
			existing.shape = shape
			existing.cssDirty = yes
			return existing
		let entry = new RegistryEntry el, glass, shape, opts
		self.entries.push entry
		self.byElement.set el, entry
		if opts.interactive or (glass.interactiveFlag == yes)
			entry.ensureInteractive!
		assignToContainer entry
		if self.ro
			self.ro.observe el
		if self.io
			self.io.observe el
		measureEntry entry
		pairTransition entry
		structureChanged!
		if entry.unionId
			self.unions.groupFor(entry.unionId, entry.namespace).addMember entry
		entry

	def updateGlass entry, glassValue
		entry.glass = resolveGlass glassValue
		entry.resolvedParams = null
		entry.cssDirty = yes
		markEntry entry

	def updateShape entry, shapeDescriptor
		entry.shape = shapeDescriptor
		entry.cssDirty = yes
		markEntry entry

	def unregister entry
		if typeof entry == 'object' and entry.element == undefined and self.byElement.has(entry)
			entry = self.byElement.get entry
		let i = self.entries.indexOf entry
		if i < 0
			return no
		if entry.namespacedId != null and entry.rectCss != null
			self.recentRemovals.push
				id: entry.namespacedId
				snapshot: snapshotEntry(entry)
				time: Date.now!
				transition: entry.transitionSpec
			trimRemovals!
		self.entries.splice i, 1
		self.byElement.delete entry.element
		if entry.container
			entry.container.removeEntry entry
			entry.container = null
		if entry.unionId
			self.unions.groupFor(entry.unionId, entry.namespace).removeMember entry
			self.unions.removeEmpty!
		if self.ro
			self.ro.unobserve entry.element
		if self.io
			self.io.unobserve entry.element
		entry.dispose!
		structureChanged!
		yes

	def pairTransition entry
		let spec = entry.transitionSpec
		if spec == null or spec.kind == 'identity'
			return
		if entry.namespacedId != null
			let found = null
			let foundIdx = -1
			let total = self.recentRemovals.length
			for i in [0 ... total]
				let r = self.recentRemovals[i]
				if r.id == entry.namespacedId and Date.now! - r.time < REMOVAL_WINDOW_MS
					found = r
					foundIdx = i
			if found != null
				self.recentRemovals.splice foundIdx, 1
			if found != null and spec.kind == 'matched'
				entry.transitionDriver = new TransitionDriver entry, spec, found.snapshot
				return
		entry.transitionDriver = new TransitionDriver entry, spec, null

	def trimRemovals
		let cutoff = Date.now! - REMOVAL_WINDOW_MS
		while self.recentRemovals.length > 0 and self.recentRemovals[0].time < cutoff
			self.recentRemovals.shift!

	def assignToContainer entry
		let el = entry.element
		let node = el.parentNode
		while node != null
			let cont = self.containersByElement.get node
			if cont
				cont.addEntry entry
				entry.container = cont
				return
			node = node.parentNode
		let root = ensureRootContainer!
		root.addEntry entry
		entry.container = root

	def ensureRootContainer
		if self.rootContainer == null
			self.rootContainer = newRootContainer!
			self.containers.push self.rootContainer
		self.rootContainer

	def newRootContainer
		let GlassContainerModule = self.containerFactory
		GlassContainerModule.root!

	def registerContainer el, spacing = 0
		let cont = self.containersByElement.get el
		if cont
			cont.spacing = spacing
			return cont
		cont = self.containerFactory.forElement el, spacing
		self.containers.push cont
		self.containers.sort do(a, b) a.seq - b.seq
		self.containersByElement.set el, cont
		if self.containers.length > settings.thresholds.maxContainers
			logger.recordViolation 'too-many-containers', "More than {settings.thresholds.maxContainers} glass containers exist ({self.containers.length}). Nest shapes inside a single gk-glass-container where possible.", {count: self.containers.length}
		structureChanged!
		cont

	def unregisterContainer el
		let cont = self.containersByElement.get el
		unless cont
			return no
		self.containersByElement.delete el
		let i = self.containers.indexOf cont
		if i >= 0
			self.containers.splice i, 1
		for entry in cont.entries.slice(0)
			entry.container = null
			assignToContainer entry
		structureChanged!
		yes

	def measureEntry entry
		let el = entry.element
		unless el.getBoundingClientRect
			return
		let r = el.getBoundingClientRect!
		entry.rectCss.set r.left, r.top, r.width, r.height
		entry.cssDirty = yes

	def handleAttributeChange el, attrName
		let entry = self.byElement.get el
		if entry == null
			return
		if attrName == 'glass-id'
			entry.glassId = el.getAttribute 'glass-id'
		elif attrName == 'glass-namespace'
			entry.namespace = el.getAttribute('glass-namespace') or 'default'
		elif attrName == 'class' or attrName == 'style'
			detectCustomBackground entry
		markEntry entry

	def handleFocusChange target
		if self.focusedEntry != null
			self.focusedEntry.focused = no
		self.focusedEntry = null
		let node = target
		while node != null
			let entry = self.byElement.get node
			if entry
				entry.focused = yes
				self.focusedEntry = entry
				break
			node = node.parentNode

	def markEntry entry
		entry.cssDirty = yes
		if entry.container
			entry.container.markDirty!
		dirtyTracker.markShape (entry.container ? entry.container.id : 'root'), entry.rectCss

	def structureChanged
		self.structureVersion += 1
		dirtyTracker.markAll!
		scheduleDiagnose!
		bus.emit 'registry:changed', self.structureVersion

	def scheduleDiagnose
		if !settings.devDiagnostics or self.diagnoseScheduled
			return
		self.diagnoseScheduled = yes
		globalThis.setTimeout do
			self.diagnoseScheduled = no
			self.diagnose!

	def diagnose
		unless settings.devDiagnostics
			return
		let loose = 0
		for entry in self.entries
			elLayerCheck entry
			if entry.container == self.rootContainer and !entry.state.noProbe
				loose += 1
			detectCustomBackground entry
		if loose > settings.thresholds.maxLooseShapes
			logger.recordViolation 'too-many-loose', "{loose} independent glass shapes are visible without a container (limit {settings.thresholds.maxLooseShapes}). Consider gk-glass-container.", {count: loose}
		let n = Math.min self.entries.length, 40
		for i in [0 ... n]
			let a = self.entries[i]
			if a.container == null or a.offScreen
				continue
			for j in [i + 1 ... n]
				let b = self.entries[j]
				if a.container != b.container or b.offScreen
					continue
				let d = a.rectCss.surfaceDistanceTo b.rectCss
				if a.unionId == null and b.unionId == null and a.container.spacing <= 0 and d < settings.thresholds.minSurfaceGap and d >= 0
					logger.warnOnce "crowd:{a.id}:{b.id}", "Glass shapes are crowding (surface gap {d.toFixed(0)}px < {settings.thresholds.minSurfaceGap}px) outside a blending group. Increase spacing or move them into a gk-glass-container."

	def elLayerCheck entry
		let el = entry.element
		let node = el.parentNode
		let functional = no
		let content = no
		while node != null
			if node.hasAttribute and node.hasAttribute('content-layer')
				content = yes
				break
			if node.hasAttribute and node.hasAttribute('functional-layer')
				functional = yes
				break
			node = node.parentNode
		if content and !functional
			let transient = el.getAttribute('data-gk-transient-knob') == '1'
			unless transient
				logger.warnOnce "layer:{entry.id}", "A glass shape is registered inside the content layer. Glass belongs to the functional layer (add functional-layer to the ancestor, or move the control out of content-layer)."

	def detectCustomBackground entry
		unless settings.devDiagnostics
			return
		let el = entry.element
		if el.__gkOwnsGlassSurface != yes
			return
		if typeof globalThis.getComputedStyle == 'undefined'
			return
		let style = globalThis.getComputedStyle el
		let bg = style.backgroundColor
		let bgImg = style.backgroundImage
		if (bg != 'rgba(0, 0, 0, 0)' and bg != 'transparent') or (bgImg != 'none')
			logger.warnOnce "custombg:{entry.id}", "A custom background was set on <{el.tagName.toLowerCase()}> which supplies its own glass surface. Remove the 'background' / 'background-color' property — the material provides the surface."

	def containerList
		self.containers

	get entryCount
		self.entries.length

	get globalMaxBlurRadius
		let max = 0
		for entry in self.entries
			let p = entry.resolvedGlass!
			if p.blurRadius > max
				max = p.blurRadius
		if self.containers.length > 0
			for c in self.containers
				for e in c.entries
					let pm = e.resolvedGlass!
					if pm.blurRadius > max
						max = pm.blurRadius
		max

	def entryForElement el
		self.byElement.get(el) or null

	def audit
		let surfaces = []
		for entry in self.entries
			surfaces.push
				id: entry.id
				tag: entry.element.tagName ? entry.element.tagName.toLowerCase! : 'unknown'
				variant: entry.glass.variantName
				contrast: entry.state.measuredContrast
				target: (preferences.increaseContrast ? settings.contrastHigh : settings.minContrast)
				dimming: entry.state.dimmingOpacity
		{
			violations: logger.currentViolations
			surfaces: surfaces
			counts: {entries: self.entries.length, containers: self.containers.length, unions: self.unions.groupCount}
		}

	get counts
		{entries: self.entries.length, containers: self.containers.length}

	def resetAll
		for entry in self.entries.slice(0)
			unregister entry
		for cont in self.containers.slice(0)
			if cont.element
				unregisterContainer cont.element
		self.containers = []
		self.rootContainer = null
		self.unions.clear!
		self.recentRemovals = []
		logger.clearViolations!
		structureChanged!

export const registry = new GlassRegistry

export def attachContainerFactory factory
	registry.containerFactory = factory
