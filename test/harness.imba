export const results = {passed: 0, failed: 0, skipped: 0, failures: []}

const tests = []
let currentGroup = ''

export def group name
	currentGroup = name

export def test name, fn, opts = {}
	tests.push {name: name, fn: fn, group: currentGroup, opts: opts}

export def skipIfNode name, fn
	test name, fn, {nodeOnly: no, skipInNode: yes}

class Expectation
	prop negated

	def constructor value, negated = no
		self.value = value
		self.negated = negated

	get toNot
		new Expectation self.value, !self.negated

	def fail msg
		throw new Error msg

	def check cond, msg
		if self.negated
			cond = !cond
			msg = "not: {msg}"
		unless cond
			fail "{msg} (received {fmt(self.value)})"

	def fmt v
		if typeof v == 'string'
			return "\"{v}\""
		if v == null
			return 'null'
		if typeof v == 'object'
			try
				return JSON.stringify(v)
			catch e
				return String(v)
		String v

	def toBe expected
		check Object.is(self.value, expected), "expected {fmt(expected)}"

	def toEquals expected
		deepCheck self.value, expected, ''

	def deepCheck a, b, path
		if Object.is(a, b)
			return yes
		if typeof a != typeof b
			fail "expected deep equality at {path or 'root'}: types differ ({typeof a} vs {typeof b})"
		if a == null or b == null
			fail "expected deep equality at {path or 'root'}: {fmt a} vs {fmt b}"
		if typeof a == 'object'
			let keysA = Object.keys a
			let keysB = Object.keys b
			for k in keysB
				if keysA.indexOf(k) < 0
					fail "missing key {path}.{k}"
			for k in keysA
				deepCheck a[k], b[k], "{path}.{k}"
			return yes
		fail "expected deep equality at {path or 'root'}: {fmt a} vs {fmt b}"

	def toBeTruthy
		check !!self.value, 'expected truthy'

	def toBeFalsy
		check !self.value, 'expected falsy'

	def toBeNull
		check self.value == null, 'expected null'

	def toBeGreaterThan n
		check self.value > n, "expected > {n}"

	def toBeGreaterThanOrEqual n
		check self.value >= n, "expected >= {n}"

	def toBeLessThan n
		check self.value < n, "expected < {n}"

	def toBeLessThanOrEqual n
		check self.value <= n, "expected <= {n}"

	def toBeCloseTo n, tolerance = 0.001
		check Math.abs(self.value - n) <= tolerance, "expected ≈{n} ±{tolerance}"

	def toContain part
		check String(self.value).indexOf(part) >= 0, "expected to contain {fmt(part)}"

	def toMatch re
		check re.test(String(self.value)), "expected to match {re}"

	def toThrow fragment = null
		let threw = no
		let message = ''
		try
			self.value.call null
		catch e
			threw = yes
			message = e.message or String(e)
		unless threw
			fail 'expected function to throw'
		if fragment != null and message.indexOf(fragment) < 0
			fail "expected throw containing '{fragment}', got '{message}'"

export def expect value
	new Expectation value

export def runAll out
	let counts = {passed: 0, failed: 0, skipped: 0}
	for t in tests
		let label = (t.group != '' ? "{t.group} › " : '') + t.name
		if t.opts.skipInNode == yes and typeof globalThis.window == 'undefined'
			counts.skipped += 1
			out.call null, "SKIP {label}"
			continue
		try
			let r = t.fn.call null
			if r != null and typeof r.then == 'function'
				await r
			counts.passed += 1
			out.call null, "PASS {label}"
		catch e
			counts.failed += 1
			results.failures.push {name: label, message: (e and e.message) or String(e), stack: (e and e.stack) or ''}
			out.call null, "FAIL {label}\n  {e.message}"
	results.passed = counts.passed
	results.failed = counts.failed
	results.skipped = counts.skipped
	counts
