const SPARK_PATH = 'M12 2.6c.8 4.6 3 7.8 5.2 9 1.9 1 4.6 1.5 6.2 1.9-1.6.4-4.3.9-6.2 1.9-2.2 1.2-4.4 4.4-5.2 9-.8-4.6-3-7.8-5.2-9-1.9-1-4.6-1.5-6.2-1.9 1.6-.4 4.3-.9 6.2-1.9 2.2-1.2 4.4-4.4 5.2-9Z'
const ORBIT_PATH = 'M12 4.8a7.2 7.2 0 1 1 0 14.4 7.2 7.2 0 0 1 0-14.4Z'
const DOT_PATH = 'M12 10.2a1.8 1.8 0 1 1 0 3.6 1.8 1.8 0 0 1 0-3.6Z'

tag gk-demo-icons
	prop platform = 'superellipse'
	prop previews = no
	prop blur = 0
	prop specular = 0.8
	prop refraction = 0.45
	prop innerShadow = 2.5
	prop opacity = 0.92
	prop bgIndex = 0
	prop layers = null

	def mount
		rebuildLayers!

	def backgrounds
		[
			{color: '#0a84ff', colorTo: '#0055d4'}
			{color: '#bf5af2', colorTo: '#5e2be0'}
			{color: '#30d158', colorTo: '#0e8a4c'}
			{color: '#ff9f0a', colorTo: '#d1495b'}
		]

	def backgroundValue
		backgrounds![bgIndex % backgrounds!.length]

	def rebuildLayers
		let boost = platform == 'circle' ? 5.6 : 5.1
		layers = [
			{path: ORBIT_PATH, tint: [1, 1, 1, 0.16], opacity: 0.5, scale: boost, refraction: refraction + 0.25, specular: 0.25}
			{path: SPARK_PATH, tint: '#ffffff', opacity: opacity, scale: boost * 0.62, blur: blur, specular: specular, refraction: refraction, innerShadow: innerShadow, offset: [0, -2]}
			{path: DOT_PATH, tint: '#ffffff', opacity: 0.95, scale: boost * 0.62, specular: specular * 0.8, offset: [0, 34]}
		]
		imba.commit!

	def platformChanged e
		platform = e.detail.index == 1 ? 'circle' : 'superellipse'
		rebuildLayers!

	def setParam key, v
		if key == 'blur' then blur = v
		elif key == 'specular' then specular = v
		elif key == 'refraction' then refraction = v
		elif key == 'innerShadow' then innerShadow = v
		elif key == 'opacity' then opacity = v
		rebuildLayers!

	def onSlider key
		do(e) self.setParam(key, e.detail.value)

	def render
		<self>
			<gk-section header='Layered Icon Builder' footer='Two to four layers over a background — each layer carries its own blur, specular, refraction, and inner-shadow response'>
				<div .demo-icon-lab>
					<gk-app-icon size=176 platform=platform layers=layers background=backgroundValue! previews=previews label='Studio app'>
					<div .demo-col>
						<gk-segmented-control items=['superellipse', 'circle'] selected=(platform == 'circle' ? 1 : 0) label='Platform shape' @change=(do self.platformChanged(e))>
						<gk-picker kind='menu' items=['Blue', 'Violet', 'Green', 'Ember'] selected=bgIndex label='Background' @change=(do(e) bgIndex = e.detail.index)>
						<gk-slider value=(blur) min=0 max=8 label='Symbol blur' @change=onSlider('blur')>
						<gk-slider value=(specular) min=0 max=1 step=0.05 label='Specular' @change=onSlider('specular')>
						<gk-slider value=(refraction) min=0 max=1 step=0.05 label='Refraction' @change=onSlider('refraction')>
						<gk-slider value=(innerShadow) min=0 max=8 label='Inner shadow depth' @change=onSlider('innerShadow')>
						<gk-toggle checked=previews label='Show all six environment previews' @change=(do(e) previews = e.detail.checked)>
			<gk-section header='How Layers Composite'>
				<div .demo-block>
					<div .demo-col>
						<gk-list-row title='1 · Background gradient' subtitle='Clipped by the platform silhouette' leading='paintbrush'>
						<gk-list-row title='2 · Orbit ring' subtitle='High refraction — the backdrop bends through it' leading='circle'>
						<gk-list-row title='3 · Spark glyph' subtitle='Specular lobe + inner shadow per layer' leading='star'>
						<gk-list-row title='4 · Grounding dot' subtitle='Offset toward the bottom rim' leading='plus'>
