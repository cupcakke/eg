import {parseColor, toHex} from '../core/color'
import {saturate} from '../core/math'

export class Tint
	prop color
	prop strength

	def constructor color = null, strength = 1
		self.color = if color == null then [0, 0, 0, 0] else parseColor(color)
		self.strength = saturate strength

	static def from value, strength = 1
		if value isa Tint
			return value
		new Tint value, strength

	get isEmpty
		self.color[3] <= 0 or self.strength <= 0

	def withStrength s
		new Tint self.color.slice(0), s

	def withColor c
		new Tint c, self.strength

	def toCss
		if self.color[3] <= 0
			return 'transparent'
		let r = Math.round self.color[0] * 255
		let g = Math.round self.color[1] * 255
		let b = Math.round self.color[2] * 255
		let a = Math.round(self.color[3] * self.strength * 1000) / 1000
		"rgba({r}, {g}, {b}, {a})"

	def toRecord
		[self.color[0], self.color[1], self.color[2], self.color[3]]

export def tintCss colorArray, strength = 1
	new Tint(colorArray, strength).toCss
