import {logger} from '../core/logger'
import {titleCased} from './list-row'

tag gk-section
	prop header = ''
	prop footer = ''
	prop style = 'grouped'

	def checkHeaderCase
		if header == ''
			return
		let letters = header.replace(/[^A-Za-z]/g, '')
		if letters.length >= 5 and letters == letters.toUpperCase!
			logger.warnOnce "section-allcaps:{header}", "Section header \"{header}\" is uppercase — supply \"{titleCased(header)}\" instead; GlassKit renders headers in title case"

	get displayHeader
		let trimmed = String(header).trim!
		let letters = trimmed.replace(/[^A-Za-z]/g, '')
		if letters.length >= 5 and letters == letters.toUpperCase!
			titleCased trimmed.toLowerCase!
		else
			trimmed

	def mount
		checkHeaderCase!

	def render
		<self role='group' data-style=style>
			if displayHeader != ''
				<div .gk-section-header role='heading' aria-level='2'> displayHeader
			<div .gk-section-body>
				<slot>
			if footer != ''
				<div .gk-section-footer> footer
