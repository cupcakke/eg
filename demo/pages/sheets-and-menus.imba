const MENU_ITEMS = [
	{title: 'New Tab', icon: 'plus', shortcut: '⌘T', action: 'new-tab'}
	{title: 'New Window', icon: 'macwindow', action: 'new-window'}
	{separator: yes}
	{title: 'Share…', icon: 'square.and.arrow.up', action: 'share', submenu: [
		{title: 'Mail', action: 'share-mail'}
		{title: 'Messages', action: 'share-messages'}
		{title: 'Copy Link', action: 'share-link'}
	]}
	{separator: yes}
	{title: 'Move to Trash', icon: 'trash', destructive: yes, shortcut: '⌫', action: 'trash'}
]

tag gk-demo-sheets
	prop menuOpen = no
	prop popOpen = no
	prop sheetOpen = no
	prop alertOpen = no
	prop actionOpen = no
	prop lastAction = '—'

	def tell e
		let d = e.detail or {}
		lastAction = String(d.action or d.title or (d.item ? d.item.action : null) or d.index or '—')
		menuOpen = no
		actionOpen = no
		imba.commit!

	def render
		<self @select=tell>
			<gk-section header='Menus & Popovers'>
				<div .demo-block>
					<div .demo-row>
						<gk-button$menuBtn label='File menu' variant='bordered' @activate=(do menuOpen = !menuOpen)>
						<gk-button$popBtn label='Popover' variant='bordered' @activate=(do popOpen = !popOpen)>
					<div .demo-note style='margin-top:10px'> "Last action: {lastAction}"
				if menuOpen
					<gk-menu items=MENU_ITEMS anchorel=self.menuBtn label='File' @close=(do menuOpen = no)>
				if popOpen
					<gk-popover open=yes anchorel=self.popBtn label='Quick settings' @close=(do popOpen = no)>
						<div .demo-col style='min-width:220px'>
							<strong> "Quality"
							<gk-segmented-control items=['Auto', 'High', 'Low'] selected=0 label='Quality mode'>
							<gk-toggle label='Live backdrop' checked=yes>
			<gk-section header='Context Menu' footer='Right-click or long-press the zone'>
				<div .demo-block style='text-align:center;padding:40px;border:1px dashed rgb(128 128 128 / .5);border-radius:12px'>
					"Right-click or long-press here"
					<gk-context-menu items=MENU_ITEMS>
			<gk-section header='Sheets & Alerts'>
				<div .demo-block>
					<div .demo-row>
						<gk-button label='Open sheet' variant='filled' @activate=(do sheetOpen = true)>
						<gk-button label='Action sheet' variant='bordered' @activate=(do actionOpen = true)>
						<gk-button label='Alert' variant='bordered' @activate=(do alertOpen = true)>
				<gk-sheet open=sheetOpen detents=['medium', 'large'] label='Inspector' @close=(do sheetOpen = false)>
					<div .demo-col style='padding:8px 4px'>
						<h3 style='margin:0'> "Layer inspector"
						<gk-list style='plain' selection='single' value='l0'>
							<gk-list-row value='l0' title='Glass layer' subtitle='Blur 28 · refraction 1.45' leading='square.stack'>
							<gk-list-row value='l1' title='Functional layer' subtitle='Focus rings, indicators' leading='scope'>
							<gk-list-row value='l2' title='Content layer' subtitle='Glyphs and labels' leading='textformat'>
				<gk-action-sheet open=actionOpen label='Document actions' actions=[{title: 'Duplicate', action: 'duplicate'}, {title: 'Rename…', action: 'rename'}, {title: 'Delete', action: 'delete', destructive: yes}, {title: 'Cancel', action: 'cancel', cancel: yes}] @close=(do actionOpen = false)>
				<gk-alert open=alertOpen title='Revert document?' message='All unsaved changes since the last checkpoint will be lost. This cannot be undone.' actions=[{title: 'Cancel', action: 'cancel', cancel: yes}, {title: 'Revert', action: 'revert', destructive: yes}] @close=(do alertOpen = false)>
