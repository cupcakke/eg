import {Rect} from '../src/core/geometry'
import {dirtyTracker} from '../src/core/dirty-tracker'
import {isBrowser} from '../src/core/env'

export class ProceduralBackdrop
	prop kind

	def constructor kind = 'mesh'
		self.kind = kind
		self.canvas = null
		self.ctx = null
		self.raf = null
		self.running = no
		self.renderer = null
		self.rect = new Rect 0, 0, 1, 1
		self.t0 = 0
		self.frame = 0
		self.particles = []
		self.sourceId = 'demo-backdrop'
		if isBrowser
			self.canvas = globalThis.document.createElement 'canvas'
			self.canvas.width = 960
			self.canvas.height = 540
			self.ctx = self.canvas.getContext '2d'
			seedParticles!

	get element
		self.canvas

	def seedParticles
		self.particles = []
		for i in [0 ... 42]
			self.particles.push
				x: (i * 97 % 960)
				y: (i * 193 % 540)
				vx: 0.18 + (i % 7) * 0.06
				vy: 0.11 + (i % 5) * 0.05
				r: 1.4 + (i % 4) * 0.9

	def viewportRect
		unless isBrowser
			return self.rect
		let vw = globalThis.window.innerWidth
		let vh = globalThis.window.innerHeight
		self.rect.set 0, 0, vw, vh
		self.rect

	def attach renderer
		if self.renderer != null
			detach!
		self.renderer = renderer
		if renderer != null
			renderer.registerContentSource self.sourceId, 'canvas', self.canvas, viewportRect!

	def detach
		if self.renderer != null
			self.renderer.unregisterContentSource self.sourceId
			self.renderer = null

	def start
		if self.running or !isBrowser
			return
		self.running = yes
		self.t0 = Date.now!
		tick!

	def stop
		self.running = no
		if self.raf != null
			globalThis.cancelAnimationFrame self.raf
			self.raf = null

	def tick
		unless self.running
			return
		self.raf = globalThis.requestAnimationFrame do(t) self.tick!
		self.frame += 1
		let speed = if self.kind == 'noise' then 1e9 else (if self.kind == 'particles' then 2 else 3)
		if self.frame % speed != 0 and self.frame > 2
			return
		let t = (Date.now! - self.t0) / 1000
		paint t
		if self.renderer != null
			viewportRect!
		dirtyTracker.markAll!

	def paint t
		switch self.kind
			when 'caustics' then paintCaustics t
			when 'particles' then paintParticles t
			when 'noise' then paintNoise t
			when 'solid' then paintSolid t
			else paintMesh t

	def baseFill top, bottom
		let ctx = self.ctx
		let w = self.canvas.width
		let h = self.canvas.height
		let grad = ctx.createLinearGradient 0, 0, 0, h
		grad.addColorStop 0, top
		grad.addColorStop 1, bottom
		ctx.globalCompositeOperation = 'source-over'
		ctx.fillStyle = grad
		ctx.fillRect 0, 0, w, h

	def paintMesh t
		let ctx = self.ctx
		let w = self.canvas.width
		let h = self.canvas.height
		baseFill '#10121c', '#1b1e2e'
		let blobs = [
			[0.24, 0.22, 0.36, 'rgba(105,80,220,0.42)', 0.9]
			[0.78, 0.30, 0.30, 'rgba(30,140,180,0.38)', 1.4]
			[0.55, 0.78, 0.34, 'rgba(200,70,140,0.30)', 0.7]
			[0.15, 0.85, 0.28, 'rgba(70,150,90,0.26)', 1.1]
		]
		for blob, i in blobs
			let cx = (blob[0] + 0.09 * Math.sin(t * 0.21 * blob[4] + i * 1.7)) * w
			let cy = (blob[1] + 0.08 * Math.cos(t * 0.17 * blob[4] + i * 2.3)) * h
			let r = blob[2] * Math.min(w, h) * (1 + 0.12 * Math.sin(t * 0.3 + i))
			let grad = ctx.createRadialGradient cx, cy, 0, cx, cy, r
			grad.addColorStop 0, blob[3]
			grad.addColorStop 1, 'rgba(0,0,0,0)'
			ctx.fillStyle = grad
			ctx.fillRect 0, 0, w, h
		ctx.strokeStyle = 'rgba(255,255,255,0.045)'
		ctx.lineWidth = 1
		let gap = 48
		for gx in [0 ... Math.ceil(w / gap) + 1]
			ctx.beginPath!
			ctx.moveTo gx * gap + 0.5, 0
			ctx.lineTo gx * gap + 0.5, h
			ctx.stroke!
		for gy in [0 ... Math.ceil(h / gap) + 1]
			ctx.beginPath!
			ctx.moveTo 0, gy * gap + 0.5
			ctx.lineTo w, gy * gap + 0.5
			ctx.stroke!

	def paintCaustics t
		let ctx = self.ctx
		let w = self.canvas.width
		let h = self.canvas.height
		baseFill '#03202c', '#013545'
		ctx.globalCompositeOperation = 'lighter'
		for i in [0 ... 9]
			let cx = (0.5 + 0.42 * Math.sin(t * 0.24 + i * 0.9)) * w
			let cy = (0.5 + 0.38 * Math.cos(t * 0.19 + i * 1.4)) * h
			let r = (0.1 + 0.05 * (i % 3)) * Math.min(w, h)
			let grad = ctx.createRadialGradient cx, cy, r * 0.55, cx, cy, r
			grad.addColorStop 0, 'rgba(0,0,0,0)'
			grad.addColorStop 0.8, "rgba(90,{180 + (i * 7) % 60},200,0.11)"
			grad.addColorStop 1, 'rgba(0,0,0,0)'
			ctx.fillStyle = grad
			ctx.fillRect 0, 0, w, h
		ctx.globalCompositeOperation = 'source-over'

	def paintParticles t
		let ctx = self.ctx
		let w = self.canvas.width
		let h = self.canvas.height
		baseFill '#14101e', '#1e1428'
		for p in self.particles
			p.x += p.vx
			p.y += p.vy * Math.sin(t * 0.4 + p.r)
			if p.x > w + 10 then p.x = -10
			if p.y > h + 10 then p.y = -10
			if p.y < -10 then p.y = h + 10
		ctx.strokeStyle = 'rgba(150,130,220,0.12)'
		ctx.lineWidth = 1
		for a, i in self.particles
			for b, j in self.particles
				if j <= i then continue
				let dx = a.x - b.x
				let dy = a.y - b.y
				if dx * dx + dy * dy < 110 * 110
					ctx.beginPath!
					ctx.moveTo a.x, a.y
					ctx.lineTo b.x, b.y
					ctx.stroke!
		for p in self.particles
			let grad = ctx.createRadialGradient p.x, p.y, 0, p.x, p.y, p.r * 3
			grad.addColorStop 0, 'rgba(200,180,255,0.5)'
			grad.addColorStop 1, 'rgba(200,180,255,0)'
			ctx.fillStyle = grad
			ctx.beginPath!
			ctx.arc p.x, p.y, p.r * 3, 0, Math.PI * 2
			ctx.fill!

	def paintNoise t
		let ctx = self.ctx
		let w = self.canvas.width
		let h = self.canvas.height
		baseFill '#14161f', '#101018'
		let cell = 60
		for gy in [0 ... Math.ceil(h / cell)]
			for gx in [0 ... Math.ceil(w / cell)]
				let n = Math.sin(gx * 12.9898 + gy * 78.233) * 43758.5453
				n = n - Math.floor(n)
				ctx.fillStyle = "rgba(255,255,255,{(0.02 + n * 0.06).toFixed(3)})"
				ctx.fillRect gx * cell, gy * cell, cell - 2, cell - 2

	def paintSolid t
		baseFill '#15161d', '#0e0f15'
