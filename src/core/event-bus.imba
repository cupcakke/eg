export class EventBus
	def constructor
		self.listeners = new Map

	def on event, fn
		let set = self.listeners.get(event)
		unless set
			set = new Set
			self.listeners.set event, set
		set.add fn
		do self.off(event, fn)

	def once event, fn
		let wrapper = do(payload)
			self.off event, wrapper
			fn payload
		on event, wrapper

	def off event, fn
		let set = self.listeners.get(event)
		if set
			set.delete fn
			if set.size == 0
				self.listeners.delete event
		self

	def emit event, payload = undefined
		let set = self.listeners.get(event)
		if set
			for fn in set
				fn payload
		self

	def clear
		self.listeners.clear

	get listenerCount
		let n = 0
		self.listeners.forEach do(set)
			n += set.size
		n

export const bus = new EventBus
