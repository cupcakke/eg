import {announce} from '../a11y/aria'
import {clamp} from '../core/math'

const DIGIT_HEIGHT_EM = 1.0

tag gk-badge
	prop value = 0
	prop cap = 99
	prop label = null
	prop kind = 'count'
	prop showZero = no
	prop maxDigits = 3

	get display
		if kind == 'dot'
			return ''
		let n = Math.floor Number(value)
		if isNaN n
			return String value
		if n > cap
			return "{cap}+"
		String n

	get hidden
		kind != 'dot' and Number(value) == 0 and !showZero

	def announceChange prev, next
		if label != null and prev != next
			announce "{label}: {displayFor(next)}"

	def displayFor v
		let n = Math.floor Number(v)
		if isNaN n
			return String v
		if n > cap then "{cap}+" else String(n)

	def valueDidSet next, prev
		announceChange prev, next

	def render
		let text = display
		<self role='status'
			aria-label=(label or (kind == 'dot' ? 'Notification' : "{display} unread"))
			data-kind=kind
			data-hidden=(hidden ? '1' : null)>
			if kind == 'dot'
				<span .gk-badge-dot aria-hidden='yes'>
			elif text.length > 1
				for ch, i in text.split('')
					<span .gk-badge-col key="col{i}">
						if ch >= '0' and ch <= '9'
							<span .gk-badge-strip style="transform:translateY({-Number(ch) * DIGIT_HEIGHT_EM}em)">
								for d in [0 ... 10]
									<span .gk-badge-digit> d
						else
							<span .gk-badge-suffix> ch
			else
				<span .gk-badge-single> text
