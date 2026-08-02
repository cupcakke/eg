import {group, test, expect} from './harness'
import {Spring} from '../src/core/spring'

def drive spring, seconds, hz = 120
	let dt = 1 / hz
	let steps = Math.round seconds * hz
	for i in [0 ... steps]
		spring.advance dt

def driveWithProbe spring, seconds, probe
	let dt = 1 / 120
	let steps = Math.round seconds * 120
	for i in [0 ... steps]
		spring.advance dt
		probe spring, i

group 'spring'

test 'rest spring does not drift' do
	let s = new Spring 0.4, 1.0, 0
	s.snapTo 0.5
	drive s, 1
	expect(s.value).toBeCloseTo 0.5, 1e-12
	expect(s.settled).toBeTruthy

test 'critically damped spring never overshoots' do
	let s = new Spring 0.4, 1.0, 0
	s.setTarget 1
	let overshoot = no
	driveWithProbe s, 2.5, do(sp, i)
		if sp.value > 1.0005 then overshoot = yes
	expect(overshoot).toBeFalsy
	expect(s.value).toBeCloseTo 1, 0.002

test 'critically damped spring settles near target' do
	let s = new Spring 0.4, 1.0, 0
	s.setTarget 1
	drive s, 3
	expect(s.settled).toBeTruthy
	expect(Math.abs(s.value - 1) < 0.0005).toBeTruthy

test 'underdamped spring overshoots then settles' do
	let s = new Spring 0.5, 0.35, 0
	s.setTarget 1
	let peak = -1e9
	driveWithProbe s, 4, do(sp, i)
		if sp.value > peak then peak = sp.value
	expect(peak > 1.005).toBeTruthy
	expect(s.value).toBeCloseTo 1, 0.01
	expect(s.settled).toBeTruthy

test 'analytic velocity at handoff is continuous with blend' do
	let s = new Spring 0.4, 0.9, 0.12
	s.setTarget 1
	drive s, 0.15
	let beforeValue = s.value
	let beforeVel = s.velocity
	s.setTarget 0.2
	let jump = Math.abs s.value - beforeValue
	expect(jump < 1e-9).toBeTruthy
	let vels = []
	driveWithProbe s, 0.3, do(sp, i)
		vels.push sp.velocity
	let maxJump = 0
	for i in [1 ... vels.length]
		let d = Math.abs vels[i] - vels[i - 1]
		if d > maxJump then maxJump = d
	expect(maxJump < 26).toBeTruthy

test 'initial velocity seed affects trajectory' do
	let a = new Spring 0.4, 1.0, 0
	let b = new Spring 0.4, 1.0, 0
	a.setTarget 1, 0
	b.setTarget 1, 4
	a.advance 1 / 120
	b.advance 1 / 120
	expect(b.value > a.value).toBeTruthy

test 'snapTo retargets instantly and stays settled' do
	let s = new Spring 0.5, 0.5, 0
	s.setTarget 1
	drive s, 0.1
	s.snapTo -3
	expect(s.value).toBe -3
	expect(s.settled).toBeTruthy

test 'degenerate response is clamped and stays finite' do
	let s = new Spring 0, 1.0, 0
	expect(s.response >= 1e-4).toBeTruthy
	s.setTarget 1
	let finite = yes
	driveWithProbe s, 0.05, do(sp, i)
		if Number.isFinite(sp.value) == no then finite = no
	expect(finite).toBeTruthy

test 'zero-blend retarget keeps current value exactly' do
	let s = new Spring 0.35, 0.85, 0
	s.setTarget 1
	drive s, 0.22
	let v = s.value
	s.setTarget 0
	expect(s.value).toBeCloseTo v, 1e-12
