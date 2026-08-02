import {GlassKit} from '../../src/index'
import {ProceduralBackdrop} from '../procedural'
import {demoState} from '../index'
import {applyGlassEffect, removeGlassEffect} from '../../src/material/glass-effect'
import {Glass} from '../../src/material/glass'
import {Shape} from '../../src/material/shape'
import {scheduler} from '../../src/core/raf-scheduler'

tag gk-demo-performance
	prop shapeCount = 0
	prop dprCap = 2
	prop animating = no
	prop frameStats = []
	prop info = ''

	def mount
		self.spawned = []
		self.fpsCanvas = null
		self.sampleTimer = globalThis.setInterval (do sampleStats!), 250
		self.fieldEl = null
		globalThis.setTimeout (do self.initDomRefs!), 0

	def initDomRefs
		self.fieldEl = self.querySelector '.demo-shapes-field'
		self.fpsCanvas = self.querySelector '.demo-fps-canvas'
		setCount 24

	def unmount
		globalThis.clearInterval self.sampleTimer
		setCount 0

	def sampleStats
		let ms = scheduler.frameAvg or 0
		frameStats.push ms
		if frameStats.length > 120 then frameStats.shift!
		drawGraph!
		imba.commit!

	def drawGraph
		let canvas = self.fpsCanvas
		if canvas == null then return
		let cw = canvas.clientWidth or 600
		let ch = canvas.clientHeight or 120
		let dpr = Math.min 2, (globalThis.devicePixelRatio or 1)
		canvas.width = cw * dpr
		canvas.height = ch * dpr
		let ctx = canvas.getContext '2d'
		ctx.scale dpr, dpr
		ctx.clearRect 0, 0, cw, ch
		ctx.fillStyle = 'rgb(0 0 0 / .25)'
		ctx.fillRect 0, 0, cw, ch
		ctx.strokeStyle = 'rgb(255 255 255 / .18)'
		ctx.beginPath!
		ctx.moveTo 0, ch - 16.7 * 3
		ctx.lineTo cw, ch - 16.7 * 3
		ctx.stroke!
		ctx.strokeStyle = '#30d158'
		ctx.lineWidth = 1.5
		ctx.beginPath!
		for t, i in frameStats
			let x = i / 120 * cw
			let y = ch - Math.min(ch, t) * 3
			if i == 0 then ctx.moveTo x, y else ctx.lineTo x, y
		ctx.stroke!
		let last = frameStats.length > 0 ? frameStats[frameStats.length - 1] : 0
		ctx.fillStyle = 'rgb(255 255 255 / .85)'
		ctx.font = '11px ui-monospace, monospace'
		ctx.fillText "{last.toFixed(2)} ms / frame (line = 16.7 ms)", 8, 14

	def setCount n
		shapeCount = n
		for el in self.spawned
			removeGlassEffect el
			el.remove!
		self.spawned = []
		let field = self.fieldEl
		if field == null or n == 0
			return
		let fw = Math.max 320, field.clientWidth or 640
		for i in [0 ... n]
			let el = globalThis.document.createElement 'div'
			el.className = 'demo-shape'
			let w = 64 + (i * 37 % 80)
			let h = 44 + (i * 53 % 60)
			let x = (i * 97 % Math.max(1, fw - w))
			let y = (i * 61 % 240)
			el.style.cssText = "position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;border-radius:16px"
			field.appendChild el
			let glass = if i % 3 == 0 then Glass.clear else Glass.regular
			if i % 4 == 0 then glass = glass.tint('#5ac8fa', 0.3)
			applyGlassEffect el, glass, Shape.rect(cornerRadius: 16), {namespace: 'perf', spacing: 12}
			self.spawned.push el
		info = "{n} surfaces live"
		imba.commit!

	def setAnimating on
		animating = on
		if on
			spinLoop!
		imba.commit!

	def spinLoop
		unless animating
			return
		globalThis.requestAnimationFrame do(t) self.spinFrame(t)

	def spinFrame t
		for el, i in self.spawned
			let dx = 30 * Math.sin(t / 900 + i)
			let dy = 18 * Math.cos(t / 1100 + i * 1.3)
			el.style.transform = "translate({dx.toFixed(1)}px,{dy.toFixed(1)}px)"
		if animating
			globalThis.requestAnimationFrame do(tt) self.spinFrame(tt)

	def setDprCap e
		dprCap = e.detail.value
		GlassKit.settings.maxDPR = dprCap
		imba.commit!

	def preset24
		dprCap = 2
		GlassKit.settings.maxDPR = 2
		setCount 24

	def render
		let stats = GlassKit.renderer != null ? GlassKit.renderer.stats : null
		<self>
			<gk-section header='Stress Harness' footer='Shape count and animation drive the full pipeline — capture, mip blur, per-chunk SDF shading, composite'>
				<div .demo-grid-2>
					<div .demo-col>
						<gk-slider value=shapeCount min=0 max=64 step=1 label='Surface count' @change=(do(e) self.setCount(e.detail.value))>
						<gk-slider value=dprCap min=1 max=3 step=0.5 label='DPR cap' @change=setDprCap>
						<div .demo-row>
							<gk-button label=(animating ? 'Stop motion' : 'Animate') variant=(animating ? 'tinted' : 'bordered') @activate=(do self.setAnimating(!animating))>
							<gk-button label='24 surfaces / DPR 2' variant='plain' @activate=(do self.preset24!)>
							if info != ''
								<span .demo-note aria-live='polite'> info
					<div>
						<canvas .demo-fps-canvas aria-label='Frame time graph'>
			<div .demo-shapes-field>
			if stats != null
				<div .demo-row>
					<div .demo-stat>
						<b> stats.drawCalls
						<span> "draw calls"
					<div .demo-stat>
						<b> stats.textures.alive
						<span> "live textures"
					<div .demo-stat>
						<b> stats.framebuffers.alive
						<span> "framebuffers"
					<div .demo-stat>
						<b> "T{GlassKit.quality}"
						<span> "auto tier"
