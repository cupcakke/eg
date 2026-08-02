import {logger} from '../core/logger'

export def nextPow2 v
	let p = 1
	while p < v
		p *= 2
	p

export def isPow2 v
	v > 0 and (v & (v - 1)) == 0

export def align4 v
	(v + 3) & ~3

export def annotateSource src
	let lines = src.split('\n')
	let out = []
	for i in [0 ... lines.length]
		out.push "{i + 1}: {lines[i]}"
	out.join '\n'

export def compileShader gl, type, source, name
	let sh = gl.createShader type
	if sh == null
		throw new Error "GlassKit: failed to create shader object for {name}"
	gl.shaderSource sh, source
	gl.compileShader sh
	let ok = gl.getShaderParameter sh, gl.COMPILE_STATUS
	if ok !== true
		let log = gl.getShaderInfoLog(sh) or 'unknown compile error'
		gl.deleteShader sh
		let err = new Error "GlassKit: shader '{name}' failed to compile — {log}\n{annotateSource(source)}"
		logger.error err.message
		throw err
	sh

export def linkProgram gl, name, vert, frag
	let prog = gl.createProgram!
	if prog == null
		throw new Error "GlassKit: failed to create program object for {name}"
	gl.attachShader prog, vert
	gl.attachShader prog, frag
	gl.linkProgram prog
	let ok = gl.getProgramParameter prog, gl.LINK_STATUS
	if ok !== true
		let log = gl.getProgramInfoLog(prog) or 'unknown link error'
		gl.deleteProgram prog
		logger.error "GlassKit: program '{name}' failed to link — {log}"
		throw new Error "GlassKit: program '{name}' failed to link — {log}"
	prog

export def checkGlError gl, where
	if logger.devEnabled
		let err = gl.getError!
		if err != gl.NO_ERROR
			logger.warnOnce "glerror:{where}:{err}", "GL error 0x{err.toString(16)} at {where}"

export def chooseColorFormat gl, isGL2, caps
	if isGL2 and (caps.hasFloatBuffers or caps.hasHalfFloatBuffers)
		{internalFormat: gl.RGBA16F, format: gl.RGBA, type: gl.HALF_FLOAT, dither: 0.0}
	elif isGL2 and caps.hasFloatBuffers
		{internalFormat: gl.RGBA32F, format: gl.RGBA, type: gl.FLOAT, dither: 0.0}
	else
		{internalFormat: (if isGL2 then gl.RGBA8 else gl.RGBA), format: gl.RGBA, type: gl.UNSIGNED_BYTE, dither: 1.0 / 255.0}

export def computeGaussianWeights sigma
	let s = Math.max 0.5, sigma
	let w = []
	let total = 0
	for i in [0 ... 5]
		let v = Math.exp(-(i * i) / (2 * s * s))
		w.push v
		total += if i == 0 then v else v * 2
	for i in [0 ... 5]
		w[i] = w[i] / total
	w

export def gaussianSigmaForRadius radius
	Math.max 0.6, radius / 2.5

export def levelsForRadius radius, baseSize
	let levels = 1
	let r = 2
	while r < Math.max(2, radius) and levels < 8
		r *= 2
		levels += 1
	Math.min levels, 8

export def lodForRadius radius
	Math.max 0, Math.log2(Math.max(1, radius)) - 1.585
