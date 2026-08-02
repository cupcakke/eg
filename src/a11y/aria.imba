import {isBrowser} from '../core/env'
import {uid} from '../core/id'

let liveRegionPolite = null
let liveRegionAssertive = null

def ensureLiveRegion kind
	if !isBrowser
		return null
	let doc = globalThis.document
	if kind == 'polite'
		if liveRegionPolite == null
			liveRegionPolite = doc.createElement 'div'
			liveRegionPolite.setAttribute 'aria-live', 'polite'
			liveRegionPolite.setAttribute 'role', 'status'
			liveRegionPolite.className = 'gk-visually-hidden'
			liveRegionPolite.setAttribute 'data-gk-live', 'polite'
			doc.body.appendChild liveRegionPolite
		return liveRegionPolite
	if liveRegionAssertive == null
		liveRegionAssertive = doc.createElement 'div'
		liveRegionAssertive.setAttribute 'aria-live', 'assertive'
		liveRegionAssertive.setAttribute 'role', 'alert'
		liveRegionAssertive.className = 'gk-visually-hidden'
		liveRegionAssertive.setAttribute 'data-gk-live', 'assertive'
		doc.body.appendChild liveRegionAssertive
	liveRegionAssertive

export def announce message, politeness = 'polite'
	let region = ensureLiveRegion politeness
	if region
		region.textContent = ''
		globalThis.setTimeout (do region.textContent = message), 30

export def setRole el, role
	el.setAttribute 'role', role
	el

export def setLabel el, label
	if label != null and label != ''
		el.setAttribute 'aria-label', label
	el

export def labelBy el, ids
	el.setAttribute 'aria-labelledby', ids
	el

export def describeBy el, text
	if isBrowser
		let id = uid 'gkdesc'
		let span = globalThis.document.createElement 'span'
		span.id = id
		span.className = 'gk-visually-hidden'
		span.textContent = text
		el.appendChild span
		el.setAttribute 'aria-describedby', id
	el

export def setExpanded el, value
	el.setAttribute 'aria-expanded', (if value then 'true' else 'false')

export def setPressed el, value
	el.setAttribute 'aria-pressed', (if value then 'true' else 'false')

export def setChecked el, value
	el.setAttribute 'aria-checked', (if value isa String then value else (if value then 'true' else 'false'))

export def setSelected el, value
	el.setAttribute 'aria-selected', (if value then 'true' else 'false')

export def setDisabled el, value
	if value
		el.setAttribute 'aria-disabled', 'true'
		if el.hasAttribute and el.tagName == 'BUTTON'
			el.setAttribute 'disabled', ''
	else
		el.removeAttribute 'aria-disabled'
		if el.hasAttribute and el.tagName == 'BUTTON'
			el.removeAttribute 'disabled'

export def setCurrent el, value
	let text = if typeof value == 'string' then value else (if value then 'true' else 'false')
	el.setAttribute 'aria-current', text

export def setValueNow el, value, min = 0, max = 100, text = null
	el.setAttribute 'role', el.getAttribute('role') or 'slider'
	el.setAttribute 'aria-valuemin', String min
	el.setAttribute 'aria-valuemax', String max
	el.setAttribute 'aria-valuenow', String Math.round(value * 100) / 100
	if text != null
		el.setAttribute 'aria-valuetext', text
