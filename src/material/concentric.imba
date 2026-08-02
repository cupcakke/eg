import {settings} from '../core/settings'

export def concentricRadius containerRadius, inset, minRadius = 0
	let r = containerRadius - inset
	if r < minRadius
		minRadius
	else
		r

export def concentricRadii containerRadii, inset, minRadius = 0
	[
		concentricRadius(containerRadii[0], inset, minRadius)
		concentricRadius(containerRadii[1], inset, minRadius)
		concentricRadius(containerRadii[2], inset, minRadius)
		concentricRadius(containerRadii[3], inset, minRadius)
	]

export def containerCornerOffset inset, sizeToFit = no
	let r = settings.windowCornerRadius
	let effectiveInset = if sizeToFit then inset else Math.max(0, inset - r * (1 - Math.SQRT1_2))
	{padding: effectiveInset, radius: concentricRadius(r, inset, Math.min(6, r))}

export def capsuleRadius w, h
	Math.min(w, h) / 2

export def isCapsuleRadius radius, w, h
	radius >= Math.min(w, h) / 2 - 0.5

export def inheritContainerRadius el
	let node = el
	while node != null
		if node.getAttribute
			let explicit = node.getAttribute 'data-gk-container-radius'
			if explicit != null
				let v = Number explicit
				if Number.isFinite(v)
					return v
			let surface = node.getAttribute 'data-gk-surface'
			if surface != null and typeof globalThis.getComputedStyle != 'undefined'
				let style = globalThis.getComputedStyle node
				let r = parseFloat(style.borderTopLeftRadius)
				if Number.isFinite(r)
					return r
		node = node.parentNode
	settings.windowCornerRadius

export def computeInset childRect, containerRect
	Math.max childRect.x - containerRect.x, childRect.y - containerRect.y

export class ConcentricRectModel
	prop minRadius
	prop inset
	prop containerRadius

	def constructor opts = {}
		self.minRadius = opts.minimum or 8
		self.inset = opts.inset or 0
		self.containerRadius = opts.containerRadius or 0

	def resolve el = null
		let containerR = self.containerRadius
		if el != null
			containerR = inheritContainerRadius el
		let inset = self.inset
		if el != null and self.inset == 0
			inset = 4
		concentricRadius containerR, inset, self.minRadius
