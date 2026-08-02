import {clamp, lerp} from './math'
import {MAX_POLY} from './constants'

export class Rect
	prop x
	prop y
	prop w
	prop h

	def constructor x = 0, y = 0, w = 0, h = 0
		self.x = x
		self.y = y
		self.w = w
		self.h = h

	static def zero
		new Rect(0, 0, 0, 0)

	static def fromDOMRect r
		new Rect(r.left, r.top, r.width, r.height)

	get right
		self.x + self.w

	get bottom
		self.y + self.h

	get centerX
		self.x + self.w / 2

	get centerY
		self.y + self.h / 2

	get area
		self.w * self.h

	get isEmpty
		self.w <= 0 or self.h <= 0

	get minHalfExtent
		Math.min(self.w, self.h) / 2

	def set x, y, w, h
		self.x = x
		self.y = y
		self.w = w
		self.h = h
		self

	def copyFrom o
		self.x = o.x
		self.y = o.y
		self.w = o.w
		self.h = o.h
		self

	def clone
		new Rect(self.x, self.y, self.w, self.h)

	def equals o, eps = 1e-4
		Math.abs(self.x - o.x) <= eps and Math.abs(self.y - o.y) <= eps and Math.abs(self.w - o.w) <= eps and Math.abs(self.h - o.h) <= eps

	def contains px, py
		px >= self.x and px <= right and py >= self.y and py <= bottom

	def intersects o
		self.x < o.right and right > o.x and self.y < o.bottom and bottom > o.y

	def expand amount
		self.x -= amount
		self.y -= amount
		self.w += amount * 2
		self.h += amount * 2
		self

	def unionWith o
		if o.isEmpty
			return self
		if isEmpty
			return copyFrom(o)
		let nx = Math.min self.x, o.x
		let ny = Math.min self.y, o.y
		self.w = Math.max(right, o.right) - nx
		self.h = Math.max(bottom, o.bottom) - ny
		self.x = nx
		self.y = ny
		self

	def intersectWith o
		let nx = Math.max self.x, o.x
		let ny = Math.max self.y, o.y
		let nr = Math.min right, o.right
		let nb = Math.min bottom, o.bottom
		if nr <= nx or nb <= ny
			set 0, 0, 0, 0
		else
			set nx, ny, nr - nx, nb - ny
		self

	def toGL out, viewportHeight, scale = 1
		out.x = self.x * scale
		out.y = (viewportHeight - self.y - self.h) * scale
		out.w = self.w * scale
		out.h = self.h * scale
		out

	def surfaceDistanceTo o
		let dx = Math.max(0, Math.max(o.x - right, self.x - o.right))
		let dy = Math.max(0, Math.max(o.y - bottom, self.y - o.bottom))
		Math.sqrt(dx * dx + dy * dy)

export def polygonBounds points
	let minX = Infinity
	let minY = Infinity
	let maxX = -Infinity
	let maxY = -Infinity
	for i in [0 ... points.length] when i % 2 == 0
		let px = points[i]
		let py = points[i + 1]
		if px < minX then minX = px
		if px > maxX then maxX = px
		if py < minY then minY = py
		if py > maxY then maxY = py
	new Rect(minX, minY, maxX - minX, maxY - minY)

export def polygonCentroid points
	let cx = 0
	let cy = 0
	let n = Math.floor(points.length / 2)
	for i in [0 ... n]
		cx += points[i * 2]
		cy += points[i * 2 + 1]
	if n > 0
		[cx / n, cy / n]
	else
		[0, 0]

export def normalizePolygon points, rect
	let out = []
	let c = polygonCentroid points
	let hx = Math.max 1e-6, rect.w / 2
	let hy = Math.max 1e-6, rect.h / 2
	for i in [0 ... points.length] when i % 2 == 0
		out.push (points[i] - c[0]) / hx
		out.push (points[i + 1] - c[1]) / hy
	out

export def resamplePolygon points, maxCount = MAX_POLY
	let n = Math.floor(points.length / 2)
	if n <= maxCount
		return points.slice(0)
	let lengths = [0]
	let total = 0
	for i in [0 ... n]
		let j = (i + 1) % n
		let dx = points[j * 2] - points[i * 2]
		let dy = points[j * 2 + 1] - points[i * 2 + 1]
		total += Math.sqrt(dx * dx + dy * dy)
		lengths.push total
	let out = []
	let segLen = total / maxCount
	let idx = 0
	for k in [0 ... maxCount]
		let target = k * segLen
		while idx < n - 1 and lengths[idx + 1] < target
			idx += 1
		let segStart = lengths[idx]
		let segEnd = lengths[idx + 1]
		let t = segEnd > segStart ? (target - segStart) / (segEnd - segStart) : 0
		let j = (idx + 1) % n
		out.push lerp(points[idx * 2], points[j * 2], t)
		out.push lerp(points[idx * 2 + 1], points[j * 2 + 1], t)
	out

export def rectFromCenter cx, cy, w, h
	new Rect(cx - w / 2, cy - h / 2, w, h)

export def clampRectToViewport rect, vw, vh, margin = 0
	rect.x = clamp rect.x, margin, Math.max(margin, vw - rect.w - margin)
	rect.y = clamp rect.y, margin, Math.max(margin, vh - rect.h - margin)
	rect
