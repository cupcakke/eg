import {clamp, lerp} from './math'

export def sdCircle px, py, r
	Math.sqrt(px * px + py * py) - r

export def sdCapsule px, py, ax, ay, bx, byy, r
	let pax = px - ax
	let pay = py - ay
	let bax = bx - ax
	let bay = byy - ay
	let denom = bax * bax + bay * bay
	let h = denom > 1e-12 ? clamp((pax * bax + pay * bay) / denom, 0, 1) : 0
	let dx = px - (ax + bax * h)
	let dy = py - (ay + bay * h)
	Math.sqrt(dx * dx + dy * dy) - r

def cornerRadius px, py, rtl, rtr, rbr, rbl, hx, hy
	let r = 0
	if px < 0
		r = if py > 0 then rtl else rbl
	else
		r = if py > 0 then rtr else rbr
	clamp r, 0, Math.min(hx, hy)

export def sdRoundedBox px, py, hx, hy, rtl, rtr, rbr, rbl
	let r = cornerRadius px, py, rtl, rtr, rbr, rbl, hx, hy
	let qx = Math.abs(px) - hx + r
	let qy = Math.abs(py) - hy + r
	let ax = Math.max qx, 0
	let ay = Math.max qy, 0
	Math.sqrt(ax * ax + ay * ay) + Math.min(Math.max(qx, qy), 0) - r

export def sdSuperellipseBox px, py, hx, hy, r, n = 4.0
	let rr = clamp r, 0, Math.min(hx, hy)
	let qx = Math.abs(px) - (hx - rr)
	let qy = Math.abs(py) - (hy - rr)
	let ax = Math.max qx, 0
	let ay = Math.max qy, 0
	let outside = Math.pow(Math.pow(ax, n) + Math.pow(ay, n), 1 / n)
	outside + Math.min(Math.max(qx, qy), 0) - rr

export def sdOrientedRoundedPolygon px, py, pts, count, r
	let vx = pts[0]
	let vy = pts[1]
	let d = (px - vx) * (px - vx) + (py - vy) * (py - vy)
	let s = 1.0
	for i in [0 ... count]
		let j = (i + count - 1) % count
		let ex = pts[j * 2] - pts[i * 2]
		let ey = pts[j * 2 + 1] - pts[i * 2 + 1]
		let wx = px - pts[i * 2]
		let wy = py - pts[i * 2 + 1]
		let ee = ex * ex + ey * ey
		let t = ee > 1e-12 ? clamp((wx * ex + wy * ey) / ee, 0, 1) : 0
		let bx = wx - ex * t
		let byy = wy - ey * t
		d = Math.min d, bx * bx + byy * byy
		let c1 = py >= pts[i * 2 + 1]
		let c2 = py < pts[j * 2 + 1]
		let c3 = ex * wy > ey * wx
		if (c1 and c2 and c3) or (!c1 and !c2 and !c3)
			s = -s
	s * Math.sqrt(d) - r

export def opSmoothUnion d1, d2, k
	if k <= 0
		return Math.min d1, d2
	let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0, 1)
	lerp(d2, d1, h) - k * h * (1 - h)

export def opSmoothUnionBlend d1, d2, k
	if k <= 0
		return [Math.min(d1, d2), if d1 <= d2 then 0 else 1]
	let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0, 1)
	[lerp(d2, d1, h) - k * h * (1 - h), h]

export def opSmoothSubtract d1, d2, k
	if k <= 0
		return Math.max d1, -d2
	let h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0, 1)
	lerp(d1, -d2, h) + k * h * (1 - h)

export def opSmoothIntersect d1, d2, k
	if k <= 0
		return Math.max d1, d2
	let h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0, 1)
	lerp(d2, d1, h) + k * h * (1 - h)

export def sdCircleGradient px, py
	let l = Math.sqrt(px * px + py * py)
	if l < 1e-9
		[0, 1]
	else
		[px / l, py / l]

export def sdRoundedBoxGradient px, py, hx, hy, rtl, rtr, rbr, rbl
	let sx = if px < 0 then -1 else 1
	let sy = if py < 0 then -1 else 1
	let r = cornerRadius px, py, rtl, rtr, rbr, rbl, hx, hy
	let cx = (hx - r) * sx
	let cy = (hy - r) * sy
	let qx = Math.abs(px) - hx + r
	let qy = Math.abs(py) - hy + r
	if qx > 0 and qy > 0
		let gx = px - cx
		let gy = py - cy
		let l = Math.sqrt(gx * gx + gy * gy)
		if l < 1e-9
			[sx, sy]
		else
			[gx / l, gy / l]
	elif qx > qy
		[sx, 0]
	else
		[0, sy]

export def sdfGradientNum f, px, py, eps = 0.5
	let gx = (f(px + eps, py) - f(px - eps, py)) / (2 * eps)
	let gy = (f(px, py + eps) - f(px, py - eps)) / (2 * eps)
	let l = Math.sqrt(gx * gx + gy * gy)
	if l < 1e-9
		[0, 1]
	else
		[gx / l, gy / l]

export def sdfCurvatureNum f, px, py, eps = 0.75
	let fC = f px, py
	let fX1 = f(px + eps, py)
	let fX0 = f(px - eps, py)
	let fY1 = f(px, py + eps)
	let fY0 = f(px, py - eps)
	let fXY1 = f(px + eps, py + eps)
	let fXY2 = f(px - eps, py + eps)
	let fXY3 = f(px + eps, py - eps)
	let fXY4 = f(px - eps, py - eps)
	let fx = (fX1 - fX0) / (2 * eps)
	let fy = (fY1 - fY0) / (2 * eps)
	let fxx = (fX1 - 2 * fC + fX0) / (eps * eps)
	let fyy = (fY1 - 2 * fC + fY0) / (eps * eps)
	let fxy = (fXY1 - fXY2 - fXY3 + fXY4) / (4 * eps * eps)
	let denom = Math.pow(fx * fx + fy * fy, 1.5)
	if denom < 1e-9
		return 0
	(fyy * fx * fx - 2 * fx * fy * fxy + fxx * fy * fy) / denom

def shapeLocalDistance shape, px, py
	let cx = shape.x + shape.w / 2
	let cy = shape.y + shape.h / 2
	let lx = px - cx
	let ly = py - cy
	let hx = shape.w / 2
	let hy = shape.h / 2
	let t = shape.shapeType
	if t == 0
		let r = Math.min hx, hy
		if shape.w >= shape.h
			sdCapsule lx, ly, -(hx - r), 0, hx - r, 0, r
		else
			sdCapsule lx, ly, 0, -(hy - r), 0, hy - r, r
	elif t == 1
		sdRoundedBox lx, ly, hx, hy, shape.radii[0], shape.radii[1], shape.radii[2], shape.radii[3]
	elif t == 2
		sdCircle lx, ly, Math.min(hx, hy)
	elif t == 3
		sdSuperellipseBox lx, ly, hx, hy, shape.radii[0], shape.superN or 4.0
	elif t == 4
		let n = Math.min shape.polyCount, (shape.polyPoints.length / 2)
		let pts = new Array n * 2
		for i in [0 ... n]
			pts[i * 2] = shape.polyPoints[i * 2] * hx
			pts[i * 2 + 1] = shape.polyPoints[i * 2 + 1] * hy
		sdOrientedRoundedPolygon lx, ly, pts, n, shape.polyRadius or 0
	else
		sdRoundedBox lx, ly, hx, hy, shape.radii[0], shape.radii[1], shape.radii[2], shape.radii[3]

export class SdfScene
	prop shapes
	prop smoothing

	def constructor shapes = [], smoothing = 0
		self.shapes = shapes
		self.smoothing = smoothing

	get count
		self.shapes.length

	def dist px, py
		let d = 1e9
		for shape in self.shapes
			d = opSmoothUnion d, shapeLocalDistance(shape, px, py), self.smoothing
		d

	def distWithNearest px, py
		let d = 1e9
		let nearestD = 1e9
		let nearest = -1
		for i in [0 ... self.shapes.length]
			let di = shapeLocalDistance self.shapes[i], px, py
			if di < nearestD
				nearestD = di
				nearest = i
			d = opSmoothUnion d, di, self.smoothing
		[d, nearest, nearestD]

	def gradient px, py
		let f = do(x, y) self.dist(x, y)
		sdfGradientNum f, px, py

	def curvature px, py
		let f = do(x, y) self.dist(x, y)
		sdfCurvatureNum f, px, py

	def hitTest px, py, feather = 0
		dist(px, py) <= feather

	def nearestShape px, py
		let res = distWithNearest px, py
		if res[1] >= 0
			[self.shapes[res[1]], res[2], res[1]]
		else
			[null, 1e9, -1]

export def shapeDistanceRecord rec, px, py
	shapeLocalDistance rec, px, py
