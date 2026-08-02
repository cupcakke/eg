import {Rect} from './geometry'

export class DirtyTracker
	def constructor
		self.allDirty = yes
		self.settingsDirty = no
		self.shapeRects = new Map
		self.backdropRects = new Map
		self.animDirty = no
		self.dirtyContainers = new Set

	def markAll
		self.allDirty = yes

	def markSettings
		self.settingsDirty = yes

	def markShape containerId, rect
		self.dirtyContainers.add containerId
		markInto self.shapeRects, containerId, rect

	def markBackdrop containerId, rect
		self.dirtyContainers.add containerId
		markInto self.backdropRects, containerId, rect

	def markAnimation active
		self.animDirty = active

	def markInto map, containerId, rect
		if rect == null or rect.isEmpty
			return
		let existing = map.get(containerId)
		if existing
			existing.unionWith rect
		else
			map.set containerId, rect.clone()

	get frameDirty
		self.allDirty or self.settingsDirty or self.animDirty or self.shapeRects.size > 0 or self.backdropRects.size > 0

	def containerDirty containerId
		self.allDirty or self.shapeRects.has(containerId) or self.backdropRects.has(containerId)

	def shapeRectFor containerId
		self.shapeRects.get(containerId) or null

	def backdropRectFor containerId
		self.backdropRects.get(containerId) or null

	def consumeSnapshot outShapes, outBackdrops
		self.shapeRects.forEach do(rect, id)
			outShapes.set id, rect
		self.backdropRects.forEach do(rect, id)
			outBackdrops.set id, rect
		let hadAll = self.allDirty
		let hadSettings = self.settingsDirty
		self.allDirty = no
		self.settingsDirty = no
		self.animDirty = no
		self.shapeRects = new Map
		self.backdropRects = new Map
		self.dirtyContainers = new Set
		[hadAll, hadSettings]

export const dirtyTracker = new DirtyTracker
