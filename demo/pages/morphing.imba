import {applyGlassEffect, removeGlassEffect, glassEffectFor} from '../../src/material/glass-effect'
import {Glass} from '../../src/material/glass'
import {Shape} from '../../src/material/shape'
import {uid} from '../../src/core/id'

tag gk-demo-morphing
	prop unionOn = no
	prop morphed = no
	prop chipAX = 60
	prop chipAY = 200
	prop chipBX = 340
	prop chipBY = 220

	def mount
		self.handles = {}
		self.chipEls = {}
		self.drag = null
		globalThis.setTimeout (do self.grabChips!), 0

	def grabChips
		let a = self.querySelector '[data-chip="a"]'
		let b = self.querySelector '[data-chip="b"]'
		if a != null then applyChip a, 'a'
		if b != null then applyChip b, 'b'

	def unmount
		for own key, handle of self.handles
			if handle != null then handle.dispose!
		self.handles = {}

	def applyChip el, which
		unless el
			return
		self.chipEls[which] = el
		if self.handles[which] != null
			self.handles[which].dispose!
			self.handles[which] = null
		self.handles[which] = applyGlassEffect el, Glass.regular.interactive(yes).tint('#5ac8fa', 0.25), Shape.capsule(),
			namespace: 'demo-chips'
			unionId: (unionOn ? 'chip-union' : null)
			transition: 'materialize'

	def setUnion value
		unionOn = value
		for own which, el of self.chipEls
			applyChip el, which
		imba.commit!

	def beginDrag e, which
		e.preventDefault!
		let el = self.chipEls[which]
		let startX = e.clientX
		let startY = e.clientY
		let baseX = if which == 'a' then chipAX else chipBX
		let baseY = if which == 'a' then chipAY else chipBY
		let move = do(ev)
			let dx = ev.clientX - startX
			let dy = ev.clientY - startY
			if which == 'a'
				chipAX = baseX + dx
				chipAY = baseY + dy
			else
				chipBX = baseX + dx
				chipBY = baseY + dy
			el.style.left = "{which == 'a' ? chipAX : chipBX}px"
			el.style.top = "{which == 'a' ? chipAY : chipBY}px"
			imba.commit!
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def morphNow
		morphed = !morphed
		imba.commit!

	def render
		<self>
			<gk-section header='Glass Unions' footer='When on, both chips share one sampling origin inside the union spacing; drag them within ~two spacings to feel the material fuse'>
				<div .demo-morph-stage>
					<div .demo-chip data-chip='a' style="left:{chipAX}px; top:{chipAY}px" @pointerdown=(do(e) self.beginDrag(e, 'a'))> "Drag me"
					<div .demo-chip data-chip='b' style="left:{chipBX}px; top:{chipBY}px" @pointerdown=(do(e) self.beginDrag(e, 'b'))> "Drag me too"
				<div .demo-row style='margin-top:12px'>
					<gk-toggle checked=unionOn label='Shared glass union' @change=(do(e) self.setUnion(e.detail.checked))>
			<gk-section header='Matched Geometry' footer='One glass-id migrates between hosts; geometry springs carry the material — no crossfade'>
				<div .demo-morph-stage>
					if morphed
						<div .demo-morph-target>
							<gk-button label='I am the same glass' variant='filled' glassId='morph-hero' glassNamespace='demo-morph' @activate=morphNow>
					else
						<div .demo-chip style='left:24px; top:24px'>
							<gk-button label='Morph me' variant='tinted' tint='#bf5af2' glassId='morph-hero' glassNamespace='demo-morph' @activate=morphNow>
				<div .demo-row style='margin-top:12px'>
					<span .demo-note> "Tap the surface — the same glass-id reappears elsewhere within the removal window and the two materializations merge into one morph."
