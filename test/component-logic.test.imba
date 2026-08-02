import {group, test, expect} from './harness'
import {setRole, setLabel, labelBy, setExpanded, setPressed, setChecked, setSelected, setDisabled, setCurrent, setValueNow} from '../src/a11y/aria'
import {RovingGroup, FocusTrap} from '../src/a11y/keyboard-nav'
import {concentricRadius, capsuleRadius, isCapsuleRadius} from '../src/material/concentric'
import {computeColumnWidths, collapseColumns} from '../src/layout/resize-controller'
import {preferences} from '../src/a11y/preferences'
import {FakeElement, fakeEl, fakeEvent} from './mini-dom'

group 'component logic'

def installDocumentStub
	let doc = new FakeElement 'document'
	doc.activeElement = null
	doc.created = []
	doc.createElement = do(tag)
		let el = new FakeElement tag
		doc.created.push el
		el
	doc.body = new FakeElement 'body'
	doc.documentElement = new FakeElement 'html'
	globalThis.document = doc
	doc

def toolbarContainer count = 4
	let cont = new FakeElement 'div'
	let items = []
	for i in [0 ... count]
		let el = new FakeElement 'button'
		el.setAttribute 'data-gk-item', ''
		el.tabIndex = -1
		cont.appendChild el
		items.push el
	[cont, items]

test 'aria helpers write the expected attributes' do
	let el = fakeEl 'button'
	setRole el, 'switch'
	setLabel el, 'Enable sync'
	setExpanded el, yes
	setPressed el, no
	setChecked el, yes
	setSelected el, yes
	setCurrent el, 'page'
	setDisabled el, yes
	setValueNow el, 42, 0, 100, '42 percent'
	labelBy el, 'lbl-1 lbl-2'
	expect(el.getAttribute('role')).toBe 'switch'
	expect(el.getAttribute('aria-label')).toBe 'Enable sync'
	expect(el.getAttribute('aria-expanded')).toBe 'true'
	expect(el.getAttribute('aria-pressed')).toBe 'false'
	expect(el.getAttribute('aria-checked')).toBe 'true'
	expect(el.getAttribute('aria-selected')).toBe 'true'
	expect(el.getAttribute('aria-current')).toBe 'page'
	expect(el.getAttribute('aria-disabled')).toBe 'true'
	expect(el.getAttribute('aria-valuenow')).toBe '42'
	expect(el.getAttribute('aria-valuemin')).toBe '0'
	expect(el.getAttribute('aria-valuemax')).toBe '100'
	expect(el.getAttribute('aria-valuetext')).toBe '42 percent'
	expect(el.getAttribute('aria-labelledby')).toBe 'lbl-1 lbl-2'

test 'roving tabindex moves with arrow keys and wraps' do
	installDocumentStub!
	let pair = toolbarContainer 3
	let group = new RovingGroup pair[0], '[data-gk-item]', {}
	group.attach!
	let items = pair[1]
	globalThis.document.activeElement = items[0]
	group.updateTabstops items[0]
	expect(items[0].tabIndex).toBe 0
	expect(items[1].tabIndex).toBe -1
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowRight'})
	expect(globalThis.document.activeElement == items[1] or items[1].focused).toBeTruthy
	expect(items[1].tabIndex).toBe 0
	expect(items[0].tabIndex).toBe -1
	globalThis.document.activeElement = items[2]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowRight'})
	expect(items[0].focused).toBeTruthy
	group.detach!

test 'roving home and end jump to the edges' do
	installDocumentStub!
	let pair = toolbarContainer 4
	let group = new RovingGroup pair[0], '[data-gk-item]', {}
	group.attach!
	globalThis.document.activeElement = pair[1][1]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'End'})
	expect(pair[1][3].focused).toBeTruthy
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'Home'})
	expect(pair[1][0].focused).toBeTruthy
	group.detach!

test 'vertical groups answer up and down only' do
	installDocumentStub!
	let pair = toolbarContainer 3
	let group = new RovingGroup pair[0], '[data-gk-item]', {orientation: 'vertical'}
	group.attach!
	globalThis.document.activeElement = pair[1][0]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowDown'})
	expect(pair[1][1].focused).toBeTruthy
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowRight'})
	expect(pair[1][2].focused).toBeFalsy
	globalThis.document.activeElement = pair[1][1]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowUp'})
	expect(pair[1][0].focused).toBeTruthy
	group.detach!

test 'rtl swaps the horizontal direction keys' do
	installDocumentStub!
	let pair = toolbarContainer 3
	let group = new RovingGroup pair[0], '[data-gk-item]', {}
	group.attach!
	preferences.dir = 'rtl'
	globalThis.document.activeElement = pair[1][0]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowLeft'})
	expect(pair[1][1].focused).toBeTruthy
	preferences.dir = 'ltr'
	group.detach!

test 'disabled items are skipped by keyboard navigation' do
	installDocumentStub!
	let pair = toolbarContainer 3
	pair[1][1].setAttribute 'aria-disabled', 'true'
	let group = new RovingGroup pair[0], '[data-gk-item]', {}
	group.attach!
	globalThis.document.activeElement = pair[1][0]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'ArrowRight'})
	expect(pair[1][2].focused).toBeTruthy
	expect(pair[1][1].focused).toBeFalsy
	group.detach!

test 'enter activates the focused item through the callback' do
	installDocumentStub!
	let pair = toolbarContainer 2
	let activated = null
	let group = new RovingGroup pair[0], '[data-gk-item]', {onActivate: do(el) activated = el}
	group.attach!
	globalThis.document.activeElement = pair[1][1]
	pair[0].dispatchEvent fakeEvent('keydown', {key: 'Enter'})
	expect(activated == pair[1][1]).toBeTruthy
	group.detach!

test 'focus trap keeps tab inside the dialog and escapes out' do
	installDocumentStub!
	let dialog = new FakeElement 'div'
	let first = new FakeElement 'button'
	let second = new FakeElement 'button'
	dialog.appendChild first
	dialog.appendChild second
	let escaped = no
	let trap = new FocusTrap dialog, {onEscape: do escaped = yes}
	trap.activate!
	expect(first.focused).toBeTruthy
	globalThis.document.activeElement = second
	trap.handleKey fakeEvent('keydown', {key: 'Tab'})
	expect(first.focused).toBeTruthy
	globalThis.document.activeElement = first
	trap.handleKey fakeEvent('keydown', {key: 'Tab', shiftKey: yes})
	expect(second.focused).toBeTruthy
	trap.handleKey fakeEvent('keydown', {key: 'Escape'})
	expect(escaped).toBeTruthy
	trap.deactivate!
	expect(trap.active).toBeFalsy

test 'concentric radii follow container minus inset with the minimum clamped' do
	expect(concentricRadius(40, 8)).toBe 32
	expect(concentricRadius(40, 8, 12)).toBe 32
	expect(concentricRadius(16, 10, 8)).toBe 8
	expect(concentricRadius(12, 12, 2)).toBe 2
	expect(concentricRadius(0, 0)).toBe 0

test 'capsule radius helpers agree with geometry' do
	expect(capsuleRadius(100, 44)).toBe 22
	expect(isCapsuleRadius(22, 100, 44)).toBeTruthy
	expect(isCapsuleRadius(10, 100, 44)).toBeFalsy

test 'column widths share extra space by flex weight' do
	let widths = computeColumnWidths 404, [{width: 100, flex: 1}, {width: 100, flex: 3}], 4
	expect(widths.length).toBe 2
	expect(widths[0]).toBeCloseTo 150, 1e-4
	expect(widths[1]).toBeCloseTo 250, 1e-4

test 'column widths honor minimums under pressure' do
	let widths = computeColumnWidths 120, [{width: 100, min: 60}, {width: 100, min: 20}], 0
	expect(widths[0]).toBeGreaterThanOrEqual 59.5
	expect(widths[1]).toBeGreaterThanOrEqual 19.5
	expect(widths[0] + widths[1]).toBeLessThanOrEqual 121

test 'columns collapse when the width falls below their threshold' do
	let res = collapseColumns 200, [{width: 240, min: 80, collapseBelow: 160}, {width: 240, min: 80, collapseBelow: 160, collapsible: no}], 0
	expect(res.collapsed.length).toBe 1
	expect(res.collapsed[0].width).toBe 240
	expect(res.active.length).toBe 1
	expect(res.widths.length).toBe 1
