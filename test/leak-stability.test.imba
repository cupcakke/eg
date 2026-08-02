import {group, test, expect} from './harness'
import {registry} from '../src/material/glass-registry'
import '../src/material/glass-container'
import {Glass} from '../src/material/glass'
import {Shape} from '../src/material/shape'
import {fakeEl} from './mini-dom'

group 'leak stability'

test 'one hundred register and unregister cycles leave zero entries' do
	registry.resetAll!
	for i in [0 ... 100]
		let el = fakeEl 'div', 10 + (i % 10) * 120, 10, 110, 44
		let entry = registry.register el, Glass.regular, Shape.capsule(), {namespace: "cycle-{i % 4}"}
		registry.unregister entry
	expect(registry.entries.length).toBe 0
	expect(registry.byElement.size).toBe 0
	expect(registry.entryCount).toBe 0

test 'interactive controllers detach every listener on unregister' do
	registry.resetAll!
	let el = fakeEl 'div', 10, 10, 110, 44
	let entry = registry.register el, Glass.regular.interactive(yes), Shape.capsule(), {}
	expect(entry.interactive).toNot.toBeNull
	expect(el.totalListeners!).toBeGreaterThanOrEqual 6
	registry.unregister entry
	expect(el.totalListeners!).toBe 0
	expect(registry.entries.length).toBe 0

test 'containers release their element mapping on unregister' do
	registry.resetAll!
	for i in [0 ... 20]
		let host = fakeEl 'div'
		let child = fakeEl 'div', 10, 10 + i * 50, 100, 40
		host.appendChild child
		registry.registerContainer host, 12
		registry.register child, Glass.regular, Shape.capsule(), {}
		registry.unregisterContainer host
		registry.unregister registry.entryForElement(child)
	expect(registry.containersByElement.size).toBe 0
	expect(registry.entries.length).toBe 0
	registry.resetAll!
	expect(registry.containers.length).toBe 0

test 'unions empty out when their last member leaves' do
	registry.resetAll!
	for i in [0 ... 30]
		let parent = fakeEl 'div'
		registry.registerContainer parent, 12
		let els = []
		for k in [0 ... 2]
			let el = fakeEl 'div', 10 + k * 130, 10, 120, 44
			parent.appendChild el
			els.push el
		let a = registry.register els[0], Glass.regular, Shape.capsule(), {unionId: 'pair', namespace: 'u'}
		let b = registry.register els[1], Glass.regular, Shape.capsule(), {unionId: 'pair', namespace: 'u'}
		expect(registry.unions.groupCount).toBe 1
		registry.unregister a
		registry.unregister b
		expect(registry.unions.groupCount).toBe 0
	expect(registry.entries.length).toBe 0

test 'recent removals are trimmed and bounded' do
	registry.resetAll!
	for i in [0 ... 50]
		let el = fakeEl 'div', 10, 10, 100, 40
		let e = registry.register el, Glass.regular, Shape.capsule(), {glassId: "id-{i}", namespace: 'n', transition: 'identity'}
		registry.unregister e
	expect(registry.recentRemovals.length).toBeLessThanOrEqual 60
	registry.resetAll!
	expect(registry.recentRemovals.length).toBe 0

test 'structure version rises monotonically through churn' do
	registry.resetAll!
	let v0 = registry.structureVersion
	for i in [0 ... 25]
		let el = fakeEl 'div', 10, 10, 100, 40
		let e = registry.register el, Glass.regular, Shape.capsule(), {}
		registry.unregister e
	expect(registry.structureVersion).toBeGreaterThan v0 + 40

test 're-registering the same element replaces rather than duplicates' do
	registry.resetAll!
	let el = fakeEl 'div', 10, 10, 100, 40
	let first = registry.register el, Glass.regular, Shape.capsule(), {}
	let again = registry.register el, Glass.clear, Shape.rect(8), {}
	expect(again == first).toBeTruthy
	expect(registry.entries.length).toBe 1
	expect(again.glass.variantName).toBe 'clear'
	registry.unregister first
	expect(registry.entries.length).toBe 0

test 'resetAll clears violations alongside every collection' do
	registry.resetAll!
	for i in [0 ... 6]
		let el = fakeEl 'div', 10 + i * 130, 10, 120, 44
		registry.register el, Glass.regular, Shape.capsule(), {}
	expect(registry.entries.length).toBe 6
	registry.resetAll!
	expect(registry.entries.length).toBe 0
	expect(registry.containers.length).toBe 0
	expect(registry.unions.groupCount).toBe 0
	expect(registry.audit!.surfaces.length).toBe 0
