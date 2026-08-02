import {group, test, expect} from './harness'
import {registry} from '../src/material/glass-registry'
import '../src/material/glass-container'
import {Glass} from '../src/material/glass'
import {Shape} from '../src/material/shape'
import {MAX_SHAPES, FLOATS_PER_SHAPE, SHAPE_CAPSULE, SHAPE_ROUNDED_RECT, SHAPE_POLYGON, VARIANT_REGULAR, VARIANT_CLEAR} from '../src/core/constants'
import {fakeEl} from './mini-dom'

group 'shape record packing'

def makeRenderer dpr = 2, vpH = 600
	{shapeData: new Float32Array(MAX_SHAPES * FLOATS_PER_SHAPE), polyData: new Float32Array(8 * 24), dpr: dpr, width: 5000, height: 5000, env: {viewportHeightCss: vpH}}

def soloEntry rect, glass, shape, opts = {}
	registry.resetAll!
	let parent = fakeEl 'div'
	let el = fakeEl 'div', rect[0], rect[1], rect[2], rect[3]
	parent.appendChild el
	let cont = registry.registerContainer parent, 0
	let entry = registry.register el, glass, shape, opts
	let renderer = makeRenderer!
	cont.packShapeData renderer
	[entry, renderer.shapeData, renderer.polyData, cont]

test 'rect converts to GL coordinates with flipped y and dpr scaling' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	let out = packed[1]
	expect(out[0]).toBeCloseTo 20
	expect(out[1]).toBeCloseTo((600 - 20 - 40) * 2)
	expect(out[2]).toBeCloseTo 200
	expect(out[3]).toBeCloseTo 80
	registry.resetAll!

test 'capsule radii resolve to half the short side in device px' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	let out = packed[1]
	for i in [4 ... 8]
		expect(out[i]).toBeCloseTo 40
	registry.resetAll!

test 'material parameters land at their declared offsets' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular.tint('#5ac8fa', 0.3).interactive(yes), Shape.rect(12), {}
	let entry = packed[0]
	let out = packed[1]
	let p = entry.resolvedGlass!
	expect(out[8]).toBeCloseTo p.tint[0], 1e-4
	expect(out[9]).toBeCloseTo p.tint[1], 1e-4
	expect(out[10]).toBeCloseTo p.tint[2], 1e-4
	expect(out[11]).toBeCloseTo p.tint[3], 1e-4
	expect(out[16]).toBe SHAPE_ROUNDED_RECT
	expect(out[17]).toBe VARIANT_REGULAR
	expect(out[18]).toBeCloseTo p.tintStrength, 1e-4
	expect(out[19]).toBe 1
	expect(out[24]).toBeCloseTo p.refractionStrength, 1e-4
	expect(out[25]).toBeCloseTo p.edgeThickness, 1e-4
	expect(out[26]).toBeCloseTo p.chromaticAberration, 1e-4
	expect(out[27]).toBeCloseTo p.blurRadius * 2, 1e-4
	expect(out[28]).toBeCloseTo p.specularIntensity, 1e-4
	expect(out[29]).toBeCloseTo p.specularSharpness, 1e-4
	expect(out[33]).toBeCloseTo 4
	expect(out[36]).toBe 1
	registry.resetAll!

test 'shadow record scales with dpr and flips its y offset' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	let out = packed[1]
	expect(out[12]).toBeGreaterThan 0.2
	expect(out[13]).toBeCloseTo 44
	expect(out[14]).toBeCloseTo 0
	expect(out[15]).toBeCloseTo -24
	registry.resetAll!

test 'interaction state channels write through verbatim with pointer y flipped' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	let entry = packed[0]
	entry.state.press = 0.42
	entry.state.hover = 0.75
	entry.state.pointerX = 0.25
	entry.state.pointerY = 0.8
	let renderer = makeRenderer!
	packed[3].packShapeData renderer
	let out = renderer.shapeData
	expect(out[20]).toBeCloseTo 0.42, 1e-4
	expect(out[21]).toBeCloseTo 0.75, 1e-4
	expect(out[22]).toBeCloseTo 0.25, 1e-4
	expect(out[23]).toBeCloseTo 0.2, 1e-4
	registry.resetAll!

test 'clear variant carries dimming while regular forces it off' do
	let clearPacked = soloEntry [10, 20, 100, 40], Glass.clear, Shape.capsule(), {}
	clearPacked[0].state.dimmingOpacity = 0.35
	let clearRenderer = makeRenderer!
	clearPacked[3].packShapeData clearRenderer
	expect(clearRenderer.shapeData[31]).toBeCloseTo 0.35, 1e-4
	registry.resetAll!
	let regularPacked = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	regularPacked[0].state.dimmingOpacity = 0.35
	let regularRenderer = makeRenderer!
	regularPacked[3].packShapeData regularRenderer
	expect(regularRenderer.shapeData[31]).toBe 0
	expect(regularRenderer.shapeData[17]).toBe VARIANT_REGULAR
	registry.resetAll!

test 'polygon shapes fill a poly slot and flag their type' do
	let packed = soloEntry [10, 20, 80, 80], Glass.regular, Shape.path([[0, 0], [80, 0], [40, 70]], 8), {}
	let out = packed[1]
	let polys = packed[2]
	expect(out[16]).toBe SHAPE_POLYGON
	expect(out[32]).toBe 0
	expect(out[34]).toBeGreaterThanOrEqual 3
	let any = no
	for i in [0 ... 6]
		if polys[i] != 0
			any = yes
	expect(any).toBeTruthy
	registry.resetAll!

test 'more than eight polygons in a chunk degrade the extras to rounded rects' do
	registry.resetAll!
	let parent = fakeEl 'div'
	let els = []
	for i in [0 ... 9]
		let el = fakeEl 'div', 10 + i * 110, 20, 80, 80
		parent.appendChild el
		els.push el
	let cont = registry.registerContainer parent, 0
	for el in els
		registry.register el, Glass.regular, Shape.path([[0, 0], [80, 0], [40, 70]], 4), {}
	let renderer = makeRenderer!
	cont.packShapeData renderer
	let out = renderer.shapeData
	for i in [0 ... 8]
		expect(out[i * FLOATS_PER_SHAPE + 16]).toBe SHAPE_POLYGON
		expect(out[i * FLOATS_PER_SHAPE + 32]).toBe i
	expect(out[8 * FLOATS_PER_SHAPE + 16]).toBe SHAPE_ROUNDED_RECT
	registry.resetAll!

test 'tail of every record stays zeroed for stable hashing' do
	let packed = soloEntry [10, 20, 100, 40], Glass.regular, Shape.capsule(), {}
	let out = packed[1]
	for pad in [37 ... 48]
		expect(out[pad]).toBe 0
	registry.resetAll!
