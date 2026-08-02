import {clamp} from '../core/math'

export def computeColumnWidths totalWidth, columns, handleSize = 1
	let n = columns.length
	if n == 0
		return []
	let available = totalWidth - handleSize * (n - 1)
	let widths = []
	let sum = 0
	for c in columns
		let w = Math.max c.min or 0, Number(c.width) or 0
		widths.push w
		sum += w
	if sum <= available
		let flexibleSum = 0
		for c in columns
			flexibleSum += c.flex or 1
		let extra = available - sum
		for i in [0 ... n]
			if extra > 0
				let share = extra * ((columns[i].flex or 1) / flexibleSum)
				widths[i] += share
		return widths
	let deficit = sum - available
	let locked = new Array(n).fill(no)
	for iter in [0 ... 8]
		if deficit <= 0.5
			break
		let totalPriority = 0
		let movable = 0
		for i in [0 ... n]
			unless locked[i]
				movable += 1
				totalPriority += 1 / Math.max(1, columns[i].priority or n)
		if movable == 0
			break
		let remainingDeficit = deficit
		for i in [0 ... n]
			if locked[i]
				continue
			let share = deficit * ((1 / Math.max(1, columns[i].priority or n)) / totalPriority)
			let canShrink = widths[i] - (columns[i].min or 0)
			let shrinkBy = Math.min share, Math.max(0, canShrink)
			widths[i] -= shrinkBy
			remainingDeficit -= shrinkBy
			if widths[i] <= (columns[i].min or 0) + 0.5
				widths[i] = columns[i].min or 0
				locked[i] = yes
		deficit = remainingDeficit
	widths

export def collapseColumns totalWidth, columns, handleSize = 1
	let active = []
	for c in columns
		active.push c
	let widths = computeColumnWidths totalWidth, active, handleSize
	let collapsed = []
	let changed = yes
	for iter in [0 ... columns.length]
		if changed == no
			break
		changed = no
		let i = active.length
		while i > 0
			i -= 1
			let minNeeded = active[i].collapseBelow or active[i].min or 0
			if widths[i] < minNeeded - 0.5 and active[i].collapsible != no
				collapsed.push active[i]
				active.splice i, 1
				widths = computeColumnWidths totalWidth, active, handleSize
				changed = yes
	{active: active, collapsed: collapsed, widths: widths}

export class ResizeController
	def constructor opts = {}
		self.columns = opts.columns or []
		self.handleSize = opts.handleSize or 9
		self.totalWidth = opts.totalWidth or 1024
		self.altWidth = no

	def setTotal width
		self.totalWidth = width
		compute!

	def setColumn index, def_
		self.columns[index] = def_
		compute!

	def compute
		self.widths = computeColumnWidths self.totalWidth, self.columns, self.handleSize
		self.widths

	get widths
		self.widths or compute!

	def drag columnIndex, deltaPx
		let next = self.columns[columnIndex]
		let prev = self.columns[columnIndex + 1]
		let newA = (Number(next.width) or 0) + deltaPx
		let newB = (Number(prev.width) or 0) - deltaPx
		let minA = next.min or 0
		let minB = prev.min or 0
		let appliedDelta = deltaPx
		if newA < minA
			appliedDelta = minA - (Number(next.width) or 0)
		if newB < minB
			appliedDelta = Math.min appliedDelta, (Number(prev.width) or 0) - minB
		next.width = (Number(next.width) or 0) + appliedDelta
		prev.width = (Number(prev.width) or 0) - appliedDelta
		compute!
		appliedDelta
