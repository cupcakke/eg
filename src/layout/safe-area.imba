import {EventBus} from '../core/event-bus'
import {isBrowser} from '../core/env'
import {uid} from '../core/id'

export class SafeAreaManager
	def constructor
		self.bars = []
		self.manual = {top: 0, leading: 0, bottom: 0, trailing: 0}
		self.events = new EventBus
		self.appliedCssVars = no

	get insets
		let result =
			top: self.manual.top
			leading: self.manual.leading
			bottom: self.manual.bottom
			trailing: self.manual.trailing
		for bar in self.bars
			if bar.edge == 'top'
				result.top = Math.max result.top, bar.thickness
			elif bar.edge == 'bottom'
				result.bottom = Math.max result.bottom, bar.thickness
			elif bar.edge == 'leading'
				result.leading = Math.max result.leading, bar.thickness
			elif bar.edge == 'trailing'
				result.trailing = Math.max result.trailing, bar.thickness
		result

	def registerBar edge, thickness = 0, el = null
		let bar = {id: uid('gkb'), edge: edge, thickness: thickness, el: el}
		self.bars.push bar
		changed!
		bar.id

	def updateBar id, thickness
		for bar in self.bars
			if bar.id == id
				if bar.thickness != thickness
					bar.thickness = thickness
					changed!
				return yes
		no

	def unregisterBar id
		let i = self.bars.findIndex(do(b) b.id == id)
		if i >= 0
			self.bars.splice i, 1
			changed!
			yes
		else
			no

	def setManual edge, value
		self.manual[edge] = value
		changed!

	def applyToRoot rootEl = null
		unless isBrowser
			return
		let el = rootEl or globalThis.document.documentElement
		let ins = insets
		el.style.setProperty '--gk-inset-top', "{ins.top}px"
		el.style.setProperty '--gk-inset-leading', "{ins.leading}px"
		el.style.setProperty '--gk-inset-bottom', "{ins.bottom}px"
		el.style.setProperty '--gk-inset-trailing', "{ins.trailing}px"

	def onChanged fn
		self.events.on 'changed', fn

	def changed
		applyToRoot!
		self.events.emit 'changed', insets

	def reset
		self.bars = []
		self.manual = {top: 0, leading: 0, bottom: 0, trailing: 0}
		changed!

export const safeArea = new SafeAreaManager
