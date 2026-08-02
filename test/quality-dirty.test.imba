import {group, test, expect} from './harness'
import {RafScheduler} from '../src/core/raf-scheduler'
import {DirtyTracker} from '../src/core/dirty-tracker'
import {Rect} from '../src/core/geometry'
import {TIER_DEGRADE_MS, TIER_RESTORE_MS, QUALITY_TIERS} from '../src/core/constants'

group 'quality tiers'

test 'frame average tracks injected frame times' do
	let s = new RafScheduler
	s.budgetMs = 16.7
	for i in [0 ... 40]
		s.step 10
	expect(s.frameAvg).toBeLessThan 12
	for i in [0 ... 200]
		s.step 25
	expect(s.frameAvg).toBeGreaterThan 20

test 'sustained over-budget frames degrade through the tiers' do
	let s = new RafScheduler
	s.budgetMs = 16.7
	let seen = []
	s.onQualityChange do(q) seen.push q.tier
	expect(s.tier).toBe 0
	let guard = 0
	while s.tier == 0 and guard < 2000
		s.step 40
		guard += 1
	expect(s.tier).toBeGreaterThanOrEqual 1
	expect(seen.length).toBeGreaterThanOrEqual 1
	expect(seen[0]).toBe 1
	expect(s.quality.blurScale).toBeLessThan 1

test 'sustained headroom restores the top tier' do
	let s = new RafScheduler
	s.budgetMs = 16.7
	let guard = 0
	while s.tier < 2 and guard < 6000
		s.step 40
		guard += 1
	expect(s.tier).toBeGreaterThanOrEqual 2
	guard = 0
	while s.tier > 0 and guard < 8000
		s.step 6
		guard += 1
	expect(s.tier).toBe 0
	expect(s.quality.dprScale).toBe 1

test 'a quality lock pins the table and ignores budgets' do
	let s = new RafScheduler
	s.budgetMs = 16.7
	s.setQuality 2
	expect(s.quality.tier).toBe 2
	expect(s.quality.dprScale).toBe 0.85
	for i in [0 ... 900]
		s.step 40
	expect(s.tier).toBe 0
	expect(s.quality.tier).toBe 2
	s.setQuality null
	for i in [0 ... 2000]
		s.step 40
	expect(s.tier).toBeGreaterThanOrEqual 1

test 'override tier values clamp into range' do
	let s = new RafScheduler
	s.setQuality 99
	expect(s.quality.tier).toBe QUALITY_TIERS - 1
	s.setQuality -4
	expect(s.quality.tier).toBe 0

test 'degrade and restore windows are consistent with the budgets' do
	let s = new RafScheduler
	s.budgetMs = 16.7
	let count = 0
	while s.tier == 0 and count < 100000
		s.step 20
		count += 1
	let degradedMs = count * 20
	expect(degradedMs).toBeGreaterThan TIER_DEGRADE_MS - 200
	expect(degradedMs).toBeLessThan TIER_DEGRADE_MS + 5200

group 'dirty tracking'

test 'a fresh tracker starts fully dirty and consumes cleanly' do
	let t = new DirtyTracker
	expect(t.frameDirty).toBeTruthy
	let outShapes = new Map
	let outBackdrops = new Map
	let flags = t.consumeSnapshot outShapes, outBackdrops
	expect(flags[0]).toBeTruthy
	expect(flags[1]).toBeFalsy
	expect(t.frameDirty).toBeFalsy

test 'shape marks union rects per container and flag only that container' do
	let t = new DirtyTracker
	t.consumeSnapshot new Map, new Map
	let a = new Rect 0, 0, 50, 50
	let b = new Rect 100, 100, 50, 50
	t.markShape 'c1', a
	t.markShape 'c1', b
	expect(t.containerDirty('c1')).toBeTruthy
	expect(t.containerDirty('c2')).toBeFalsy
	let rect = t.shapeRectFor 'c1'
	expect(rect).toNot.toBeNull
	expect(rect.x).toBeLessThanOrEqual 0
	expect(rect.right >= 150).toBeTruthy
	expect(rect.bottom >= 150).toBeTruthy

test 'animation marks keep every frame dirty until settled' do
	let t = new DirtyTracker
	t.consumeSnapshot new Map, new Map
	t.markAnimation yes
	expect(t.frameDirty).toBeTruthy
	t.consumeSnapshot new Map, new Map
	expect(t.frameDirty).toBeFalsy

test 'backdrop marks are reported separately from shape marks' do
	let t = new DirtyTracker
	t.consumeSnapshot new Map, new Map
	t.markBackdrop 'root', new Rect(5, 5, 20, 20)
	expect(t.backdropRectFor('root')).toNot.toBeNull
	expect(t.shapeRectFor('root')).toBeNull
	let outShapes = new Map
	let outBackdrops = new Map
	t.consumeSnapshot outShapes, outBackdrops
	expect(outBackdrops.has('root')).toBeTruthy
	expect(outShapes.has('root')).toBeFalsy

test 'empty rects never mark anything' do
	let t = new DirtyTracker
	t.consumeSnapshot new Map, new Map
	t.markShape 'x', null
	t.markShape 'x', new Rect(0, 0, 0, 0)
	expect(t.frameDirty).toBeFalsy

test 'settings flips ride the snapshot channel' do
	let t = new DirtyTracker
	t.consumeSnapshot new Map, new Map
	t.markSettings!
	expect(t.frameDirty).toBeTruthy
	let flags = t.consumeSnapshot new Map, new Map
	expect(flags[1]).toBeTruthy
	expect(t.frameDirty).toBeFalsy
