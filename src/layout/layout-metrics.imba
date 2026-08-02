import {MIN_HIT_TARGET} from '../core/constants'
import {EventBus} from '../core/event-bus'

const TYPE_SIZE_ORDER = ['xSmall', 'small', 'medium', 'large', 'xLarge', 'xxLarge', 'xxxLarge', 'accessibility1', 'accessibility2', 'accessibility3', 'accessibility4', 'accessibility5']

const TYPE_TABLE =
	body: [12, 13, 14, 17, 19, 21, 23, 26, 30, 34, 38, 43]
	headline: [13, 14, 15, 17, 19, 22, 24, 28, 33, 38, 43, 48]
	subheadline: [11, 12, 13, 15, 17, 19, 21, 24, 28, 32, 36, 40]
	title1: [22, 24, 26, 28, 31, 34, 38, 43, 48, 53, 58, 64]
	title2: [17, 19, 20, 22, 24, 26, 28, 32, 37, 42, 47, 52]
	title3: [15, 17, 18, 20, 22, 24, 26, 29, 33, 37, 41, 45]
	footnote: [11, 12, 12, 13, 14, 15, 16, 18, 21, 24, 27, 30]
	caption1: [10, 11, 11, 12, 13, 14, 15, 17, 20, 23, 26, 28]
	caption2: [10, 10, 11, 12, 13, 14, 15, 16, 19, 22, 25, 27]

const HEIGHT_TABLE =
	mini: 20
	small: 24
	regular: 28
	large: 34
	extraLarge: 42

const HEIGHT_SCALE = [0.82, 0.88, 0.94, 1, 1.04, 1.09, 1.15, 1.24, 1.35, 1.46, 1.58, 1.7]

export class LayoutMetrics
	prop typeSize

	def constructor
		self.typeSize = 'large'
		self.events = new EventBus
		self.spacingBase = 4

	get typeSizeIndex
		let i = TYPE_SIZE_ORDER.indexOf self.typeSize
		if i < 0 then 3 else i

	def setTypeSize name
		if TYPE_SIZE_ORDER.indexOf(name) < 0
			throw new Error "GlassKit: unknown dynamic type size '{name}' — expected one of {TYPE_SIZE_ORDER.join(', ')}"
		if self.typeSize != name
			self.typeSize = name
			self.events.emit 'changed', self

	def typeSizeNameAt index
		TYPE_SIZE_ORDER[index]

	def fontSize style = 'body', sizeName = null
		let table = TYPE_TABLE[style] or TYPE_TABLE.body
		let idx = if sizeName == null then typeSizeIndex else TYPE_SIZE_ORDER.indexOf(sizeName)
		if idx < 0 then idx = 3
		table[idx]

	def fontScale style = 'body'
		fontSize(style) / TYPE_TABLE[style][3]

	def controlHeight size = 'regular', applyTypeScale = yes
		let base = HEIGHT_TABLE[size] or HEIGHT_TABLE.regular
		if applyTypeScale
			Math.round base * HEIGHT_SCALE[typeSizeIndex]
		else
			base

	get minHitTarget
		MIN_HIT_TARGET

	def spacing step = 2
		self.spacingBase * step

	def scaledMetric base, style = 'body'
		Math.round(base * fontScale(style) * 100) / 100

	def subscribe fn
		self.events.on 'changed', fn

export const metrics = new LayoutMetrics

export def scaledMetric base, style = 'body'
	metrics.scaledMetric base, style

export def controlHeightFor size = 'regular'
	metrics.controlHeight size
