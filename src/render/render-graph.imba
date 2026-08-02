import {logger} from '../core/logger'

export class RenderPass
	prop name
	prop deps

	def constructor name, runFn, opts = {}
		self.name = name
		self.runFn = runFn
		self.deps = opts.deps or []
		self.dirtyFn = opts.dirty or null
		self.enabledFn = opts.enabled or null
		self.executed = no

	def isDirty frame
		if self.dirtyFn == null
			return yes
		self.dirtyFn frame

	def isEnabled frame
		if self.enabledFn == null
			return yes
		self.enabledFn frame

export class RenderGraph
	def constructor
		self.passes = new Map
		self.resolved = []
		self.dirtyGraph = yes
		self.plan = []
		self.lastExecuted = 0
		self.lastSkipped = 0

	def add pass
		self.passes.set pass.name, pass
		self.dirtyGraph = yes
		pass

	def remove name
		self.passes.delete name
		self.dirtyGraph = yes

	def resolve
		unless self.dirtyGraph
			return self.resolved
		let order = []
		let visiting = new Set
		let visited = new Set
		let visit = do(name)
			if visited.has(name)
				return
			if visiting.has(name)
				throw new Error "GlassKit: render graph cycle detected at pass '{name}'"
			visiting.add name
			let pass = self.passes.get(name)
			if pass == null
				throw new Error "GlassKit: render graph dependency '{name}' is not registered"
			for dep in pass.deps
				visit dep
			visiting.delete name
			visited.add name
			order.push pass
		let names = []
		self.passes.forEach do(pass, name)
			names.push name
		for name in names
			visit name
		self.resolved = order
		self.dirtyGraph = no
		self.resolved

	def planFor frame
		let order = resolve!
		self.plan.length = 0
		for pass in order
			if pass.isEnabled(frame) and pass.isDirty(frame)
				self.plan.push pass
		self.plan

	def run gl, frame
		let plan = planFor frame
		self.lastExecuted = 0
		self.lastSkipped = self.resolved.length - plan.length
		for pass in plan
			pass.runFn gl, frame
			pass.executed = yes
			self.lastExecuted += 1
		plan.length

	def describe frame = null
		let lines = ['RenderGraph (' + String(self.resolved.length) + ' passes)']
		for pass in resolve!
			let state = 'run'
			if frame != null
				if !pass.isEnabled(frame)
					state = 'disabled'
				elif !pass.isDirty(frame)
					state = 'culled'
			let deps = pass.deps.length > 0 ? ' <- [{pass.deps.join(", ")}]' : ''
			lines.push "  [{state}] {pass.name}{deps}"
		let s = lines.join('\n')
		if logger.devEnabled
			logger.info s
		s

export def createGraph
	new RenderGraph
