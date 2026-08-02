import {SHAPE_CAPSULE, SHAPE_ROUNDED_RECT, SHAPE_CIRCLE, SHAPE_CONCENTRIC_RECT, SHAPE_POLYGON} from '../core/constants'
import {polygonBounds, normalizePolygon, resamplePolygon} from '../core/geometry'
import {concentricRadius} from './concentric'

export class ShapeDescriptor
	prop type
	prop cornerRadius
	prop corners
	prop uniformCorners
	prop minRadius
	prop superN
	prop polyPoints
	prop polyRadius
	prop polyBounds

	def constructor type, opts = {}
		self.type = type
		self.cornerRadius = opts.cornerRadius or 0
		self.corners = opts.corners or null
		self.uniformCorners = opts.uniformCorners !== no
		self.minRadius = opts.minRadius or 0
		self.superN = opts.superN or 4.0
		self.polyPoints = opts.polyPoints or null
		self.polyRadius = opts.polyRadius or 0
		self.polyBounds = opts.polyBounds or null

	def clone
		new ShapeDescriptor self.type,
			cornerRadius: self.cornerRadius
			corners: (self.corners ? {tl: self.corners.tl, tr: self.corners.tr, br: self.corners.br, bl: self.corners.bl} : null)
			uniformCorners: self.uniformCorners
			minRadius: self.minRadius
			superN: self.superN
			polyPoints: (self.polyPoints ? self.polyPoints.slice(0) : null)
			polyRadius: self.polyRadius
			polyBounds: self.polyBounds

	def resolveRadii rect, context = {}
		let tl = self.cornerRadius
		let tr = self.cornerRadius
		let br = self.cornerRadius
		let bl = self.cornerRadius
		if self.corners != null
			tl = self.corners.tl
			tr = self.corners.tr
			br = self.corners.br
			bl = self.corners.bl
		if context.ltr == no
			let tmp = tl
			tl = tr
			tr = tmp
			tmp = bl
			bl = br
			br = tmp
		let maxR = Math.min(rect.w, rect.h) / 2
		if self.type == SHAPE_CAPSULE
			return [maxR, maxR, maxR, maxR]
		if self.type == SHAPE_CONCENTRIC_RECT
			let containerR = context.containerRadius or 0
			let inset = context.inset or 0
			let computed = concentricRadius (containerR > 0 ? containerR : self.minRadius + inset), inset, self.minRadius
			tl = tr = br = bl = computed
		let sumTop = tl + tr
		let sumRight = tr + br
		let sumBottom = bl + br
		let sumLeft = tl + bl
		let scale = 1
		if sumTop > rect.w and sumTop > 0 then scale = Math.min scale, rect.w / sumTop
		if sumBottom > rect.w and sumBottom > 0 then scale = Math.min scale, rect.w / sumBottom
		if sumRight > rect.h and sumRight > 0 then scale = Math.min scale, rect.h / sumRight
		if sumLeft > rect.h and sumLeft > 0 then scale = Math.min scale, rect.h / sumLeft
		[tl * scale, tr * scale, br * scale, bl * scale]

export const Shape =
	capsule: do
		new ShapeDescriptor SHAPE_CAPSULE
	circle: do
		new ShapeDescriptor SHAPE_CIRCLE
	rect: do(opts = {})
		if typeof opts == 'number'
			return new ShapeDescriptor(SHAPE_ROUNDED_RECT, {cornerRadius: opts})
		if opts.corners != null
			let c = opts.corners
			return new ShapeDescriptor SHAPE_ROUNDED_RECT,
				corners: {tl: (c.tl or c.topLeading or 0), tr: (c.tr or c.topTrailing or 0), br: (c.br or c.bottomTrailing or 0), bl: (c.bl or c.bottomLeading or 0)}
				uniformCorners: (opts.isUniform or no)
		new ShapeDescriptor(SHAPE_ROUNDED_RECT, {cornerRadius: (opts.cornerRadius or 0)})
	concentric: do(opts = {})
		let minimum = if typeof opts == 'number' then opts else (opts.minimum or 8)
		new ShapeDescriptor SHAPE_CONCENTRIC_RECT, {minRadius: minimum, superN: 4.0}
	superellipse: do(opts = {})
		let radius = if typeof opts == 'number' then opts else (opts.radius or 12)
		let exponent = if typeof opts == 'number' then 4.0 else (opts.exponent or 4.0)
		new ShapeDescriptor SHAPE_CONCENTRIC_RECT, {cornerRadius: radius, minRadius: radius, superN: exponent}
	path: do(points, radius = 0)
		let flat = []
		if Array.isArray(points) and points.length > 0 and Array.isArray(points[0])
			for p in points
				flat.push p[0]
				flat.push p[1]
		elif Array.isArray(points)
			flat = points.slice(0)
		let bounds = polygonBounds flat
		let normalized = normalizePolygon resamplePolygon(flat), bounds
		new ShapeDescriptor SHAPE_POLYGON,
			polyPoints: normalized
			polyRadius: radius
			polyBounds: bounds
