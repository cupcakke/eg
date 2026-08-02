import {demoState} from '../index'
import {ProceduralBackdrop} from '../procedural'

const SCENES = [
	{id: 'mesh', title: 'Gradient mesh'}
	{id: 'caustics', title: 'Caustic light'}
	{id: 'particles', title: 'Particle field'}
	{id: 'noise', title: 'Static mosaic'}
	{id: 'solid', title: 'Flat'}
]

tag gk-demo-media-background
	prop scene = 'mesh'

	def switchScene id
		scene = id
		let bd = demoState.backdrop
		if bd != null
			bd.kind = id
			bd.seedParticles!
		imba.commit!

	def render
		<self>
			<gk-section header='Registered Content Sources' footer='Every scene below is painted procedurally into a canvas and registered as the backdrop source the glass samples — no images, no video assets'>
				<div .demo-block>
					<div .demo-scene-picker role='group' aria-label='Scene'>
						for s in SCENES
							<button key=s.id type='button' aria-pressed=(scene == s.id ? 'true' : 'false') @click=(do self.switchScene(s.id))> s.title
			<div .demo-grid-2>
				<gk-card glass=yes title='Floating panel' subtitle='Blur + refraction track the moving scene' interactive=yes>
					<span class='demo-note'> "The backdrop this surface samples animates behind it in real time."
				<gk-card glass=yes tint='#30d158' title='Tinted sampling' subtitle='OKLab tint preserves luminance'>
					<span class='demo-note'> "Chromatic dispersion follows the motion field; tint mix stays luminance-neutral."
			<gk-section header='Luminance Adaptation' footer='Switches between flat and vivid scenes to watch the dimming solver react'>
				<div .demo-block>
					<gk-slider value=50 min=0 max=100 label='Dimming probe (visual only)'> 
					<span .demo-note> "The luminance probe reads the blurred backdrop every few frames and adjusts the glass dimming so content contrast stays above target."
