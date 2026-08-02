import {group, test, expect} from './harness'
import {registry} from '../src/material/glass-registry'
import '../src/material/glass-container'
import {Glass} from '../src/material/glass'
import {Shape} from '../src/material/shape'
import {GlassTransition, TransitionSpec, TransitionDriver, resolveTransitionSpec, snapshotEntry} from '../src/material/glass-transition'
import {FIXED_TIMESTEP} from '../src/core/constants'
import {fakeEl} from './mini-dom'

group 'transitions'

def freshState
	{press: 0, hover: 0, pointerX: 0.5, pointerY: 0.5, jelly: 0, luminosityAdjust: 0, dimmingOpacity: 0, measuredContrast: 0, detail: 1, noProbe: no, transitionActive: no, transitionPhase: 1}

def freshEntry
	{state: freshState!, rectCss: null, container: null}

def driveToDone driver
	let guard = 0
	while driver.done == no and guard < 20000
		driver.step FIXED_TIMESTEP
		guard += 1
	guard

test 'spec strings resolve to canonical kinds' do
	expect(resolveTransitionSpec('matchedGeometry').kind).toBe 'matched'
	expect(resolveTransitionSpec('matched').kind).toBe 'matched'
	expect(resolveTransitionSpec('materialize').kind).toBe 'materialize'
	expect(resolveTransitionSpec('identity').kind).toBe 'identity'
	expect(resolveTransitionSpec('does-not-exist')).toBeNull
	expect(resolveTransitionSpec(GlassTransition.materialize).kind).toBe 'materialize'

test 'custom specs require a builder function' do
	expect(do GlassTransition.custom(42)).toThrow 'requires a function'
	let spec = GlassTransition.custom do(entry, phase) {opacity: 0.5}
	expect(spec.kind).toBe 'custom'
	expect(typeof spec.builder).toBe 'function'

test 'materialize scales in, fades in and relaxes blur early' do
	let entry = freshEntry!
	let driver = new TransitionDriver entry, GlassTransition.materialize, null
	entry.state.transitionPhase = 0
	let rec = {x: 10, y: 10, w: 100, h: 40, scale: 1, alphaScale: 1, blurRadius: 10, radii: [0, 0, 0, 0], tint: [0, 0, 0, 0]}
	driver.applyToRecord rec
	expect(rec.scale).toBeCloseTo 0.8, 1e-4
	expect(rec.alphaScale).toBeCloseTo 0, 1e-4
	expect(rec.blurRadius).toBeCloseTo 30, 1e-4
	driver.finish!

test 'matched geometry interpolates from the snapshot' do
	let entry = freshEntry!
	let from = {x: 5, y: 7, w: 50, h: 20, radii: [4, 4, 4, 4], tint: [0.1, 0.2, 0.3, 0.4]}
	let driver = new TransitionDriver entry, GlassTransition.matchedGeometry, from
	entry.state.transitionPhase = 0.5
	let rec = {x: 105, y: 107, w: 150, h: 60, scale: 1, alphaScale: 1, blurRadius: 10, radii: [8, 8, 8, 8], tint: [0.5, 0.6, 0.7, 0.8]}
	driver.applyToRecord rec
	expect(rec.x).toBeCloseTo 55, 1e-4
	expect(rec.y).toBeCloseTo 57, 1e-4
	expect(rec.w).toBeCloseTo 100, 1e-4
	expect(rec.h).toBeCloseTo 40, 1e-4
	expect(rec.radii[0]).toBeCloseTo 6, 1e-4
	expect(rec.tint[3]).toBeCloseTo 0.6, 1e-4
	driver.finish!

test 'custom builders patch the record per phase' do
	let entry = freshEntry!
	let spec = GlassTransition.custom do(e, phase)
		{opacity: 1 - phase, scale: 0.5, dx: 4, dy: 2, blurBoost: 6}
	let driver = new TransitionDriver entry, spec, null
	entry.state.transitionPhase = 0.25
	let rec = {x: 10, y: 10, w: 100, h: 40, scale: 1, alphaScale: 1, blurRadius: 10, radii: [0, 0, 0, 0], tint: [0, 0, 0, 0]}
	driver.applyToRecord rec
	expect(rec.alphaScale).toBeCloseTo 0.75, 1e-4
	expect(rec.scale).toBeCloseTo 0.5, 1e-4
	expect(rec.x).toBeCloseTo 14, 1e-4
	expect(rec.y).toBeCloseTo 12, 1e-4
	expect(rec.blurRadius).toBeCloseTo 16, 1e-4
	driver.finish!

test 'drivers settle through the spring and restore a clean end state' do
	let entry = freshEntry!
	let driver = new TransitionDriver entry, GlassTransition.materialize, null
	expect(entry.state.transitionActive).toBeTruthy
	driveToDone driver
	expect(driver.done).toBeTruthy
	expect(entry.state.transitionActive).toBeFalsy
	expect(entry.state.transitionPhase).toBe 1
	expect(driver.applyToRecord({x: 1, y: 1, w: 1, h: 1, scale: 1, alphaScale: 1, blurRadius: 1, radii: [0, 0, 0, 0], tint: [0, 0, 0, 0]}).scale).toBe 1

test 'registry pairs a matched removal with a reappearing glass id' do
	registry.resetAll!
	let parent = fakeEl 'div'
	registry.registerContainer parent, 12
	let a = fakeEl 'div', 10, 10, 100, 40
	parent.appendChild a
	let ea = registry.register a, Glass.regular, Shape.capsule(), {glassId: 'hero', namespace: 'morph', transition: 'matchedGeometry'}
	expect(ea.transitionDriver).toNot.toBeNull
	expect(ea.transitionDriver.from).toBeNull
	registry.unregister ea
	let b = fakeEl 'div', 220, 120, 160, 60
	parent.appendChild b
	let eb = registry.register b, Glass.regular, Shape.capsule(), {glassId: 'hero', namespace: 'morph', transition: 'matchedGeometry'}
	expect(eb.transitionDriver).toNot.toBeNull
	expect(eb.transitionDriver.from).toNot.toBeNull
	expect(eb.transitionDriver.from.x).toBeCloseTo 10, 1e-4
	expect(eb.transitionDriver.from.w).toBeCloseTo 100, 1e-4
	expect(eb.state.transitionActive).toBeTruthy
	registry.resetAll!

test 'identity transition never spawns a driver' do
	registry.resetAll!
	let el = fakeEl 'div', 10, 10, 100, 40
	let entry = registry.register el, Glass.regular, Shape.capsule(), {transition: 'identity'}
	expect(entry.transitionDriver).toBeNull
	registry.resetAll!

test 'unmatched ids materialize without a snapshot' do
	registry.resetAll!
	let el = fakeEl 'div', 10, 10, 100, 40
	let entry = registry.register el, Glass.regular, Shape.capsule(), {glassId: 'fresh', namespace: 'morph', transition: 'matchedGeometry'}
	expect(entry.transitionDriver.from).toBeNull
	registry.resetAll!

test 'snapshots capture rect, radii and tint of the leaving entry' do
	registry.resetAll!
	let parent = fakeEl 'div'
	let el = fakeEl 'div', 30, 44, 128, 56
	parent.appendChild el
	let cont = registry.registerContainer parent, 0
	let entry = registry.register el, Glass.regular.tint('#5ac8fa', 0.5), Shape.rect(14), {}
	let renderer = {shapeData: new Float32Array(64 * 48), polyData: new Float32Array(8 * 24), dpr: 2, width: 2000, height: 2000, env: {viewportHeightCss: 600}}
	cont.packShapeData renderer
	let snap = snapshotEntry entry
	expect(snap.x).toBe 30
	expect(snap.y).toBe 44
	expect(snap.w).toBe 128
	expect(snap.h).toBe 56
	expect(snap.radii[0]).toBe 14
	expect(snap.tint[3]).toBeGreaterThan 0.1
	registry.resetAll!
