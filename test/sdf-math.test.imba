import {group, test, expect} from './harness'
import {sdCircle, sdCapsule, sdRoundedBox, sdSuperellipseBox, sdOrientedRoundedPolygon, opSmoothUnion} from '../src/core/sdf-cpu'
import {SdfScene} from '../src/core/sdf-cpu'

group 'sdf'

test 'circle exact at landmark points' do
	expect(sdCircle(0, 0, 10)).toBeCloseTo -10
	expect(sdCircle(10, 0, 10)).toBeCloseTo 0, 1e-6
	expect(sdCircle(3, 4, 10)).toBeCloseTo -5, 1e-6
	expect(sdCircle(13, 4, 10)).toBeCloseTo(Math.hypot(13, 4) - 10)

test 'rounded box axis distances are exact' do
	expect(sdRoundedBox(0, 0, 20, 10, 0, 0, 0, 0)).toBeCloseTo -10
	expect(sdRoundedBox(20, 0, 20, 10, 0, 0, 0, 0)).toBeCloseTo 0
	expect(sdRoundedBox(23, 0, 20, 10, 0, 0, 0, 0)).toBeCloseTo 3
	expect(sdRoundedBox(0, 14, 20, 10, 0, 0, 0, 0)).toBeCloseTo 4

test 'rounded box corner follows circle of corner radius' do
	let d = sdRoundedBox(19, 9, 20, 10, 5, 5, 5, 5)
	expect(d).toBeCloseTo(Math.hypot(4, 4) - 5, 1e-6)
	let inside = sdRoundedBox(0, 0, 20, 10, 5, 5, 5, 5)
	expect(inside).toBeCloseTo(-10, 1e-6)

test 'box returns negative inside beyond corner center' do
	let d = sdRoundedBox(18, 8, 20, 10, 5, 5, 5, 5)
	expect(d < 0).toBeTruthy

test 'capsule segment endpoints round exactly' do
	expect(sdCapsule(0, 5, -10, 0, 10, 0, 4)).toBeCloseTo 1
	expect(sdCapsule(14, 0, -10, 0, 10, 0, 4)).toBeCloseTo 0
	expect(sdCapsule(-14, 0, -10, 0, 10, 0, 4)).toBeCloseTo 0
	expect(sdCapsule(0, 0, -10, 0, 10, 0, 4)).toBeCloseTo -4

test 'superellipse box with n large approaches rounded box family' do
	let h0 = sdSuperellipseBox(0, 0, 20, 10, 4, 8)
	expect(h0).toBeCloseTo -10, 1e-3
	let d2 = sdSuperellipseBox(30, 14, 20, 10, 4, 4)
	expect(d2 > 0).toBeTruthy
	let inside = sdSuperellipseBox(5, 2, 20, 10, 4, 4)
	expect(inside < 0).toBeTruthy

test 'smooth union converges to min as k goes to zero' do
	let a = 2
	let b = 5
	expect(opSmoothUnion(a, b, 0)).toBeCloseTo 2
	expect(opSmoothUnion(a, b, 0.0001)).toBeCloseTo 2, 0.01

test 'smooth union lowers distance in blend band' do
	let d = opSmoothUnion(3, 3, 10)
	expect(d < 3).toBeTruthy
	let far = opSmoothUnion(100, 3, 10)
	expect(far).toBeCloseTo 3, 0.6

test 'polygon distance matches closed-form for axis rect' do
	let pts = [-10, -5, 10, -5, 10, 5, -10, 5]
	expect(sdOrientedRoundedPolygon(0, 0, pts, 4, 0)).toBeCloseTo(-5, 1e-4)
	expect(sdOrientedRoundedPolygon(13, 0, pts, 4, 0)).toBeCloseTo 3, 1e-3
	let rounded = sdOrientedRoundedPolygon(13, 0, pts, 4, 2)
	expect(rounded).toBeCloseTo(1, 1e-3)

test 'polygon triangle signed distance negative inside' do
	let tri = [0, -10, 10, 8, -10, 8]
	expect(sdOrientedRoundedPolygon(0, 0, tri, 3, 0) < 0).toBeTruthy
	expect(sdOrientedRoundedPolygon(0, -20, tri, 3, 0) > 0).toBeTruthy

test 'SdfScene union with smoothing never exceeds min shape distance' do
	let scene = new SdfScene [
		{x: 0, y: 0, w: 40, h: 20, shapeType: 1, radii: [4, 4, 4, 4]}
		{x: 30, y: 6, w: 40, h: 20, shapeType: 1, radii: [4, 4, 4, 4]}
	], 12
	let info = scene.distWithNearest 25, 10
	let unionD = info[0]
	let nearestD = info[2]
	expect(unionD <= nearestD + 1e-9).toBeTruthy

test 'SdfScene gradient points outward' do
	let scene = new SdfScene [{x: -10, y: -10, w: 20, h: 20, shapeType: 2, radii: [10, 10, 10, 10]}], 0
	let g = scene.gradient 20, 0
	expect(g[0] > 0).toBeTruthy
	expect(Math.abs(g[1]) < 0.05).toBeTruthy

test 'distWithNearest picks nearest shape index' do
	let scene = new SdfScene [
		{x: 0, y: 0, w: 10, h: 10, shapeType: 2, radii: [5, 5, 5, 5]}
		{x: 100, y: 100, w: 10, h: 10, shapeType: 2, radii: [5, 5, 5, 5]}
	], 0
	let info = scene.distWithNearest 102, 102
	expect(info[1]).toBe 1
