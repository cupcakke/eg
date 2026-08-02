import {announce} from '../a11y/aria'
import {setExpanded} from '../a11y/aria'
import {uid} from '../core/id'
import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'

tag gk-search-field
	prop value = ''
	prop placeholder = 'Search'
	prop label = 'Search'
	prop suggestions = []
	prop glass = yes
	prop showButton = no

	def mount
		self.inputEl = null
		self.open = no
		self.activeIndex = -1
		self.listId = uid 'gksf'
		if glass
			self.glassHandle = applyGlassEffect self, Glass.regular.interactive(yes), Shape.rect(cornerRadius: 11),
				namespace: 'fields'
				transition: 'materialize'

	def unmount
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null

	def suggestionsList
		if typeof suggestions == 'string'
			suggestions.split(',').map do(s) s.trim!
		else
			suggestions

	def matches
		let list = suggestionsList!
		let q = String(value).toLowerCase!
		if q.length == 0
			list
		else
			list.filter do(s) s.toLowerCase!.indexOf(q) >= 0

	def setValue v, commit = no
		value = v
		self.setAttribute 'data-has-value', (String(v).length > 0 ? '1' : '0')
		if commit
			closeList!
		let type = commit ? 'change' : 'input'
		self.dispatchEvent new CustomEvent(type, {bubbles: yes, detail: {value: v}})

	def clearAll
		setValue '', yes
		announce 'Search cleared'
		if self.inputEl
			self.inputEl.focus!

	def inputChanged e
		setValue e.target.value
		openList!

	def chooseSuggestion e, item
		e.preventDefault!
		setValue item, yes

	def openList
		if matches!.length > 0
			self.open = yes
			setExpanded self, yes

	def closeList
		self.open = no
		self.activeIndex = -1
		setExpanded self, no

	def onKeydown e
		let list = matches!
		if e.key == 'ArrowDown'
			e.preventDefault!
			openList!
			self.activeIndex = Math.min list.length - 1, self.activeIndex + 1
		elif e.key == 'ArrowUp'
			e.preventDefault!
			self.activeIndex = Math.max -1, self.activeIndex - 1
		elif e.key == 'Enter'
			if self.open and self.activeIndex >= 0
				e.preventDefault!
				setValue list[self.activeIndex], yes
			else
				self.dispatchEvent new CustomEvent('search', {bubbles: yes, detail: {value: value}})
		elif e.key == 'Escape'
			if self.open
				e.preventDefault!
				closeList!
			else
				clearAll!

	def render
		let list = matches!
		<self role='search' aria-expanded=(self.open ? 'true' : 'false') data-open=(self.open ? '1' : null) data-has-value=(String(value).length > 0 ? '1' : '0')>
			<gk-icon name='search' scale='small' aria-hidden='yes'>
			<input$inputEl type='search' value=value placeholder=placeholder aria-label=label role='searchbox' aria-autocomplete='list' aria-controls=self.listId
				@input=(do self.inputChanged(e))
				@keydown=onKeydown
				@focus=(do openList!)
				@blur=(do globalThis.setTimeout((do closeList!), 120))>
			<button .gk-clear aria-label='Clear search' tabindex='-1' @pointerdown=(do(e) e.preventDefault!) @click=clearAll> '×'
			if self.open and list.length > 0
				<div .gk-suggestions role='listbox' id=self.listId aria-label='Suggestions'>
					for item, i in list
						<div role='option' aria-selected=(i == self.activeIndex ? 'true' : 'false') data-active=(i == self.activeIndex ? '1' : null)
							@pointerdown=(do self.chooseSuggestion(e, item))>
							item
