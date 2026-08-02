import {Glass} from '../material/glass'
import {Shape} from '../material/shape'

export const BUTTON_SIZES =
	mini: {height: 22, radius: 11, pad: 10, font: 12}
	small: {height: 26, radius: 13, pad: 12, font: 13}
	regular: {height: 35, radius: 18, pad: 16, font: 15}
	large: {height: 44, radius: 22, pad: 20, font: 16}
	extraLarge: {height: 54, radius: 27, pad: 26, font: 18}

export const BUTTON_STYLE_NAMES = ['plain', 'bordered', 'glass', 'glassProminent', 'glassClear', 'glassProminentClear']

export def buttonGlassFor styleName, accentTint = null
	switch styleName
		when 'glass'
			Glass.regular.clone!
		when 'glassProminent'
			Glass.regular.tint(accentTint or '#4a7de8', 0.62)
		when 'glassClear'
			Glass.clear.clone!
		when 'glassProminentClear'
			Glass.clear.tint(accentTint or '#4a7de8', 0.5)
		else
			null

export def buttonSizeFor sizeName
	let found = BUTTON_SIZES[sizeName]
	if found then found else BUTTON_SIZES.regular

export def buttonShapeFor styleName
	if styleName == 'bordered'
		Shape.rect(corners: {tl: 14, tr: 14, br: 14, bl: 14}, isUniform: yes)
	else
		Shape.capsule!

export def isGlassButtonStyle styleName
	styleName == 'glass' or styleName == 'glassProminent' or styleName == 'glassClear' or styleName == 'glassProminentClear'
