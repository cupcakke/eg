import {group, test, expect} from './harness'
import {registry} from '../src/material/glass-registry'
import '../src/material/glass-container'
import {Glass} from '../src/material/glass'
import {Shape} from '../src/material/shape'
import {MAX_SHAPES, FLOATS_PER_SHAPE} from '../src/core/constants'
import {fakeEl} from './mini-dom'

group 'container packing'

def makeRenderer width = 1600, height = 1200, dpr = 2, vpH = 600
	{shapeData: new Float32Array(MAX_SHAPES * FLOATS_PER_SHAPE), polyData: new Float32Array(8 * 24), dpr: dpr, width: width, height: height, env: {viewportHeightCss: vpH}}

def setupContainer spacing = 12, rects = []
	let parent = fakeEl 'div'
	let els = []
	for r in rects
		let el = fakeEl 'div', r[0], r[1], r[2], r[3]
		parent.appendChild el
		els.push el
	let cont = registry.registerContainer parent, spacing
	[cont, els]

test 'pack writes one record per entry and reports chunk size' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 100, 40], [10, 60, 100, 40]]
	let cont = setup[0]
	for el in setup[1]
		registry.register el, Glass.regular, Shape.capsule(), {}
	let renderer = makeRenderer!
	let n = cont.packShapeData renderer
	expect(n).toBe 2
	expect(cont.chunkCount).toBe 2
	registry.resetAll!

test 'chunking never exceeds the shader shape budget' do
	registry.resetAll!
	let rects = []
	for i in [0 ... 70]
		rects.push [10 + (i % 10) * 130, 10 + Math.floor(i / 10) * 60, 120, 44]
	let setup = setupContainer 12, rects
	let cont = setup[0]
	for el in setup[1]
		registry.register el, Glass.regular, Shape.capsule(), {}
	let n = cont.packShapeData makeRenderer!
	expect(n).toBe MAX_SHAPES
	expect(cont.chunkCount).toBe MAX_SHAPES
	registry.resetAll!

test 'clip rect covers all shapes grown by spacing in device px' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 100, 40], [10, 60, 100, 40]]
	let cont = setup[0]
	for el in setup[1]
		registry.register el, Glass.regular, Shape.capsule(), {}
	cont.packShapeData makeRenderer!
	let clip = cont.clipRectGL
	expect(clip.w).toBeGreaterThan 0
	expect(clip.x).toBeLessThanOrEqual 20
	expect(clip.y).toBeLessThanOrEqual 1000
	expect(clip.x + clip.w).toBeGreaterThanOrEqual 220
	expect(clip.y + clip.h).toBeGreaterThanOrEqual 1180
	registry.resetAll!

test 'empty container produces an empty clip and zero chunks' do
	registry.resetAll!
	let setup = setupContainer 12, []
	let cont = setup[0]
	let n = cont.packShapeData makeRenderer!
	expect(n).toBe 0
	expect(cont.clipRectGL.w).toBe 0
	expect(cont.offScreen).toBeTruthy
	registry.resetAll!

test 'union members pack into one segment with union spacing' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 100, 40], [10, 60, 100, 40]]
	let cont = setup[0]
	registry.register setup[1][0], Glass.regular, Shape.capsule(), {unionId: 'chip-pair', namespace: 'demo'}
	registry.register setup[1][1], Glass.regular, Shape.capsule(), {unionId: 'chip-pair', namespace: 'demo'}
	let segs = cont.segments
	expect(segs.length).toBe 1
	expect(segs[0].count).toBe 2
	expect(segs[0].spacing).toBeGreaterThanOrEqual 24
	registry.resetAll!

test 'mixed plain and union entries split into ordered segments' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 60, 30], [80, 10, 60, 30], [150, 10, 60, 30]]
	let cont = setup[0]
	registry.register setup[1][0], Glass.regular, Shape.capsule(), {unionId: 'a', namespace: 'demo'}
	registry.register setup[1][1], Glass.regular, Shape.capsule(), {}
	registry.register setup[1][2], Glass.regular, Shape.capsule(), {unionId: 'b', namespace: 'demo'}
	let segs = cont.segments
	expect(segs.length).toBe 3
	expect(segs[0].count).toBe 1
	expect(segs[1].count).toBe 1
	expect(segs[2].count).toBe 1
	expect(segs[1].spacing).toBe 12
	registry.resetAll!

test 'pack aggregates variant, blur, shadow and focus state' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 100, 40], [10, 60, 100, 40]]
	let cont = setup[0]
	let ea = registry.register setup[1][0], Glass.clear, Shape.capsule(), {}
	let eb = registry.register setup[1][1], Glass.clear, Shape.capsule(), {}
	cont.packShapeData makeRenderer!
	expect(cont.allClear).toBeTruthy
	expect(cont.maxBlurRadius).toBeGreaterThan 0
	ea.focused = yes
	cont.packShapeData makeRenderer!
	expect(cont.focusedIndex).toBe 0
	ea.focused = no
	eb.focused = yes
	expect(cont.packShapeData(makeRenderer!)).toBe 2
	expect(cont.focusedIndex).toBe 1
	registry.resetAll!

test 'a regular variant among clears flips the aggregate' do
	registry.resetAll!
	let setup = setupContainer 12, [[10, 10, 100, 40], [10, 60, 100, 40]]
	let cont = setup[0]
	registry.register setup[1][0], Glass.clear, Shape.capsule(), {}
	registry.register setup[1][1], Glass.regular, Shape.capsule(), {}
	cont.packShapeData makeRenderer!
	expect(cont.allClear).toBeFalsy
	registry.resetAll!
