import {GlassKit} from '../index'
import {isBrowser} from '../core/env'
import {logger} from '../core/logger'
import {clamp} from '../core/math'

export const ICON_VARIANTS = ['default', 'dark', 'clear-light', 'clear-dark', 'tinted-light', 'tinted-dark']

export def normalizeTint value
	if value == null
		return null
	if typeof value == 'string'
		let s = value.trim!
		if s.charAt(0) == '#'
			let hex = s.slice 1
			if hex.length == 3
				hex = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1) + hex.charAt(2) + hex.charAt(2)
			let n = parseInt hex, 16
			return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255, 1]
		return null
	if Array.isArray value
		let r = value[0] or 0
		let g = value[1] or 0
		let b = value[2] or 0
		let a = if value.length > 3 then value[3] else 1
		if r > 1 or g > 1 or b > 1
			return [r / 255, g / 255, b / 255, a]
		return [r, g, b, a]
	null

export class IconLayer
	prop tint
	prop opacity
	prop blur
	prop specular
	prop refraction
	prop innerShadow
	prop offset
	prop scale
	prop maskTexture

	def constructor spec = {}
		self.tint = normalizeTint spec.tint
		self.opacity = spec.opacity != null ? spec.opacity : 1
		self.blur = spec.blur or 0
		self.specular = spec.specular or 0
		self.refraction = spec.refraction or 0
		self.innerShadow = spec.innerShadow or 0
		self.offset = spec.offset or [0, 0]
		self.scale = spec.scale or 1
		self.path = spec.path or null
		self.draw = spec.draw or null
		self.maskCanvas = null
		self.maskTexture = null

export def superellipsePoints cx, cy, rx, ry, n = 4, segments = 64
	let pts = []
	for i in [0 ... segments]
		let t = i / segments * Math.PI * 2
		let c = Math.cos t
		let s = Math.sin t
		let px = Math.sign(c) * Math.pow(Math.abs(c), 2 / n)
		let py = Math.sign(s) * Math.pow(Math.abs(s), 2 / n)
		pts.push [cx + rx * px, cy + ry * py]
	pts

export def platformPath ctx, platform, w, h, radiusPct = 0.2237
	ctx.beginPath!
	if platform == 'circle'
		ctx.arc w / 2, h / 2, Math.min(w, h) / 2, 0, Math.PI * 2
		ctx.closePath!
		return
	let r = clamp(radiusPct, 0, 0.5) * Math.min(w, h)
	let n = 4.0
	let s = 16
	ctx.moveTo w - r, 0
	let corners = [[w - r, r, -Math.PI / 2, 0], [w - r, h - r, 0, Math.PI / 2], [r, h - r, Math.PI / 2, Math.PI], [r, r, Math.PI, Math.PI * 1.5]]
	for corner in corners
		for i in [0 ... s + 1]
			let t = corner[2] + (corner[3] - corner[2]) * i / s
			let c = Math.cos t
			let sn = Math.sin t
			ctx.lineTo corner[0] + r * Math.sign(c) * Math.pow(Math.abs(c), 2 / n), corner[1] + r * Math.sign(sn) * Math.pow(Math.abs(sn), 2 / n)
	ctx.closePath!

export def parseIconLayers raw
	if raw == null or raw == ''
		return []
	let data = raw
	if typeof raw == 'string'
		try
			data = JSON.parse raw
		catch err
			logger.warnOnce 'app-icon-layers-json', "gk-app-icon: layers attribute is not valid JSON — {err.message}"
			return []
	unless Array.isArray data
		return []
	let out = []
	for spec in data
		if spec != null
			out.push new IconLayer spec
	out

export def buildMaskCanvas layer, size
	if !isBrowser
		return null
	let c = globalThis.document.createElement 'canvas'
	c.width = size
	c.height = size
	let ctx = c.getContext '2d'
	ctx.clearRect 0, 0, size, size
	ctx.save!
	ctx.translate size / 2 + layer.offset[0], size / 2 + layer.offset[1]
	ctx.scale layer.scale, layer.scale
	ctx.translate -size / 2, -size / 2
	ctx.fillStyle = '#ffffff'
	if layer.path != null and typeof globalThis.Path2D == 'function'
		let path = new globalThis.Path2D layer.path
		ctx.fill path
	if layer.draw != null
		layer.draw ctx, size
	ctx.restore!
	layer.maskCanvas = c
	c

const ADJUSTMENTS =
	default: {bgDim: 0, specularScale: 1, clear: no, tint: null}
	dark: {bgDim: 0.55, specularScale: 0.7, clear: no, tint: null}
	'clear-light': {bgDim: 0, specularScale: 1.15, clear: yes, clearDark: no, tint: null}
	'clear-dark': {bgDim: 0, specularScale: 1.2, clear: yes, clearDark: yes, tint: null}
	'tinted-light': {bgDim: 0, specularScale: 1, clear: no, tint: [0.2, 0.45, 0.95, 0.22]}
	'tinted-dark': {bgDim: 0.5, specularScale: 0.85, clear: no, tint: [0.25, 0.5, 1.0, 0.3]}

export def variantAdjustment variant
	ADJUSTMENTS[variant] or ADJUSTMENTS.default

tag gk-app-icon
	prop size = 128
	prop platform = 'superellipse'
	prop layers = null
	prop background = null
	prop variant = 'default'
	prop previews = no
	prop useGPU = yes
	prop label = 'Application icon'

	def mount
		self.renderQueued = no
		scheduleRender!

	def layersDidSet v
		scheduleRender!

	def backgroundDidSet v
		scheduleRender!

	def platformDidSet v
		scheduleRender!

	def variantDidSet v
		scheduleRender!

	def sizeDidSet v
		scheduleRender!

	def scheduleRender
		if self.renderQueued
			return
		self.renderQueued = yes
		globalThis.setTimeout (do self.flushRender!), 0

	def flushRender
		self.renderQueued = no
		renderAll!

	def layerList
		parseIconLayers layers

	def backgroundSpec
		let bg = background
		if typeof bg == 'string'
			let trimmed = bg.trim!
			if trimmed.charAt(0) == '{'
				try
					return JSON.parse trimmed
				catch err
					return {color: '#8e8e93', colorTo: '#636366'}
			return {color: trimmed, colorTo: trimmed}
		bg or {color: '#8e8e93', colorTo: '#636366'}

	def gpuRenderer
		let renderer = GlassKit.renderer
		if useGPU and renderer != null and renderer.iconPass != null and renderer.mode != 'css'
			renderer
		null

	def renderAll
		unless isBrowser
			return
		let list = layerList!
		let els = self.querySelectorAll 'canvas'
		if previews
			for i in [0 ... Math.min(els.length, ICON_VARIANTS.length)]
				renderIcon els[i], list, ICON_VARIANTS[i]
		elif els.length > 0
			renderIcon els[0], list, variant

	def renderIcon canvas, list, variantName
		let px = Math.max 16, Math.round(Number size)
		if canvas.width != px then canvas.width = px
		if canvas.height != px then canvas.height = px
		let adj = variantAdjustment variantName
		for layer in list
			if layer.maskCanvas == null or layer.maskCanvas.width != px
				buildMaskCanvas layer, px
		let gpu = gpuRenderer!
		if gpu != null and renderWithGPU(canvas, list, adj, px)
			return
		renderWithCPU canvas, list, adj, px

	def shapeRadiusPx px
		if platform == 'circle' then px / 2 else clamp(0.2237, 0, 0.5) * px

	def renderWithGPU canvas, list, adj, px
		let renderer = gpuRenderer!
		let iconPass = renderer.iconPass
		let env = renderer.env
		try
			iconPass.ensureSize env, px
			for layer in list
				layer.maskTexture = iconPass.uploadMask env, layer.maskCanvas
			let opts =
				maskPx: [px, px]
				maskOffset: [0, 0]
				shapeRect: [0, 0, px, px]
				shapeRadius: shapeRadiusPx px
				shapeType: platform == 'circle' ? 1 : 0
				shadowOffset: [0, px * 0.045]
				shadowRadius: px * 0.09
				shadowOpacity: 0.35
				lightDir: [-0.4, 0.8, 0.45]
			iconPass.renderShadow env, opts
			for layer in list
				let lt = layer.tint or [1, 1, 1, 1]
				let gpuLayer =
					tint: [lt[0], lt[1], lt[2], lt[3]]
					opacity: layer.opacity
					specular: layer.specular * (adj.specularScale or 1)
					refraction: layer.refraction + (adj.clear ? 0.35 : 0)
					innerShadow: layer.innerShadow
					blur: layer.blur
					maskTexture: layer.maskTexture
				iconPass.renderLayer env, gpuLayer, opts
			iconPass.readToCanvas env, canvas
			if adj.bgDim > 0 or adj.tint != null
				applyVariantCanvas canvas, adj, px
			iconPass.releaseScratch!
			yes
		catch err
			logger.warn "gk-app-icon: GPU compositing failed ({err.message}) — using CPU compositor"
			no

	def renderWithCPU canvas, list, adj, px
		let ctx = canvas.getContext '2d'
		ctx.clearRect 0, 0, px, px
		ctx.save!
		platformPath ctx, platform, px, px
		ctx.clip!
		drawBackgroundCPU ctx, adj, px
		for layer in list
			drawLayerCPU ctx, layer, adj, px
		ctx.restore!
		drawShapeGloss ctx, adj, px

	def drawBackgroundCPU ctx, adj, px
		let bg = backgroundSpec!
		if adj.clear
			let grad = ctx.createLinearGradient 0, 0, 0, px
			if adj.clearDark
				grad.addColorStop 0, 'rgba(30,32,38,0.55)'
				grad.addColorStop 1, 'rgba(10,12,16,0.72)'
			else
				grad.addColorStop 0, 'rgba(255,255,255,0.45)'
				grad.addColorStop 1, 'rgba(225,228,235,0.6)'
			ctx.fillStyle = grad
			ctx.fillRect 0, 0, px, px
			return yes
		let grad = ctx.createLinearGradient 0, 0, 0, px
		grad.addColorStop 0, (bg.color or '#8e8e93')
		grad.addColorStop 1, (bg.colorTo or bg.color or '#636366')
		ctx.fillStyle = grad
		ctx.fillRect 0, 0, px, px
		if adj.bgDim > 0
			ctx.fillStyle = "rgba(8,10,14,{adj.bgDim.toFixed(3)})"
			ctx.fillRect 0, 0, px, px
		if adj.tint != null
			let t = adj.tint
			ctx.fillStyle = "rgba({Math.round(t[0] * 255)},{Math.round(t[1] * 255)},{Math.round(t[2] * 255)},{t[3].toFixed(3)})"
			ctx.fillRect 0, 0, px, px
		yes

	def scratchCanvas name, px
		let store = self.scratchStore
		if store == null
			store = self.scratchStore = {}
		let c = store[name]
		if c == null
			c = store[name] = globalThis.document.createElement 'canvas'
		if c.width != px then c.width = px
		if c.height != px then c.height = px
		c

	def drawLayerCPU ctx, layer, adj, px
		let mask = layer.maskCanvas
		if mask == null
			return
		ctx.save!
		if layer.blur > 0
			ctx.filter = "blur({(layer.blur * px / 128).toFixed(2)}px)"
		ctx.globalAlpha = clamp layer.opacity, 0, 1
		ctx.drawImage mask, 0, 0
		ctx.filter = 'none'
		if layer.tint != null
			let t = layer.tint
			ctx.globalCompositeOperation = 'source-atop'
			ctx.fillStyle = "rgba({Math.round(t[0] * 255)},{Math.round(t[1] * 255)},{Math.round(t[2] * 255)},{t[3].toFixed(3)})"
			ctx.fillRect 0, 0, px, px
		ctx.restore!
		if layer.innerShadow > 0
			let shadow = scratchCanvas 'shadow', px
			let sctx = shadow.getContext '2d'
			sctx.clearRect 0, 0, px, px
			sctx.globalCompositeOperation = 'source-over'
			sctx.filter = "blur({(layer.innerShadow * px / 96).toFixed(2)}px)"
			sctx.drawImage mask, 0, -(layer.innerShadow * px / 128)
			sctx.filter = 'none'
			sctx.globalCompositeOperation = 'source-in'
			sctx.fillStyle = 'rgba(0,0,0,0.55)'
			sctx.fillRect 0, 0, px, px
			sctx.globalCompositeOperation = 'destination-in'
			sctx.drawImage mask, 0, 0
			ctx.save!
			ctx.globalCompositeOperation = 'multiply'
			ctx.drawImage shadow, 0, 0
			ctx.restore!
		if layer.specular > 0
			let spec = clamp(layer.specular * (adj.specularScale or 1), 0, 1)
			let specCanvas = scratchCanvas 'spec', px
			let mctx = specCanvas.getContext '2d'
			mctx.clearRect 0, 0, px, px
			mctx.globalCompositeOperation = 'source-over'
			mctx.drawImage mask, 0, 0
			mctx.globalCompositeOperation = 'source-in'
			let grad = mctx.createLinearGradient 0, 0, px * 0.65, px
			grad.addColorStop 0, "rgba(255,255,255,{(0.55 * spec).toFixed(3)})"
			grad.addColorStop 0.45, 'rgba(255,255,255,0)'
			mctx.fillStyle = grad
			mctx.fillRect 0, 0, px, px
			ctx.save!
			ctx.globalCompositeOperation = 'lighter'
			ctx.drawImage specCanvas, 0, 0
			ctx.restore!
		if layer.refraction > 0 or adj.clear
			let amount = layer.refraction + (adj.clear ? 0.35 : 0)
			let shift = amount * px * 0.016
			let rim = scratchCanvas 'rim', px
			let rctx = rim.getContext '2d'
			rctx.clearRect 0, 0, px, px
			rctx.globalCompositeOperation = 'source-over'
			rctx.drawImage mask, 0, 0
			rctx.globalCompositeOperation = 'source-in'
			let grad = rctx.createLinearGradient 0, 0, 0, px
			grad.addColorStop 0, 'rgba(255,255,255,0.10)'
			grad.addColorStop 1, 'rgba(255,255,255,0.02)'
			rctx.fillStyle = grad
			rctx.fillRect 0, 0, px, px
			ctx.save!
			ctx.drawImage rim, 0, shift
			ctx.restore!

	def drawShapeGloss ctx, adj, px
		ctx.save!
		platformPath ctx, platform, px, px
		ctx.clip!
		let grad = ctx.createLinearGradient 0, 0, 0, px * 0.55
		grad.addColorStop 0, 'rgba(255,255,255,0.18)'
		grad.addColorStop 1, 'rgba(255,255,255,0)'
		ctx.fillStyle = grad
		ctx.fillRect 0, 0, px, px
		ctx.restore!

	def applyVariantCanvas canvas, adj, px
		let ctx = canvas.getContext '2d'
		ctx.save!
		platformPath ctx, platform, px, px
		ctx.clip!
		if adj.bgDim > 0
			ctx.fillStyle = "rgba(8,10,14,{adj.bgDim.toFixed(3)})"
			ctx.fillRect 0, 0, px, px
		if adj.tint != null
			let t = adj.tint
			ctx.fillStyle = "rgba({Math.round(t[0] * 255)},{Math.round(t[1] * 255)},{Math.round(t[2] * 255)},{t[3].toFixed(3)})"
			ctx.fillRect 0, 0, px, px
		ctx.restore!

	def render
		<self role='img' aria-label=label data-platform=platform data-previews=(previews ? '1' : null)>
			if previews
				for v, i in ICON_VARIANTS
					<figure .gk-icon-preview key=v>
						<canvas width=size height=size>
						<figcaption> v
			else
				<canvas width=size height=size>
