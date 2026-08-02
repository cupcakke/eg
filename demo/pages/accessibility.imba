import {GlassKit} from '../../src/index'

const OVERRIDE_KEYS = ['reducedMotion', 'reducedTransparency', 'increaseContrast', 'forcedColors', 'darkScheme']
const OVERRIDE_LABELS =
	reducedMotion: 'Reduce Motion — springs become 150 ms dissolves'
	reducedTransparency: 'Reduce Transparency — surfaces turn opaque'
	increaseContrast: 'Increase Contrast — dimming and borders strengthen'
	forcedColors: 'Forced Colors — system palette takes over'
	darkScheme: 'Dark Scheme — force the dark material theme'

tag gk-demo-accessibility
	prop appearance = 'auto'
	prop overrideState = null

	def mount
		self.overrideState = refreshState!
		appearance = GlassKit.settings.glassAppearance

	def refreshState
		let out = {}
		for key in OVERRIDE_KEYS
			out[key] = GlassKit.preferences[key] ? yes : no
		out

	def toggleOverride key
		do(e)
			let on = e.detail.checked
			GlassKit.preferences.setOverride key, on
			self.overrideState = refreshState!
			imba.commit!

	def setAppearance e
		let names = ['auto', 'tinted', 'clear', 'solid']
		appearance = names[e.detail.index] or 'auto'
		GlassKit.settings.setGlassAppearance appearance
		imba.commit!

	def appearanceIndex
		let names = ['auto', 'tinted', 'clear', 'solid']
		let i = names.indexOf appearance
		i < 0 ? 0 : i

	def directionChanged e
		GlassKit.preferences.setOverride 'dir', (e.detail.index == 1 ? 'rtl' : 'ltr')
		imba.commit!

	def clearOverrides
		for key in OVERRIDE_KEYS
			GlassKit.preferences.setOverride key, null
		self.overrideState = refreshState!
		imba.commit!

	def render
		<self>
			<gk-section header='Media Preferences' footer='Each toggle simulates the corresponding OS-level preference; the material reacts immediately'>
				<div .demo-block>
					<div .demo-col>
						for key in OVERRIDE_KEYS
							<gk-toggle key=key checked=self.overrideState[key] label=OVERRIDE_LABELS[key] @change=toggleOverride(key)>
					<div .demo-row style='margin-top:12px'>
						<gk-button label='Reset all to system values' variant='bordered' @activate=clearOverrides>
			<gk-section header='Glass Appearance' footer='Persisted per origin; clear and solid remain fully opaque'>
				<div .demo-block>
					<gk-segmented-control items=['Auto', 'Tinted', 'Clear', 'Solid'] selected=appearanceIndex! label='Appearance' @change=setAppearance>
			<gk-section header='On-Glass Contrast' footer='The probe solver holds text contrast above the target automatically'>
				<div .demo-block>
					<div .demo-row>
						<gk-card glass=yes title='Adaptive label' subtitle='Backdrop luminance steers --gk-on-glass'>
							<span class='demo-note'> "Drag cards over bright and dark regions of the scene to watch the label flip between the two reading colors."
						<gk-card glass=yes tint='#ffd60a' title='Tinted bright' subtitle='Measured contrast is reported by audit()'>
							<span class='demo-note'> "Run the audit from Overview to inspect contrast per surface."
			<gk-section header='Text Direction'>
				<div .demo-block>
					<div .demo-row>
						<gk-segmented-control items=['LTR', 'RTL'] selected=(GlassKit.preferences.dir == 'rtl' ? 1 : 0) label='Direction' @change=(do self.directionChanged(e))>
						<span .demo-note> "Arrow keys and progress animations mirror automatically."
