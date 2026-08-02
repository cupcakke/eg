import {storage} from './env'
import {EventBus} from './event-bus'
import {WARN_MAX_LOOSE_SHAPES, WARN_MAX_CONTAINERS, WARN_MIN_SURFACE_GAP, CONTRAST_TARGET, CONTRAST_TARGET_HIGH, MAX_DPR, STORAGE_APPEARANCE_KEY} from './constants'

const APPEARANCES = ['auto', 'tinted', 'clear', 'solid']

export class Settings
	prop maxDPR
	prop glassAppearance
	prop debugMode
	prop qualityOverride
	prop blurAlgorithm
	prop minContrast
	prop contrastHigh
	prop windowCornerRadius
	prop luminanceInterval
	prop luminanceTau

	def constructor
		self.maxDPR = MAX_DPR
		self.debugMode = no
		self.qualityOverride = null
		self.blurAlgorithm = 'auto'
		self.minContrast = CONTRAST_TARGET
		self.contrastHigh = CONTRAST_TARGET_HIGH
		self.windowCornerRadius = 12
		self.luminanceInterval = 4
		self.luminanceTau = 0.18
		self.warningThresholds =
			maxLooseShapes: WARN_MAX_LOOSE_SHAPES
			maxContainers: WARN_MAX_CONTAINERS
			minSurfaceGap: WARN_MIN_SURFACE_GAP
		self.events = new EventBus
		self.glassAppearance = 'auto'
		let stored = storage.getItem STORAGE_APPEARANCE_KEY
		if stored and APPEARANCES.indexOf(stored) >= 0
			self.glassAppearance = stored

	get thresholds
		self.warningThresholds

	get isProduction
		globalThis.__GK_PROD__ === true

	get devDiagnostics
		self.debugMode or !isProduction

	def setGlassAppearance value
		if APPEARANCES.indexOf(value) < 0
			throw new Error("GlassKit: unknown glassAppearance '{value}' — expected one of {APPEARANCES.join(', ')}")
		if self.glassAppearance != value
			self.glassAppearance = value
			storage.setItem STORAGE_APPEARANCE_KEY, value
			changed!

	def setQualityOverride tier
		self.qualityOverride = tier
		changed!

	def warnThreshold key, value
		if self.warningThresholds.hasOwnProperty(key)
			self.warningThresholds[key] = value
			changed!

	def subscribe fn
		self.events.on 'changed', fn

	def changed
		self.events.emit 'changed', self

export const settings = new Settings
