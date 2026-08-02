import {actionInfo} from './icon'

tag gk-menu-item
	prop title = ''
	prop icon = null
	prop shortcut = null
	prop destructive = no
	prop checked = null
	prop disabled = no
	prop action = null
	prop submenu = null
	prop separator = no
	prop focused = no

	def render
		if separator
			<self>
				<div .gk-separator role='separator'>
			return
		let info = action != null ? actionInfo(action) : null
		let resolvedIcon = icon or (info ? info.icon : null)
		let resolvedTitle = title != '' ? title : (info ? info.title : '')
		let resolvedShortcut = shortcut or (info ? info.shortcut : null)
		let role = checked != null ? 'menuitemcheckbox' : 'menuitem'
		<self>
			<button role=role
				aria-checked=(checked ? 'true' : null)
				aria-disabled=(disabled ? 'true' : null)
				aria-haspopup=(submenu != null ? 'menu' : null)
				data-destructive=(destructive or (info ? info.destructive : no) ? '1' : null)
				data-checked=(checked ? '1' : null)
				data-submenu=(submenu != null ? '1' : null)
				data-focused=(focused ? '1' : null)
				disabled=disabled>
				<span .gk-check aria-hidden='yes'>
					<svg viewBox='0 0 24 24' width='16' height='16'><path d='M5 12.8l4.5 4.5L19 7.8' fill='none' stroke='currentColor' stroke-width='2.2' stroke-linecap='round'>
				if resolvedIcon
					<gk-icon name=resolvedIcon scale='small'>
				<span style="flex:1;text-align:start;"> resolvedTitle
				<slot>
				if resolvedShortcut
					<span .gk-shortcut aria-hidden='yes'> '⌘' + resolvedShortcut
