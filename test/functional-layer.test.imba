import {group, test, expect} from './harness'
import {registry} from '../src/material/glass-registry'
import '../src/material/glass-container'
import {logger} from '../src/core/logger'
import {Glass} from '../src/material/glass'
import {Shape} from '../src/material/shape'
import {fakeEl} from './mini-dom'

group 'functional layer diagnostics'

def silentWarn fn
	let c = globalThis.console
	let origWarn = c.warn
	c.warn = do(msg) null
	try
		fn!
	catch e
		c.warn = origWarn
		throw e
	c.warn = origWarn

def resetState
	registry.resetAll!
	logger.clearViolations!
	logger.seen.clear()

def contentChild
	let layer = fakeEl 'div'
	layer.setAttribute 'content-layer', ''
	let el = fakeEl 'div'
	layer.appendChild el
	[layer, el]

test 'glass inside the content layer is flagged' do
	resetState!
	let pair = contentChild!
	let entry = null
	silentWarn do
		entry = registry.register pair[1], Glass.regular, Shape.capsule(), {}
		registry.diagnose!
	expect(logger.seen.has("layer:{entry.id}")).toBeTruthy
	registry.resetAll!

test 'glass inside the functional layer passes clean' do
	resetState!
	let layer = fakeEl 'div'
	layer.setAttribute 'functional-layer', ''
	let el = fakeEl 'div'
	layer.appendChild el
	silentWarn do
		registry.register el, Glass.regular, Shape.capsule(), {}
		registry.diagnose!
	let flagged = no
	for key in Array.from(logger.seen)
		if String(key).indexOf('layer:') >= 0
			flagged = yes
	expect(flagged).toBeFalsy
	registry.resetAll!

test 'the innermost layer ancestor decides the verdict' do
	resetState!
	let outer = fakeEl 'div'
	outer.setAttribute 'functional-layer', ''
	let inner = fakeEl 'div'
	inner.setAttribute 'content-layer', ''
	outer.appendChild inner
	let el = fakeEl 'div'
	inner.appendChild el
	let entry = null
	silentWarn do
		entry = registry.register el, Glass.regular, Shape.capsule(), {}
		registry.diagnose!
	expect(logger.seen.has("layer:{entry.id}")).toBeTruthy
	registry.resetAll!

test 'transient knobs inside content are exempt' do
	resetState!
	let pair = contentChild!
	pair[1].setAttribute 'data-gk-transient-knob', '1'
	silentWarn do
		registry.register pair[1], Glass.regular, Shape.capsule(), {}
		registry.diagnose!
	let flagged = no
	for key in Array.from(logger.seen)
		if String(key).indexOf('layer:') >= 0
			flagged = yes
	expect(flagged).toBeFalsy
	registry.resetAll!

test 'loose shapes beyond the threshold become an audit violation' do
	resetState!
	let els = []
	silentWarn do
		for i in [0 ... 7]
			let el = fakeEl 'div', 10 + i * 130, 10, 120, 44
			registry.register el, Glass.regular, Shape.capsule(), {}
			els.push el
		registry.diagnose!
	let kinds = Array.from(logger.currentViolations).map do(v) v.kind
	expect(kinds.indexOf('too-many-loose') >= 0).toBeTruthy
	registry.resetAll!

test 'shapes within the threshold raise no violation' do
	resetState!
	silentWarn do
		for i in [0 ... 3]
			registry.register fakeEl('div', 10 + i * 130, 10, 120, 44), Glass.regular, Shape.capsule(), {}
		registry.diagnose!
	let kinds = Array.from(logger.currentViolations).map do(v) v.kind
	expect(kinds.indexOf('too-many-loose') >= 0).toBeFalsy
	registry.resetAll!

test 'crowded surfaces outside a blending group are reported once' do
	resetState!
	let parent = fakeEl 'div'
	registry.registerContainer parent, 0
	let a = fakeEl 'div', 10, 10, 100, 40
	let b = fakeEl 'div', 10, 54, 100, 40
	parent.appendChild a
	parent.appendChild b
	let ea = null
	let eb = null
	silentWarn do
		ea = registry.register a, Glass.regular, Shape.capsule(), {}
		eb = registry.register b, Glass.regular, Shape.capsule(), {}
		registry.diagnose!
		registry.diagnose!
	expect(logger.seen.has("crowd:{ea.id}:{eb.id}")).toBeTruthy
	registry.resetAll!

test 'containers beyond the threshold register a violation eagerly' do
	resetState!
	silentWarn do
		for i in [0 ... 4]
			registry.registerContainer fakeEl('div'), 12
	let kinds = Array.from(logger.currentViolations).map do(v) v.kind
	expect(kinds.indexOf('too-many-containers') >= 0).toBeTruthy
	registry.resetAll!

test 'audit lists every surface with a live contrast target' do
	resetState!
	silentWarn do
		registry.register fakeEl('div', 0, 0, 100, 40), Glass.regular, Shape.rect(12), {}
		registry.register fakeEl('div', 0, 60, 100, 40), Glass.clear, Shape.capsule(), {}
	let report = registry.audit!
	expect(report.counts.entries).toBe 2
	expect(report.surfaces.length).toBe 2
	expect(report.surfaces[0].variant).toBe 'regular'
	expect(report.surfaces[1].variant).toBe 'clear'
	expect(report.surfaces[0].target).toBeGreaterThan 1
	expect(Array.isArray(report.violations)).toBeTruthy
	registry.resetAll!
