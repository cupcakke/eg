import {Tint} from './tint'
import {variantDescriptor} from './glass-variant'

let g_clone_counter = 0

export class Glass
	prop variantName
	prop tintValue
	prop interactiveFlag

	def constructor variant = 'regular'
		self.variantName = variant
		self.tintValue = new Tint null, 0
		self.interactiveFlag = no
		self.identity = ++g_clone_counter

	def clone
		let g = new Glass self.variantName
		g.tintValue = new Tint self.tintValue.color.slice(0), self.tintValue.strength
		g.interactiveFlag = self.interactiveFlag
		g

	def tint color, strength = 1
		let g = clone!
		g.tintValue = new Tint color, strength
		g

	def interactive flag = yes
		let g = clone!
		g.interactiveFlag = if flag then yes else no
		g

	def variant name
		unless name == 'regular' or name == 'clear'
			throw new Error "GlassKit: unknown variant '{name}' — expected 'regular' or 'clear'"
		let g = clone!
		g.variantName = name
		g

	def resolve
		let d = variantDescriptor self.variantName
		{
			variantId: d.id
			blurRadius: d.blurRadius
			chromaticAberration: d.chromaticAberration
			edgeThickness: d.edgeThickness
			refractionStrength: d.refractionStrength
			specularIntensity: d.specularIntensity
			specularSharpness: d.specularSharpness
			dimmingOpacity: d.dimmingOpacity
			tint: self.tintValue.toRecord!
			tintStrength: self.tintValue.strength
			interactive: (self.interactiveFlag ? 1 : 0)
		}

Glass.regular = new Glass 'regular'
Glass.clear = new Glass 'clear'

export def resolveGlass value
	if value isa Glass
		return value.clone!
	if value == 'clear'
		return Glass.clear.clone!
	if value == 'regular'
		return Glass.regular.clone!
	Glass.regular.clone!
