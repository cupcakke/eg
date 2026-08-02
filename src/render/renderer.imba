import {GLContextHost} from './gl-context'
import {ProgramCache, programStats} from './program'
import {FullscreenQuad} from './quad'
import {BlurPipeline} from './blur-pipeline'
import {BackdropCapture} from './backdrop-capture'
import {CompositePass} from './composite-pass'
import {GlassPass} from './glass-pass'
import {HighlightPass} from './highlight-pass'
import {ShadowPass} from './shadow-pass'
import {ScrollEdgePass} from './scroll-edge-pass'
import {BackgroundExtensionPass} from './background-extension-pass'
import {IconPass} from './icon-pass'
import {Texture} from './texture'
import {RenderGraph} from './render-graph'
import {CssFallbackRenderer} from './css-fallback'
import {textureStats} from './texture'
import {framebufferStats} from './framebuffer'
import {lodForRadius} from './gl-utils'
import {dirtyTracker} from '../core/dirty-tracker'
import {scheduler} from '../core/raf-scheduler'
import {settings} from '../core/settings'
import {preferences} from '../a11y/preferences'
import {registry} from '../material/glass-registry'
import {Rect} from '../core/geometry'
import {isBrowser, dpr as envDpr} from '../core/env'
import {bus} from '../core/event-bus'
import {logger} from '../core/logger'
import {MAX_SHAPES, FLOATS_PER_SHAPE, LUM_UPDATE_INTERVAL} from '../core/constants'
import {detectCapabilities} from '../core/capabilities'
import {LuminanceProbe} from '../material/luminance-probe'
import {shaders3, shaders100} from './shaders.gen'

const LIGHT = (do
	let l = Math.sqrt(0.38 * 0.38 + 0.82 * 0.82 + 0.42 * 0.42)
	[-0.38 / l, 0.82 / l, 0.42 / l]
)()

class FrameEnv
	prop gl
	prop isGL2
	prop width
	prop height
	prop dpr
	prop viewportHeightCss
	prop flags
	prop time
	prop lightDir

	def constructor renderer
		self.renderer = renderer
		self.gl = null
		self.isGL2 = no
		self.width = 2
		self.height = 2
		self.dpr = 1
		self.viewportHeightCss = 600
		self.flags = 0
		self.time = 0
		self.lightDir = LIGHT
		self.chromScale = 1
		self.rimScale = 1
		self.specularScale = 1
		self.shadowEnabled = yes
		self.blurMaxLod = 0
		self.blurDescriptor = null
		self.captureTexture = null
		self.tempRect = new Rect

	get programs
		self.renderer.programs

	get quad
		self.renderer.quad

	def shaderFor name
		if self.isGL2
			shaders3[name]
		else
			shaders100[name]

	def bindBlurLod prog
		let desc = self.blurDescriptor
		if desc == null
			return
		if desc.mode == 'lod'
			prog.uTexture 'uBlur', desc.texture, 0
			prog.u1f 'uBlurMaxLod', desc.maxLod
		elif desc.mode == 'single'
			prog.uTexture 'uBlur', desc.texture, 0
			prog.u1f 'uBlurMaxLod', 0
		else
			prog.uTexture 'uBlur', desc.levels[0].texture, 0
			prog.u1f 'uBlurMaxLod', 0

	def bindBlurPair prog, radius = 0
		let desc = self.blurDescriptor
		if desc == null
			return
		if desc.mode == 'levels'
			let lod = lodForRadius radius
			let lo = Math.min desc.maxLod, Math.floor(lod)
			let hi = Math.min desc.maxLod, lo + 1
			prog.uTexture 'uBlur', desc.levels[lo].texture, 0
			prog.uTexture 'uBlur2', desc.levels[hi].texture, 1
			prog.u1f 'uLodMix', lod - lo
			prog.u1f 'uBlurMaxLod', desc.maxLod
		elif desc.mode == 'lod'
			prog.uTexture 'uBlur', desc.texture, 0
			prog.uTexture 'uBlur2', desc.texture, 1
			prog.u1f 'uLodMix', 0
		else
			prog.uTexture 'uBlur', desc.texture, 0
			prog.uTexture 'uBlur2', desc.texture, 1
			prog.u1f 'uLodMix', 0

	def bindGlassUniforms prog, container
		let gl = self.gl
		prog.u2f 'uResolution', self.width, self.height
		let r = container.clipRectGL
		prog.u4f 'uDrawRect', r.x, r.y, r.w, r.h
		prog.u1f 'uSpacing', container.spacing * self.dpr
		prog.u3f 'uLightDir', self.lightDir[0], self.lightDir[1], self.lightDir[2]
		prog.u1f 'uTime', self.time
		prog.u1f 'uDpr', self.dpr
		prog.u1f 'uAAWidth', 1.0
		prog.u1f 'uRimDistance', 6.0 * self.dpr
		prog.u1f 'uIOR', 1.45
		prog.u1f 'uChromScale', self.chromScale
		prog.u1f 'uRimScale', self.rimScale
		prog.u1f 'uSpecularScale', self.specularScale
		prog.uTexture 'uBackdrop', self.captureTexture, 2
		if self.isGL2
			prog.u1i 'uShapeCount', container.chunkCount
			prog.u1i 'uFlags', self.flags
			bindBlurLod prog, container.maxBlurRadius * self.dpr
		else
			prog.u1f 'uShapeCount', container.chunkCount
			prog.u1i 'uFlags', self.flags
			bindBlurPair prog, container.maxBlurRadius * self.dpr
			if self.renderer.shapeTexture
				prog.uTexture 'uShapeTex', self.renderer.shapeTexture, 3
			if self.renderer.polyTexture
				prog.uTexture 'uPolyTex', self.renderer.polyTexture, 4

	def drawContainerQuad prog, container
		let gl = self.gl
		let r = container.clipRectGL
		gl.enable gl.SCISSOR_TEST
		gl.scissor Math.max(0, Math.floor(r.x)), Math.max(0, Math.floor(r.y)), Math.max(1, Math.ceil(r.w)), Math.max(1, Math.ceil(r.h))
		prog.drawQuad self.quad
		gl.disable gl.SCISSOR_TEST

export class Renderer
	prop mode
	prop width
	prop height
	prop dpr

	def constructor mountEl = null, opts = {}
		self.mountEl = mountEl
		self.canvas = null
		self.host = null
		self.mode = 'idle'
		self.programs = null
		self.quad = null
		self.blurPipeline = null
		self.capture = null
		self.compositePass = new CompositePass
		self.glassPass = new GlassPass
		self.highlightPass = new HighlightPass
		self.shadowPass = new ShadowPass
		self.scrollEdgePass = new ScrollEdgePass
		self.backgroundExtensionPass = new BackgroundExtensionPass
		self.iconPass = new IconPass
		self.graph = new RenderGraph
		self.env = new FrameEnv self
		self.probe = null
		self.css = null
		self.glassUbo = null
		self.polyUbo = null
		self.shapeTexture = null
		self.polyTexture = null
		self.shapeData = new Float32Array MAX_SHAPES * FLOATS_PER_SHAPE
		self.shapeBytes = new Uint8Array MAX_SHAPES * FLOATS_PER_SHAPE * 4
		self.polyData = new Float32Array 8 * 6 * 4
		self.width = 2
		self.height = 2
		self.dpr = 1
		self.resizePending = yes
		self.resizeTimer = null
		self.frameCount = 0
		self.drawCalls = 0
		self.edgeEffects = []
		self.bgEffects = []
		self.disposed = no
		self.shapeSnapshots = new Map
		self.backdropSnapshots = new Map
		self.describedOnce = no
		self.lightsFlipped = no
		self.timeAccum = 0
		self.polyBytesCache = new Uint8Array 8 * 6 * 4

	def init
		unless isBrowser
			self.mode = 'headless'
			return no
		let canvas = globalThis.document.createElement 'canvas'
		canvas.setAttribute 'data-gk-renderer', ''
		canvas.style.cssText = 'position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:2147483000;'
		let root = self.mountEl or globalThis.document.body
		root.appendChild canvas
		self.canvas = canvas
		self.host = new GLContextHost canvas
		let gl = self.host.gl
		self.mode = self.host.mode
		if self.host.isCSS
			self.css = new CssFallbackRenderer
			self.css.start self
			return yes
		self.env.gl = gl
		self.env.isGL2 = self.host.isGL2
		gl.disable gl.DEPTH_TEST
		gl.disable gl.CULL_FACE
		gl.enable gl.BLEND
		gl.blendFunc gl.ONE, gl.ONE_MINUS_SRC_ALPHA
		self.quad = new FullscreenQuad gl
		self.programs = new ProgramCache gl
		self.blurPipeline = new BlurPipeline gl, self.host.isGL2, self.quad, self.programs, (if self.host.isGL2 then shaders3 else shaders100)
		let caps = detectCapabilities!
		self.blurPipeline.configure caps.hasFloatBuffers, caps.hasHalfFloatBuffers
		self.capture = new BackdropCapture gl
		self.probe = new LuminanceProbe gl, self.env
		if self.host.isGL2
			self.glassUbo = gl.createBuffer!
			gl.bindBuffer gl.UNIFORM_BUFFER, self.glassUbo
			gl.bufferData gl.UNIFORM_BUFFER, MAX_SHAPES * FLOATS_PER_SHAPE * 4, gl.DYNAMIC_DRAW
			gl.bindBufferBase gl.UNIFORM_BUFFER, 0, self.glassUbo
			self.polyUbo = gl.createBuffer!
			gl.bindBuffer gl.UNIFORM_BUFFER, self.polyUbo
			gl.bufferData gl.UNIFORM_BUFFER, 8 * 6 * 4 * 4, gl.DYNAMIC_DRAW
			gl.bindBufferBase gl.UNIFORM_BUFFER, 1, self.polyUbo
			gl.bindBuffer gl.UNIFORM_BUFFER, null
		else
			buildES1Textures!
		observeResize!
		buildGraph!
		preferences.subscribe do(p)
			dirtyTracker.markAll!
		settings.subscribe do(s)
			dirtyTracker.markAll!
		bus.on 'gl:restored', do
			dirtyTracker.markAll!
			scheduler.requestRender!
		scheduler.onRender do(dt) self.render(dt)
		scheduler.start!
		yes

	def buildES1Textures
		if self.host == null or self.host.isGL2 or self.host.gl == null
			return
		let gl = self.host.gl
		let floatOk = globalThis.__GK_FLOAT_TEXTURES__ !== no
		let type = floatOk ? gl.FLOAT : gl.UNSIGNED_BYTE
		self.shapeTexture = new Texture gl,
			width: 12
			height: 64
			internalFormat: gl.RGBA
			format: gl.RGBA
			type: type
			filter: 'nearest'
			wrap: 'clamp'
		self.polyTexture = new Texture gl,
			width: 6
			height: 8
			internalFormat: gl.RGBA
			format: gl.RGBA
			type: type
			filter: 'nearest'
			wrap: 'clamp'

	def observeResize
		unless isBrowser
			return
		let w = globalThis.window
		self.onResize = do
			if self.resizeTimer != null
				globalThis.clearTimeout self.resizeTimer
			self.resizeTimer = globalThis.setTimeout (do
				self.resizePending = yes
				dirtyTracker.markAll!
				scheduler.requestRender!
			), 80
		w.addEventListener 'resize', self.onResize
		if typeof globalThis.ResizeObserver != 'undefined'
			self.resizeObserver = new globalThis.ResizeObserver do(entries)
				self.onResize!
			self.resizeObserver.observe globalThis.document.documentElement

	def buildGraph
		self.graph.add "capture", do(gl, frame) self.doCapture(frame)
		self.graph.add "blur", (do(gl, frame) self.doBlur(frame)), {deps: ['capture']}
		self.graph.add "shadows", (do(gl, frame) self.doContainers(frame, 'shadow')), {deps: ['blur']}
		self.graph.add "glass", (do(gl, frame) self.doContainers(frame, 'glass')), {deps: ['shadows']}
		self.graph.add "highlights", (do(gl, frame) self.doContainers(frame, 'highlight')), {deps: ['glass']}
		self.graph.add "scroll-edge", (do(gl, frame) self.doScrollEdges(frame)), {deps: ['blur']}
		self.graph.add "background-extension", (do(gl, frame) self.doBackgroundExtensions(frame)), {deps: ['blur']}
		self.graph.add "luminance-probe", (do(gl, frame) self.doProbe(frame)), {deps: ['blur']}

	def applyQuality
		let q = scheduler.quality
		let overrideTier = settings.qualityOverride
		if overrideTier != null
			scheduler.setQuality overrideTier
		elif settings.qualityOverride == null
			scheduler.setQuality null
		self.env.chromScale = q.chromatic ? 1 : 0
		self.env.rimScale = q.rim ? 1 : 0
		self.env.specularScale = q.specular ? 1 : 0.2
		self.env.shadowEnabled = q.shadow
		q

	def resizeIfNeeded
		unless self.resizePending
			return
		self.resizePending = no
		let w = globalThis.window
		let q = applyQuality!
		let dprv = Math.min settings.maxDPR, envDpr!
		dprv = Math.max 1, dprv * q.dprScale
		self.dpr = dprv
		self.width = Math.max 2, Math.round(w.innerWidth * dprv)
		self.height = Math.max 2, Math.round(w.innerHeight * dprv)
		self.canvas.width = self.width
		self.canvas.height = self.height
		self.env.dpr = dprv
		self.env.viewportHeightCss = w.innerHeight
		self.capture.ensureSize self.width, self.height
		self.blurPipeline.ensureSize self.width, self.height

	def computeFlags
		let f = 0
		if preferences.reducedTransparency
			f |= 1
		if preferences.reducedMotion
			f |= 2
		if preferences.increaseContrast
			f |= 4
		f

	def doCapture frame
		if frame.backdropChanged
			self.capture.capture self.dpr
			self.env.captureTexture = self.capture.texture
			refreshStrips!

	def doBlur frame
		if frame.backdropChanged or self.blurDescriptorStale
			let radius = Math.max 8, registry.globalMaxBlurRadius * self.dpr
			let q = scheduler.quality
			let caps = detectCapabilities!
			self.env.blurDescriptor = self.blurPipeline.blur self.env.captureTexture, radius, q.blurScale, caps.performanceClass, settings.blurAlgorithm
			self.env.blurMaxLod = self.env.blurDescriptor.maxLod
			self.blurDescriptorStale = no

	def doContainers frame, stage
		let gl = self.host.gl
		let containers = registry.containerList
		for ci in [0 ... containers.length]
			let container = containers[ci]
			if container.shapeCount == 0
				continue
			if container.offScreen
				continue
			let segs = container.segments
			for seg in segs
				if seg.count <= 0
					continue
				let segSpacing = seg.spacing
				let chunks = Math.ceil(seg.count / MAX_SHAPES)
				for chunk in [0 ... chunks]
					let packed = container.packShapeData(self, seg.start + chunk * MAX_SHAPES, segSpacing)
					if packed <= 0
						continue
					uploadShapeData!
					if stage == 'shadow'
						if self.shadowPass.render(gl, self.env, container)
							self.drawCalls += 1
					elif stage == 'glass'
						if self.glassPass.render(gl, self.env, container)
							self.drawCalls += 1
					else
						if self.highlightPass.render(gl, self.env, container)
							self.drawCalls += 1

	def uploadShapeData
		let gl = self.host.gl
		if self.host.isGL2
			gl.bindBuffer gl.UNIFORM_BUFFER, self.glassUbo
			gl.bufferSubData gl.UNIFORM_BUFFER, 0, self.shapeData
			gl.bindBuffer gl.UNIFORM_BUFFER, self.polyUbo
			gl.bufferSubData gl.UNIFORM_BUFFER, 0, self.polyData
			gl.bindBuffer gl.UNIFORM_BUFFER, null
		else
			let floatOk = globalThis.__GK_FLOAT_TEXTURES__ !== no
			if floatOk
				self.shapeTexture.uploadData self.shapeData
				self.polyTexture.uploadData self.polyData
			else
				quantizeShapeData!
				self.shapeTexture.uploadData self.shapeBytes
				self.polyTexture.uploadData quantizePolyData()

	def quantizeShapeData
		let d = self.shapeData
		let b = self.shapeBytes
		for i in [0 ... d.length]
			let slot = i % 48
			let vec = Math.floor(slot / 4)
			let v = d[i]
			let q = 0
			if vec == 0
				q = Math.round(Math.max(0, Math.min(1, v / 8192)) * 255)
			elif vec == 1
				q = Math.round(Math.max(0, Math.min(1, v / 1024)) * 255)
			elif vec == 3
				let comp = slot % 4
				if comp == 0 or comp == 1
					q = Math.round(Math.max(0, Math.min(1, v / 128)) * 255)
				else
					q = Math.round(Math.max(0, Math.min(1, (v + 512) / 1024)) * 255)
			else
				q = Math.round(Math.max(0, Math.min(1, v * 0.5 + 0.5)) * 255)
			b[i] = q

	def quantizePolyData
		let b = self.polyBytesCache
		for i in [0 ... self.polyData.length]
			b[i] = Math.round(Math.max(0, Math.min(1, self.polyData[i] * 0.5 + 0.5)) * 255)
		b

	def doScrollEdges frame
		let gl = self.host.gl
		self.drawCalls += self.scrollEdgePass.render(gl, self.env, self.edgeEffects)

	def doBackgroundExtensions frame
		let gl = self.host.gl
		self.drawCalls += self.backgroundExtensionPass.render(gl, self.env, self.bgEffects)

	def doProbe frame
		unless frame.backdropChanged and self.frameCount % LUM_UPDATE_INTERVAL == 0
			return
		self.probe.run self.env, registry.containerList
		dirtyTracker.markAll!

	def refreshStrips
		for effect in self.bgEffects
			if effect.stripRectCss != null
				let tex = self.capture.captureStrip effect.stripRectCss, self.dpr, 128, 128
				if tex != null
					effect.stripTexture = tex

	def render dt
		if self.disposed or self.mode == 'css' or self.mode == 'headless'
			return
		resizeIfNeeded!
		applyQuality!
		self.timeAccum += dt
		self.env.width = self.width
		self.env.height = self.height
		self.env.time = self.timeAccum
		self.env.flags = computeFlags!
		self.shapeSnapshots.clear
		self.backdropSnapshots.clear
		let had = dirtyTracker.consumeSnapshot(self.shapeSnapshots, self.backdropSnapshots)
		let backdropChanged = had[0] or had[1] or self.backdropSnapshots.size > 0 or self.frameCount == 0 or videoSourcesActive!
		self.drawCalls = 0
		let gl = self.host.gl
		gl.bindFramebuffer gl.FRAMEBUFFER, null
		gl.viewport 0, 0, self.width, self.height
		if backdropChanged or self.frameCount == 0
			gl.clearColor 0, 0, 0, 0
			gl.clear gl.COLOR_BUFFER_BIT
		let frame =
			backdropChanged: backdropChanged or self.frameCount == 0
			settingsChanged: had[1]
		self.graph.run gl, frame
		if settings.debugMode and !self.describedOnce
			self.describedOnce = yes
			self.graph.describe frame
		self.frameCount += 1

	def videoSourcesActive
		let active = no
		if self.capture
			self.capture.sources.forEach do(src)
				if src.type == 'video' and src.element.paused == no
					active = yes
		active

	def registerContentSource id, type, element, rect
		if self.capture
			self.capture.registerSource id, type, element, rect
		id

	def unregisterContentSource id
		if self.capture
			self.capture.unregisterSource id

	def registerEdgeEffect effect
		self.edgeEffects.push effect
		effect

	def unregisterEdgeEffect effect
		let i = self.edgeEffects.indexOf effect
		if i >= 0
			self.edgeEffects.splice i, 1

	def registerBackgroundExtension effect
		self.bgEffects.push effect
		effect

	def unregisterBackgroundExtension effect
		let i = self.bgEffects.indexOf effect
		if i >= 0
			self.bgEffects.splice i, 1

	get stats
		{textures: textureStats!, framebuffers: framebufferStats!, programs: programStats!, drawCalls: self.drawCalls, mode: self.mode}

	def dispose
		if self.disposed
			return
		self.disposed = yes
		if isBrowser and self.resizeObserver
			self.resizeObserver.disconnect!
		if isBrowser and self.onResize
			globalThis.window.removeEventListener 'resize', self.onResize
		if self.css
			self.css.stop!
			self.css = null
		if self.programs
			self.programs.disposeAll!
		if self.blurPipeline
			self.blurPipeline.dispose!
		if self.capture
			self.capture.dispose!
		if self.iconPass
			self.iconPass.dispose!
		if self.probe
			self.probe.dispose!
		if self.shapeTexture
			self.shapeTexture.destroy!
			self.shapeTexture = null
		if self.polyTexture
			self.polyTexture.destroy!
			self.polyTexture = null
		if self.host and self.host.gl and self.glassUbo
			self.host.gl.deleteBuffer self.glassUbo
			self.glassUbo = null
		if self.host and self.host.gl and self.polyUbo
			self.host.gl.deleteBuffer self.polyUbo
			self.polyUbo = null
		if self.host
			self.host.dispose!
		if self.canvas and self.canvas.parentNode
			self.canvas.parentNode.removeChild self.canvas
		self.edgeEffects = []
		self.bgEffects = []
