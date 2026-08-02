import {setSelected} from '../a11y/aria'

tag gk-tab-item
	prop icon = null
	prop label = ''
	prop badge = null
	prop role = 'tab'
	prop tabRole = null
	prop dataRole = null

	def render
		let r = dataRole or null
		<self role=(role == 'search' ? 'tab' : role)
			data-role=r
			aria-selected=(self.getAttribute('aria-selected') or 'false')
			tabindex=(self.getAttribute('tabindex') or '-1')>
			if icon != null
				<gk-icon name=icon>
			<slot>
			if label != ''
				<span .gk-label> label
			if badge != null and badge != ''
				<gk-badge> badge
