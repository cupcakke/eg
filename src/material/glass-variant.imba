import {VARIANT_REGULAR, VARIANT_CLEAR, DEFAULT_BLUR_RADIUS, CLEAR_BLUR_RADIUS, CHROMATIC_REGULAR, CHROMATIC_CLEAR, DEFAULT_DIMMING, DEFAULT_EDGE_THICKNESS, DEFAULT_REFRACTION, DEFAULT_SPECULAR_INTENSITY, DEFAULT_SPECULAR_SHARPNESS} from '../core/constants'

export const VARIANT_DESCRIPTORS =
	regular:
		id: VARIANT_REGULAR
		name: 'regular'
		blurRadius: DEFAULT_BLUR_RADIUS
		chromaticAberration: CHROMATIC_REGULAR
		edgeThickness: DEFAULT_EDGE_THICKNESS
		refractionStrength: DEFAULT_REFRACTION
		specularIntensity: DEFAULT_SPECULAR_INTENSITY
		specularSharpness: DEFAULT_SPECULAR_SHARPNESS
		dimmingOpacity: 0
	clear:
		id: VARIANT_CLEAR
		name: 'clear'
		blurRadius: CLEAR_BLUR_RADIUS
		chromaticAberration: CHROMATIC_CLEAR
		edgeThickness: DEFAULT_EDGE_THICKNESS
		refractionStrength: DEFAULT_REFRACTION
		specularIntensity: DEFAULT_SPECULAR_INTENSITY * 1.1
		specularSharpness: DEFAULT_SPECULAR_SHARPNESS
		dimmingOpacity: DEFAULT_DIMMING

export def variantDescriptor name
	let d = VARIANT_DESCRIPTORS[name]
	if d == null
		VARIANT_DESCRIPTORS.regular
	else
		d

export def variantName id
	if id == VARIANT_CLEAR then 'clear' else 'regular'
