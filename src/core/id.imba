const counters = new Map

export def uid prefix = 'gk'
	let n = (counters.get(prefix) or 0) + 1
	counters.set prefix, n
	"{prefix}-{n}"

export def resetIds
	counters.clear

def validatePart value, what
	unless typeof value == 'string' and value.length > 0
		throw new Error("GlassKit: invalid {what} — expected a non-empty string, received {String(value)}")
	if /\s/.test(value)
		throw new Error("GlassKit: invalid {what} '{value}' — whitespace is not allowed")
	value

export def namespacedId namespace, id
	validatePart namespace, 'glass namespace'
	validatePart id, 'glass id'
	"{namespace}:{id}"

export def parseNamespacedId full
	let idx = String(full).indexOf(':')
	if idx < 0
		[null, String(full)]
	else
		[String(full).slice(0, idx), String(full).slice(idx + 1)]
