import {GlassKit} from '../../src/index'
import {logger} from '../../src/core/logger'

tag gk-demo-overview
	prop auditResult = null
	prop statsTick = 0

	def mount
		self.timer = globalThis.setInterval (do refreshStats!), 1000

	def unmount
		globalThis.clearInterval self.timer

	def refreshStats
		statsTick = statsTick + 1
		imba.commit!

	def rendererStats
		let r = GlassKit.renderer
		if r == null then return null
		r.stats

	def runAudit
		let result = GlassKit.audit!
		auditResult = "#{result.surfaces.length} glass surfaces audited, {result.violations.length} violation(s)"
		for v in result.violations
			logger.warn "audit: [{v.kind}] {v.message}"
		imba.commit!

	def clearLog
		logger.clearViolations!
		auditResult = 'Violation log cleared'
		imba.commit!

	def render
		let stats = rendererStats!
		<self>
			<section .demo-hero>
				<h1> "GlassKit"
				<p> "A dynamic glass material system with a physical refraction model, spring-driven motion, and a disciplined layer architecture — rendered through WebGL2 with automatic WebGL1 and CSS fallbacks."
			<div .demo-row>
				if stats != null
					<div .demo-stat>
						<b> stats.mode
						<span> "render mode"
					<div .demo-stat>
						<b> stats.drawCalls
						<span> "draw calls / frame"
					<div .demo-stat>
						<b> stats.textures.alive
						<span> "live textures"
					<div .demo-stat>
						<b> stats.programs.alive
						<span> "cached programs"
					<div .demo-stat>
						<b> "T{GlassKit.quality}"
						<span> "quality tier"
			<div .demo-row>
				<gk-button label='Run glass audit' variant='filled' @activate=runAudit>
				<gk-button label='Clear violation log' variant='bordered' @activate=clearLog>
				if auditResult != null
					<span .demo-note aria-live='polite'> auditResult
			<div .demo-grid>
				<gk-section header='Material Model'>
					<gk-card title='Physical Glass' subtitle='Lens refraction, chromatic aberration, rim light'>
						<span> "Every surface bends real backdrop content with SDF-exact edges and LOD-matched blur."
				<gk-section header='Motion'>
					<gk-card title='Springs Everywhere' subtitle='Analytic, velocity-preserving handoffs'>
						<span> "No timers, no keyframe libraries — retargetable springs drive press, drag, morph, and dismissal."
				<gk-section header='Architecture'>
					<gk-card title='Layer Discipline' subtitle='Functional vs content layers, dirty-tracked'>
						<span> "Zero work at idle; shape data uploads in 12×vec4 blocks with overflow chunking beyond 64 shapes."
			<div .demo-block>
				<h2> "Five-minute tour"
				<p .demo-note> "Navigate with the list on the left: controls, navigation patterns, morphing unions, sheets and menus, live background sources, the layered app-icon builder, accessibility tuning, and the performance harness."
				<div .demo-code> "import GlassKit from 'glasskit'\nimport 'glasskit/css'\n\nGlassKit.mount(document.body)\n\n<gk-button label='Order' variant='filled'>\n<div glass-effect=Glass.regular.interactive() glass-id='hero-bubble'>"
