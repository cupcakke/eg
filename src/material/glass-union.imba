import {uid} from '../core/id'

export class UnionGroup
	prop id
	prop namespace

	def constructor id, namespace
		self.id = id
		self.namespace = namespace
		self.key = "{namespace}::{id}"
		self.members = []
		self.spacing = 0

	def addMember entry
		if self.members.indexOf(entry) < 0
			self.members.push entry

	def removeMember entry
		let i = self.members.indexOf entry
		if i >= 0
			self.members.splice i, 1

	get size
		self.members.length

	def maxPairDistance
		let maxD = 0
		for i in [0 ... self.members.length]
			for j in [i + 1 ... self.members.length]
				let a = self.members[i].rectCss
				let b = self.members[j].rectCss
				if a == null or b == null
					continue
				let d = a.surfaceDistanceTo b
				if d > maxD
					maxD = d
		maxD

	def computeSpacing baseSpacing
		let need = maxPairDistance! / 2 + 40
		self.spacing = Math.max baseSpacing, Math.ceil(need)
		self.spacing

export class UnionRegistry
	def constructor
		self.groups = new Map

	def groupFor unionId, namespace
		let key = "{namespace}::{unionId}"
		let g = self.groups.get key
		unless g
			g = new UnionGroup unionId, namespace
			self.groups.set key, g
		g

	def removeEmpty
		let dead = []
		self.groups.forEach do(g, key)
			if g.size == 0
				dead.push key
		for key in dead
			self.groups.delete key

	get groupCount
		self.groups.size

	def clear
		self.groups.clear
