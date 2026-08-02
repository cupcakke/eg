import {Rect} from '../core/geometry'
import {uid} from '../core/id'
import {dirtyTracker} from '../core/dirty-tracker'
import {settings} from '../core/settings'
import {preferences} from '../a11y/preferences'
import {registry, attachContainerFactory} from './glass-registry'
import {concentricRadius, inheritContainerRadius, computeInset} from './concentric'
import {DEFAULT_BEVEL_EXPONENT, MAX_SHAPES, FLOATS_PER_SHAPE, SHAPE_POLYGON, VARIANT_CLEAR, VARIANT_REGULAR} from '../core/constants'
import {logger} from '../core/logger'

let containerSeq = 0

const DEFAULT_SHADOW =
	regular: {opacity: 0.24, radius: 22, offsetX: 0, offsetY: 12}
	clear: {opacity: 0.18, radius: 16, offsetX: 0, offsetY: 8}

export class GlassContainerModel
	prop id
	prop element
	prop spacing

	def constructor el, spacing = 0
		self.id = uid 'gkc'
		self.element = el
		self.spacing = spacing or 0
		self.entries = []
		self.seq = ++containerSeq
		self.clipRectGL = new Rect
		self.focusedIndex = -1
		self.focusRingWidth = 3
		self.maxBlurRadius = 0
		self.allClear = no
		self.hasShadow = no
		self.anyInteractive = no
		self.chunkCount = 0
		self.offScreen = no
		self.structureCache = -1
		self.segmentList = [{start: 0, count: 0, spacing: 0}]
		self.dirty = yes
		self.tempRect = new Rect
		self.vpHCache = 600

	def addEntry entry
		if self.entries.indexOf(entry) < 0
			self.entries.push entry
			self.entries.sort do(a, b) a.seq - b.seq
			markDirty!

	def removeEntry entry
		let i = self.entries.indexOf entry
		if i >= 0
			self.entries.splice i, 1
			markDirty!

	def markDirty
		self.dirty = yes
		self.structureCache = -1

	def measureAll
		for entry in self.entries
			registry.measureEntry entry

	get entryCount
		self.entries.length

	def entryAt i
		self.entries[i] or null

	get shapeCount
		self.entries.length

	get segments
		if self.structureCache != registry.structureVersion
			self.structureCache = registry.structureVersion
			computeSegments!
		self.segmentList

	def computeSegments
		let out = []
		let i = 0
		let n = self.entries.length
		while i < n
			let entry = self.entries[i]
			if entry.unionId != null
				let key = "{entry.unionId}::{entry.namespace}"
				let group = registry.unions.groupFor entry.unionId, entry.namespace
				let j = i
				while j < n and self.entries[j].unionId != null and "{self.entries[j].unionId}::{self.entries[j].namespace}" == key
					j += 1
				let spacingForGroup = group.computeSpacing Math.max(self.spacing, 24)
				out.push {start: i, count: j - i, spacing: spacingForGroup}
				i = j
			else
				let j = i
				while j < n and self.entries[j].unionId == null
					j += 1
				out.push {start: i, count: j - i, spacing: self.spacing}
				i = j
		if out.length == 0
			out.push {start: 0, count: 0, spacing: self.spacing}
		self.segmentList = out

	def resolveEffective entry
		let p = entry.resolvedGlass!
		let appearance = settings.glassAppearance
		if entry.element.__gkAppearanceLocked == yes
			appearance = 'auto'
		if appearance == 'clear' and p.variantId == VARIANT_REGULAR
			let converted = Object.assign({}, p)
			converted.variantId = VARIANT_CLEAR
			converted.blurRadius = 8
			converted.chromaticAberration = 0.55
			return converted
		if appearance == 'tinted' and p.tint[3] <= 0
			let tinted = Object.assign({}, p)
			tinted.tint = [0.55, 0.62, 0.78, 0.35]
			tinted.tintStrength = 0.35
			return tinted
		if appearance == 'solid' and p.variantId == VARIANT_CLEAR
			let solid = Object.assign({}, p)
			solid.variantId = VARIANT_REGULAR
			return solid
		p

	def packShapeData renderer, chunkStart = 0, spacingOverride = null
		let out = renderer.shapeData
		let polys = renderer.polyData
		let dpr = renderer.dpr
		let vpH = renderer.env.viewportHeightCss
		self.vpHCache = vpH
		let avail = self.entries.length - chunkStart
		let n = Math.min Math.max(0, avail), MAX_SHAPES
		self.chunkCount = n
		let clip = self.clipRectGL
		clip.set 1e9, 1e9, -1e9, -1e9
		let maxBlur = 0
		let allC = yes
		let shadow = no
		let anyInt = no
		let focusIdx = -1
		let polySlotRef = {value: 0}
		for i in [0 ... n]
			let entry = self.entries[chunkStart + i]
			let rec = buildEntryRecord entry, renderer, vpH, dpr
			if entry.transitionDriver != null and entry.transitionDriver.done == no
				entry.transitionDriver.applyToRecord rec
			if rec.scale != 1
				let cx = rec.x + rec.w / 2
				let cy = rec.y + rec.h / 2
				rec.w *= rec.scale
				rec.h *= rec.scale
				rec.x = cx - rec.w / 2
				rec.y = cy - rec.h / 2
			writeRecord out, i * FLOATS_PER_SHAPE, rec, dpr, polySlotRef, polys, entry
			lineUnion clip, rec, dpr
			if rec.blurRadius > maxBlur then maxBlur = rec.blurRadius
			if rec.variant == 0 then allC = no
			if rec.shadowOpacity > 0.004 then shadow = yes
			if rec.interactive > 0 then anyInt = yes
			if entry.focused then focusIdx = i
		self.maxBlurRadius = maxBlur
		self.allClear = allC and n > 0
		self.hasShadow = shadow
		self.anyInteractive = anyInt
		self.focusedIndex = focusIdx
		finalizeClip clip, renderer, (spacingOverride != null ? spacingOverride : self.spacing)
		self.offScreen = self.entries.length == 0 or allEntriesOffscreen!
		n

	def allEntriesOffscreen
		let any = no
		for entry in self.entries
			if entry.offScreen == no
				any = yes
		any == no and self.entries.length > 0

	def buildEntryRecord entry, renderer, vpH, dpr
		let p = resolveEffective entry
		let st = entry.state
		let cssRect = entry.rectCss
		let pressScale = 1
		let jelly = [1, 1, 0]
		if entry.interactive != null
			pressScale = entry.interactive.pressScale cssRect
			if preferences.reducedMotion == no
				jelly = entry.interactive.jellyOffset!
		let w = cssRect.w * pressScale * jelly[0]
		let h = cssRect.h * pressScale * jelly[1]
		let x = cssRect.centerX - w / 2
		let y = cssRect.centerY - h / 2
		let context =
			containerRadius: inheritContainerRadius entry.element
			inset: computeInset(cssRect, (entry.parentSurfaceRect or cssRect))
			ltr: preferences.dir != 'rtl'
		let radiiCss = entry.shape.resolveRadii {w: w, h: h}, context
		let jellyBoost = (Math.abs(jelly[0] - 1) + Math.abs(jelly[1] - 1)) * 24
		let radii = [radiiCss[0] + jellyBoost, radiiCss[1] + jellyBoost, radiiCss[2] + jellyBoost, radiiCss[3] + jellyBoost]
		let shadowDef = if p.variantId == VARIANT_CLEAR then DEFAULT_SHADOW.clear else DEFAULT_SHADOW.regular
		let shadowOver = entry.shadowOverride or null
		{
			x: x
			y: y
			w: w
			h: h
			type: entry.shape.type
			radii: radii
			tint: p.tint
			tintStrength: p.tintStrength
			variant: p.variantId
			interactive: p.interactive
			press: st.press
			hover: st.hover
			pointerX: st.pointerX
			pointerY: (1 - st.pointerY)
			refractionStrength: p.refractionStrength
			edgeThickness: p.edgeThickness
			chromaticAberration: p.chromaticAberration
			blurRadius: p.blurRadius
			specularIntensity: p.specularIntensity
			specularSharpness: p.specularSharpness
			luminosityAdjust: st.luminosityAdjust
			dimmingOpacity: (if p.variantId == VARIANT_CLEAR then st.dimmingOpacity else 0)
			shadowOpacity: shadowOver != null ? shadowOver.opacity : shadowDef.opacity
			shadowRadius: shadowOver != null ? shadowOver.radius : shadowDef.radius
			shadowOffsetX: shadowOver != null ? shadowOver.offsetX : shadowDef.offsetX
			shadowOffsetY: shadowOver != null ? shadowOver.offsetY : shadowDef.offsetY
			superN: entry.shape.superN
			polyPoints: entry.shape.polyPoints
			polyRadius: entry.shape.polyRadius
			bevelExponent: DEFAULT_BEVEL_EXPONENT
			alphaScale: 1
			scale: 1
			blurRadiusBoost: 0
		}

	def writeRecord out, o, rec, dpr, polySlotRef, polys, entry
		let glX = rec.x * dpr
		let glY = (self.vpHCache - rec.y - rec.h) * dpr
		out[o + 0] = glX
		out[o + 1] = glY
		out[o + 2] = rec.w * dpr
		out[o + 3] = rec.h * dpr
		out[o + 4] = rec.radii[0] * dpr
		out[o + 5] = rec.radii[1] * dpr
		out[o + 6] = rec.radii[2] * dpr
		out[o + 7] = rec.radii[3] * dpr
		out[o + 8] = rec.tint[0]
		out[o + 9] = rec.tint[1]
		out[o + 10] = rec.tint[2]
		out[o + 11] = rec.tint[3] * rec.alphaScale
		out[o + 12] = rec.shadowOpacity * rec.alphaScale
		out[o + 13] = rec.shadowRadius * dpr
		out[o + 14] = rec.shadowOffsetX * dpr
		out[o + 15] = -rec.shadowOffsetY * dpr
		out[o + 17] = rec.variant
		out[o + 18] = rec.tintStrength
		out[o + 19] = rec.interactive
		out[o + 20] = rec.press
		out[o + 21] = rec.hover
		out[o + 22] = rec.pointerX
		out[o + 23] = rec.pointerY
		out[o + 24] = rec.refractionStrength
		out[o + 25] = rec.edgeThickness
		out[o + 26] = rec.chromaticAberration
		out[o + 27] = (rec.blurRadius + rec.blurRadiusBoost) * dpr
		out[o + 28] = rec.specularIntensity
		out[o + 29] = rec.specularSharpness
		out[o + 30] = rec.luminosityAdjust
		out[o + 31] = rec.dimmingOpacity
		let slot = -1
		let polyCount = 0
		if rec.type == SHAPE_POLYGON and rec.polyPoints != null
			polyCount = Math.min 12, Math.floor(rec.polyPoints.length / 2)
			if polySlotRef.value < 8
				slot = polySlotRef.value
				polySlotRef.value += 1
				let base = slot * 24
				for k in [0 ... 24]
					polys[base + k] = 0
				for k in [0 ... polyCount]
					let px = rec.polyPoints[k * 2]
					let py = rec.polyPoints[k * 2 + 1]
					let vecIdx = base + Math.floor(k / 2) * 4
					let comp = (k % 2) * 2
					polys[vecIdx + comp] = px
					polys[vecIdx + comp + 1] = py
			else
				rec.type = 1
				logger.warnOnce 'poly-overflow', 'More than 8 polygon shapes share a draw chunk — excess polygons render as rounded rectangles in this chunk.'
		out[o + 16] = rec.type
		out[o + 32] = (slot < 0 ? 0 : slot)
		out[o + 33] = rec.superN
		out[o + 34] = polyCount
		out[o + 35] = rec.bevelExponent
		out[o + 36] = rec.alphaScale
		out[o + 37] = 0
		out[o + 38] = 0
		out[o + 39] = 0
		for pad in [40 ... 48]
			out[o + pad] = 0
		entry.lastRadii = [rec.radii[0], rec.radii[1], rec.radii[2], rec.radii[3]]
		entry.lastTint = [rec.tint[0], rec.tint[1], rec.tint[2], rec.tint[3]]

	def lineUnion clip, rec, dpr
		let x1 = rec.x * dpr
		let y1 = (self.vpHCache - rec.y - rec.h) * dpr
		let x2 = x1 + rec.w * dpr
		let y2 = y1 + rec.h * dpr
		if x1 < clip.x then clip.x = x1
		if y1 < clip.y then clip.y = y1
		if x2 > clip.w then clip.w = x2
		if y2 > clip.h then clip.h = y2

	def finalizeClip clip, renderer, spacingBase
		let grow = Math.max(spacingBase, self.spacing) * renderer.dpr + 64
		let x1 = clip.x
		let y1 = clip.y
		let x2 = clip.w
		let y2 = clip.h
		let cx1 = Math.max 0, x1 - grow
		let cy1 = Math.max 0, y1 - grow
		let cx2 = Math.min renderer.width, x2 + grow
		let cy2 = Math.min renderer.height, y2 + grow
		if clip.w == -1e9 or cx2 <= cx1 or cy2 <= cy1
			clip.set 0, 0, 0, 0
			return
		clip.set cx1, cy1, cx2 - cx1, cy2 - cy1

attachContainerFactory
	root: do
		new GlassContainerModel null, 0
	forElement: do(el, spacing)
		let s = if typeof spacing == 'string' then Number(spacing) else (spacing or 0)
		new GlassContainerModel el, s

tag gk-glass-container
	prop spacing = 40 @watch

	def mount
		self.containerModel = registry.registerContainer self, Number(spacing) or 0

	def unmount
		registry.unregisterContainer self
		self.containerModel = null

	def spacingDidSet value
		if self.containerModel
			self.containerModel.spacing = Number(value) or 0
			self.containerModel.markDirty!
			dirtyTracker.markAll!

	get model
		self.containerModel

	<self>
		<slot>
