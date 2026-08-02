import {registry} from './glass-registry'
import {resolveGlass} from './glass'
import {Shape} from './shape'
import {logger} from '../core/logger'
import {uid} from '../core/id'
import {now} from '../core/env'

export class GlassEffectHandle
	def constructor entry
		self.entry = entry
		self.id = entry.id
		self.disposed = no

	def update glassValue
		if self.disposed
			return self
		registry.updateGlass self.entry, glassValue
		self

	def updateShape shapeDescriptor
		if self.disposed
			return self
		registry.updateShape self.entry, shapeDescriptor
		self

	get element
		self.entry.element

	def dispose
		unless self.disposed
			self.disposed = yes
			registry.unregister self.entry

export def applyGlassEffect el, glassValue = null, shapeDescriptor = null, opts = {}
	if el == null
		throw new Error 'GlassKit: [glass-effect] requires a target element'
	let glass = resolveGlass glassValue
	let shape = shapeDescriptor or Shape.capsule()
	opts.namespace = opts.namespace or el.getAttribute('glass-namespace') or 'default'
	opts.glassId = opts.glassId or el.getAttribute('glass-id') or null
	opts.unionId = opts.unionId or el.getAttribute('glass-union') or null
	opts.transition = opts.transition or el.getAttribute('glass-transition') or null
	let entry = registry.register el, glass, shape, opts
	el.__gkEffectAppliedAt = now!
	el.setAttribute 'data-gk-glass', ''
	new GlassEffectHandle entry

export def removeGlassEffect el
	let entry = registry.entryForElement el
	if entry != null
		registry.unregister entry
		el.removeAttribute 'data-gk-glass'
		yes
	else
		no

export def glassEffectFor el
	registry.entryForElement el
