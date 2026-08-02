import {lerp} from './math'
import {SPRING_EPSILON_POS, SPRING_EPSILON_VEL} from './constants'

class SpringCurve
	prop response
	prop damping
	prop target
	prop start
	prop velocity
	prop time

	def constructor response, damping, target, start, velocity, time = 0
		self.response = Math.max 1e-4, response
		self.damping = Math.max 0, damping
		self.target = target
		self.start = start
		self.velocity = velocity
		self.time = time

	def evalAt t
		let w0 = 2 * Math.PI / self.response
		let z = self.damping
		let y0 = self.start - self.target
		let v0 = self.velocity
		let y = 0
		if z < 0.999999
			let wd = w0 * Math.sqrt(1 - z * z)
			let A = y0
			let B = (v0 + z * w0 * y0) / wd
			let env = Math.exp(-z * w0 * t)
			y = env * (A * Math.cos(wd * t) + B * Math.sin(wd * t))
		elif z <= 1.000001
			let C1 = y0
			let C2 = v0 + w0 * y0
			y = (C1 + C2 * t) * Math.exp(-w0 * t)
		else
			let root = Math.sqrt(z * z - 1)
			let s1 = w0 * (-z + root)
			let s2 = w0 * (-z - root)
			let A = (v0 - s2 * y0) / (s1 - s2)
			let B = y0 - A
			y = A * Math.exp(s1 * t) + B * Math.exp(s2 * t)
		self.target + y

	def evalVelocityAt t
		let w0 = 2 * Math.PI / self.response
		let z = self.damping
		let y0 = self.start - self.target
		let v0 = self.velocity
		if z < 0.999999
			let wd = w0 * Math.sqrt(1 - z * z)
			let A = y0
			let B = (v0 + z * w0 * y0) / wd
			let a = -z * w0
			let env = Math.exp(a * t)
			env * ((a * A + B * wd) * Math.cos(wd * t) + (a * B - A * wd) * Math.sin(wd * t))
		elif z <= 1.000001
			let C1 = y0
			let C2 = v0 + w0 * y0
			let env = Math.exp(-w0 * t)
			env * (C2 - w0 * (C1 + C2 * t))
		else
			let root = Math.sqrt(z * z - 1)
			let s1 = w0 * (-z + root)
			let s2 = w0 * (-z - root)
			let A = (v0 - s2 * y0) / (s1 - s2)
			let B = y0 - A
			A * s1 * Math.exp(s1 * t) + B * s2 * Math.exp(s2 * t)

export class Spring
	prop response
	prop dampingFraction
	prop blendDuration
	prop value
	prop target
	prop velocity

	static get smooth
		new Spring(0.5, 1.0, 0)

	static get snappy
		new Spring(0.3, 0.86, 0)

	static get bouncy
		new Spring(0.5, 0.6, 0)

	def constructor response = 0.4, dampingFraction = 1.0, blendDuration = 0
		self.response = Math.max 1e-4, response
		self.dampingFraction = dampingFraction
		self.blendDuration = Math.max 0, blendDuration
		self.value = 0
		self.target = 0
		self.velocity = 0
		self.curve = new SpringCurve(self.response, self.dampingFraction, 0, 0, 0)
		self.previous = null
		self.blendElapsed = 0

	def setTarget target, velocity = null
		let t = Number target
		if velocity != null
			self.velocity = Number velocity
		if self.blendDuration > 0 and self.curve
			self.previous = self.curve
			self.blendElapsed = 0
		else
			self.previous = null
		self.target = t
		self.curve = new SpringCurve(self.response, self.dampingFraction, t, self.value, self.velocity)
		self

	def snapTo v
		self.value = v
		self.target = v
		self.velocity = 0
		self.curve = new SpringCurve(self.response, self.dampingFraction, v, v, 0)
		self.previous = null
		self

	def advance dt
		if self.curve == null
			return self.value
		self.curve.time += dt
		let value = self.curve.evalAt(self.curve.time)
		let vel = self.curve.evalVelocityAt(self.curve.time)
		if self.previous != null
			self.previous.time += dt
			self.blendElapsed += dt
			let blendT = Math.min 1, self.blendElapsed / self.blendDuration
			let pv = self.previous.evalAt(self.previous.time)
			let pvel = self.previous.evalVelocityAt(self.previous.time)
			value = lerp(pv, value, blendT)
			vel = lerp(pvel, vel, blendT)
			if blendT >= 1
				self.previous = null
		self.value = value
		self.velocity = vel
		self.value

	get settled
		if self.previous != null and self.blendElapsed < self.blendDuration
			return no
		Math.abs(self.value - self.target) < SPRING_EPSILON_POS and Math.abs(self.velocity) < SPRING_EPSILON_VEL

	def hasVelocity
		Math.abs(self.velocity) >= SPRING_EPSILON_VEL
