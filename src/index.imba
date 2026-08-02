
import {Renderer} from './render/renderer'
import {settings} from './core/settings'
import {preferences} from './a11y/preferences'
import {registry} from './material/glass-registry'
import {scheduler} from './core/raf-scheduler'
import {dirtyTracker} from './core/dirty-tracker'
import {Glass, resolveGlass} from './material/glass'
import {Shape, ShapeDescriptor} from './material/shape'
import {GlassTransition, TransitionSpec} from './material/glass-transition'
import {applyGlassEffect, removeGlassEffect} from './material/glass-effect'
import {ScrollEdgeEffect, setEdgeRendererProvider} from './layout/safe-area-bar'
import {safeArea} from './layout/safe-area'
import {metrics, scaledMetric} from './layout/layout-metrics'
import {focusRing} from './a11y/focus-ring'
import {bus} from './core/event-bus'
import {logger} from './core/logger'
import {uid} from './core/id'
import {Rect} from './core/geometry'
import {isBrowser} from './core/env'
import {BG_EXTENSION_WIDTH} from './core/constants'

import './material/glass-container'
import './layout/scroll-view'
import './layout/safe-area-bar'
import './layout/split-view'
import './layout/inspector'
import './layout/window-frame'

import './components/icon'
import './components/button-styles'
import './components/button'
import './components/toggle'
import './components/slider'
import './components/stepper'
import './components/segmented-control'
import './components/picker'
import './components/text-field'
import './components/search-field'
import './components/progress'
import './components/tab-item'
import './components/tab-bar'
import './components/sidebar'
import './components/toolbar-item'
import './components/toolbar-spacer'
import './components/toolbar-group'
import './components/toolbar'
import './components/menu-item'
import './components/menu'
import './components/context-menu'
import './components/popover'
import './components/sheet'
import './components/action-sheet'
import './components/alert'
import './components/list-row'
import './components/section'
import './components/list'
import './components/form'
import './components/card'
import './components/badge'
import './components/tooltip'
import './components/app-icon'

const bgExtensionRegistry = []

def syncExtensionDescriptor desc
	let el = desc.element
	unless el and el.getBoundingClientRect
		return
	let renderer = GlassKit.renderer
	let dpr = renderer != null ? renderer.dpr : 1
	let vpH = if renderer != null then renderer.env.viewportHeightCss else (if isBrowser then globalThis.window.innerHeight else 600)
	let r = el.getBoundingClientRect!
	let band = BG_EXTENSION_WIDTH
	if desc.edge == 'leading'
		desc.stripRectCss.set r.left, r.top, Math.min(band, r.width), r.height
		desc.bandRectGL.set (r.left - band) * dpr, (vpH - r.top - r.height) * dpr, band * dpr, r.height * dpr
		desc.seamPxGL = r.left * dpr
	elif desc.edge == 'trailing'
		desc.stripRectCss.set r.right - Math.min(band, r.width), r.top, Math.min(band, r.width), r.height
		desc.bandRectGL.set r.right * dpr, (vpH - r.top - r.height) * dpr, band * dpr, r.height * dpr
		desc.seamPxGL = r.right * dpr
	elif desc.edge == 'top'
		desc.stripRectCss.set r.left, r.top, r.width, Math.min(band, r.height)
		desc.bandRectGL.set r.left * dpr, (vpH - r.top) * dpr, r.width * dpr, band * dpr
		desc.seamPxGL = (vpH - r.top) * dpr
	else
		desc.stripRectCss.set r.left, r.bottom - Math.min(band, r.height), r.width, Math.min(band, r.height)
		desc.bandRectGL.set r.left * dpr, (vpH - r.bottom - band) * dpr, r.width * dpr, band * dpr
		desc.seamPxGL = (vpH - r.bottom) * dpr
	desc.bandSizeGL = band * dpr

def applyBackgroundExtension element, edges = ['leading']
	unless isBrowser and element
		throw new Error 'GlassKit: BackgroundExtension.apply(element, edges) requires a mounted element'
	let list = Array.isArray(edges) ? edges : [edges]
	let made = []
	for edge in list
		let axis = (edge == 'top' or edge == 'bottom') ? 'y' : 'x'
		let desc =
			id: uid('gkbx')
			element: element
			edge: edge
			axis: axis
			strength: 1
			stripTexture: null
			stripRectCss: new Rect
			bandRectGL: new Rect
			stripUv: [0, 0, 1, 1]
			seamPxGL: 0
			bandSizeGL: BG_EXTENSION_WIDTH
		let renderer = GlassKit.renderer
		if renderer != null
			renderer.registerBackgroundExtension desc
			syncExtensionDescriptor desc
		made.push desc
		bgExtensionRegistry.push desc
	{
		descriptors: made
		dispose: do
			for desc in made
				let renderer = GlassKit.renderer
				if renderer != null
					renderer.unregisterBackgroundExtension desc
				let i = bgExtensionRegistry.indexOf desc
				if i >= 0
					bgExtensionRegistry.splice i, 1
	}

def updateAllExtensions
	for desc in bgExtensionRegistry
		syncExtensionDescriptor desc

def syncThemeTokens
	unless isBrowser
		return
	let root = globalThis.document.documentElement
	if preferences.forcedColors
		root.setAttribute 'data-gk-forced-colors', '1'
	else
		root.removeAttribute 'data-gk-forced-colors'
	root.style.setProperty '--gk-focus-width', "{focusRing.ringWidth}px"

export const BackgroundExtension =
	apply: applyBackgroundExtension
	update: updateAllExtensions

def glassKitApi
	GlassKit

class GlassKitAPI
	prop renderer
	prop mounted

	def constructor
		self.renderer = null
		self.mounted = no
		self.versionValue = '1.0.0'
		self.boundResize = do updateAllExtensions!

	get version
		self.versionValue

	get settings
		settings

	get preferences
		preferences

	get safeArea
		safeArea

	get metrics
		metrics

	get Glass
		Glass

	get Shape
		Shape

	get GlassTransition
		GlassTransition

	get ScrollEdgeEffect
		ScrollEdgeEffect

	get BackgroundExtension
		BackgroundExtension

	def mount root = null, options = {}
		if self.mounted
			throw new Error 'GlassKit: GlassKit.mount() was called while already mounted — call GlassKit.unmount() first'
		self.mounted = yes
		if options.maxDPR != undefined then settings.maxDPR = options.maxDPR
		if options.debug != undefined then settings.debugMode = options.debug
		if options.glassAppearance != undefined then settings.setGlassAppearance options.glassAppearance
		if options.windowCornerRadius != undefined then settings.windowCornerRadius = options.windowCornerRadius
		unless isBrowser
			return no
		let hostEl = root
		if hostEl == null
			hostEl = globalThis.document.body
		let renderer = new Renderer hostEl, options
		self.renderer = renderer
		setEdgeRendererProvider do
			glassKitApi!.renderer
		registry.attach!
		renderer.init!
		focusRing.attach!
		preferences.subscribe do(p)
			syncThemeTokens!
		settings.subscribe do(s)
			dirtyTracker.markAll!
			updateAllExtensions!
		syncThemeTokens!
		globalThis.window.addEventListener 'resize', self.boundResize
		yes

	def unmount
		unless self.mounted
			return no
		self.mounted = no
		if isBrowser
			globalThis.window.removeEventListener 'resize', self.boundResize
		if self.renderer != null
			self.renderer.dispose!
			self.renderer = null
		for desc in bgExtensionRegistry.splice(0, bgExtensionRegistry.length)
			desc.element = null
		registry.resetAll!
		safeArea.reset!
		setEdgeRendererProvider null
		yes

	def effect el, glass = null, shape = null, opts = {}
		applyGlassEffect el, glass, shape, opts

	def removeEffect el
		removeGlassEffect el

	def audit
		registry.audit!

	get quality
		scheduler.quality.tier

	set quality tier
		settings.setQualityOverride tier

export const GlassKit = new GlassKitAPI

export def mount root, options
	GlassKit.mount root, options

export def unmount
	GlassKit.unmount!

export default GlassKit
