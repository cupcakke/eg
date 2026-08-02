import {logger} from '../core/logger'
import {uid} from '../core/id'
import {clamp} from '../core/math'
import {setSelected} from '../a11y/aria'
import {preferences} from '../a11y/preferences'

const SWIPE_COMMIT_RATIO = 0.42
const SWIPE_FLING_VELOCITY = 0.45
const SMALL_WORDS = ['a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of', 'on', 'or', 'per', 'the', 'to', 'vs', 'via']

export def titleCased text
	let words = String(text).trim!.split /\s+/
	let last = words.length - 1
	let out = []
	for word, i in words
		let lower = word.toLowerCase!
		if i > 0 and i < last and SMALL_WORDS.indexOf(lower) >= 0
			out.push lower
		else
			out.push (lower.charAt(0).toUpperCase! + lower.slice(1))
	out.join ' '

tag gk-list-row
	prop title = ''
	prop subtitle = ''
	prop leading = null
	prop trailing = null
	prop value = ''
	prop detail = ''
	prop selected = no
	prop disabled = no
	prop showSeparator = yes
	prop swipeActions = []

	get actionsList
		if typeof swipeActions == 'string'
			let out = []
			for part in swipeActions.split(',')
				let label = part.trim!
				if label.length > 0
					out.push {label: label, action: label.toLowerCase!, destructive: no}
			out
		elif Array.isArray swipeActions
			swipeActions
		else
			[]

	def mount
		self.rowId = uid 'gkr'
		self.actionsEl = null
		self.contentEl = null
		self.drag = null
		self.openAmount = 0

	def unmount
		cancelDrag!

	def selectValue
		if value != null and value != '' then value else title

	def actionWidth
		if self.actionsEl == null
			return 0
		self.actionsEl.offsetWidth

	def cancelDrag
		if self.drag != null
			let move = self.drag.move
			let up = self.drag.up
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
			self.drag = null

	def beginSwipe e
		if disabled or actionsList.length == 0
			return
		if e.pointerType == 'mouse' and e.button != 0
			return
		let st =
			startX: e.clientX
			startY: e.clientY
			lastX: e.clientX
			lastT: Date.now!
			velocity: 0
			axis: null
			base: self.openAmount
		let move = do(ev)
			let dx = ev.clientX - st.startX
			let dy = ev.clientY - st.startY
			if st.axis == null and (Math.abs(dx) > 6 or Math.abs(dy) > 6)
				st.axis = if Math.abs(dx) > Math.abs(dy) then 'h' else 'v'
			if st.axis != 'h'
				return
			let now = Date.now!
			let dt = Math.max 1, now - st.lastT
			st.velocity = st.velocity * 0.7 + ((ev.clientX - st.lastX) / dt) * 0.3
			st.lastX = ev.clientX
			st.lastT = now
			let dir = if preferences.dir == 'rtl' then -1 else 1
			let amount = st.base - dx * dir
			positionSwipe clamp(amount, -24, actionWidth! + 24)
		let up = do(ev)
			globalThis.window.removeEventListener 'pointermove', move
			globalThis.window.removeEventListener 'pointerup', up
			globalThis.window.removeEventListener 'pointercancel', up
			self.drag = null
			if st.axis != 'h'
				return
			let w = actionWidth!
			let dir = if preferences.dir == 'rtl' then -1 else 1
			let fling = st.velocity * dir
			let target = 0
			if fling < -SWIPE_FLING_VELOCITY
				target = w
			elif fling > SWIPE_FLING_VELOCITY
				target = 0
			elif self.openAmount > w * SWIPE_COMMIT_RATIO
				target = w
			settleSwipe target
		st.move = move
		st.up = up
		self.drag = st
		globalThis.window.addEventListener 'pointermove', move
		globalThis.window.addEventListener 'pointerup', up
		globalThis.window.addEventListener 'pointercancel', up

	def positionSwipe amount
		self.openAmount = amount
		if self.contentEl == null
			return
		self.contentEl.style.transition = 'none'
		let dir = if preferences.dir == 'rtl' then 1 else -1
		self.contentEl.style.transform = "translateX({Math.round(amount * dir)}px)"
		if self.actionsEl != null
			let w = actionWidth!
			let reveal = w > 0 ? clamp(amount / w, 0, 1.15) : 0
			self.actionsEl.style.opacity = String(Math.min 1, reveal * 1.4)
			self.actionsEl.style.pointerEvents = if reveal > 0.05 then 'auto' else 'none'

	def settleSwipe target
		self.openAmount = target
		if self.contentEl != null
			let dir = if preferences.dir == 'rtl' then 1 else -1
			self.contentEl.style.transition = 'transform 0.32s cubic-bezier(0.24, 1.24, 0.44, 1)'
			self.contentEl.style.transform = "translateX({Math.round(target * dir)}px)"
		if self.actionsEl != null
			let open = target > 1
			self.actionsEl.style.transition = 'opacity 0.22s ease-out'
			self.actionsEl.style.opacity = open ? '1' : '0'
			self.actionsEl.style.pointerEvents = open ? 'auto' : 'none'
		if target > 1
			self.setAttribute 'data-swipe-open', '1'
		else
			self.removeAttribute 'data-swipe-open'

	def swipeActionClicked e, act
		e.stopPropagation!
		runAction act

	def runAction action
		settleSwipe 0
		let ev = new CustomEvent 'swipeaction', {bubbles: yes, detail: {action: (action.action or action.label), row: selectValue!}}
		self.dispatchEvent ev

	def activate e
		if disabled or self.drag != null
			return
		if self.openAmount > 1
			settleSwipe 0
			return
		setSelected self, yes
		let ev = new CustomEvent 'rowactivate', {bubbles: yes, detail: {value: selectValue!, row: self}}
		self.dispatchEvent ev

	def render
		let acts = actionsList
		let trailingKind = trailing
		if trailingKind == null and (detail != null and detail != '')
			trailingKind = 'detail'
		<self role='row'
			tabindex=-1
			aria-selected=(selected ? 'true' : 'false')
			aria-disabled=(disabled ? 'true' : null)
			data-selected=(selected ? '1' : null)
			data-separator=(showSeparator ? '1' : null)
			@click=activate>
			if acts.length > 0
				<div$actionsEl .gk-swipe-actions>
					for action, i in acts
						let act = action
						<button
							type='button'
							data-destructive=(act.destructive ? '1' : null)
							style=(act.color ? "background:{act.color}" : null)
							@click=(do self.swipeActionClicked(e, act))> act.label
			<div$contentEl .gk-row-content @pointerdown=beginSwipe>
				if leading != null
					<span .gk-row-leading aria-hidden='yes'>
						<gk-icon name=leading>
				<span .gk-row-text>
					<span .gk-row-title> title
					if subtitle != ''
						<span .gk-row-subtitle> subtitle
				if trailingKind == 'disclosure'
					<span .gk-row-disclosure aria-hidden='yes'>
				elif trailingKind == 'detail'
					<span .gk-row-detail> detail
				<slot>
