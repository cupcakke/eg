const NAV_ITEMS = [
	{id: 'library', icon: 'square.grid', label: 'Library'}
	{id: 'recents', icon: 'clock', label: 'Recents'}
	{id: 'pinned', icon: 'pin', label: 'Pinned'}
	{id: 'shared', icon: 'person.2', label: 'Shared'}
	{id: 'archive', icon: 'archivebox', label: 'Archive'}
]

tag gk-demo-navigation
	prop navSelection = 'library'
	prop tabSelection = 'all'
	prop listSelection = 'row1'
	prop minimized = no

	def render
		<self>
			<gk-section header='Tab Bar' footer='The search tab stays pinned at the trailing edge'>
				<gk-tab-bar tabs=[{id: 'all', icon: 'doc', label: 'All'}, {id: 'images', icon: 'photo', label: 'Images'}, {id: 'docs', icon: 'doc.richtext', label: 'Documents'}]
					selected=tabSelection
					minimizeBehavior='automatic'
					@change=(do(e) tabSelection = e.detail.selected)>
			<gk-section header='Sidebar' footer='Drag the split handle; collapse with the toggle'>
				<gk-sidebar items=NAV_ITEMS selected=navSelection label='Browse' @change=(do(e) navSelection = e.detail.selected)>
					<div style='padding:16px'>
						<strong> "Content pane"
						<p .demo-note> "Selection: {navSelection}"
			<gk-section header='Selectable List' footer='Arrow keys move focus; Enter selects'>
				<gk-list style='inset' selection='single' value=listSelection self.selectionchange=(do(e) listSelection = e.detail.value)>
					<gk-list-row value='row1' title='Foundation' subtitle='Grid, tokens, safe areas' trailing='disclosure'>
					<gk-list-row value='row2' title='Material' subtitle='Regular and clear variants' trailing='disclosure'>
					<gk-list-row value='row3' title='Motion' subtitle='Springs and morphs' trailing='disclosure'>
					<gk-list-row value='row4' title='Diagnostics' subtitle='Audit and live overlays' trailing='detail' detail='8 rules'>
			<gk-section header='Toolbar Overflow' footer='Trailing items fold into the More menu as space runs out'>
				<gk-toolbar label='Document'>
					<gk-toolbar-item icon='chevron.left' label='' aria-label='Back' action='back'>
					<gk-toolbar-item icon='textformat.size' label='Format' action='format'>
					<gk-toolbar-item icon='paintbrush' label='Style' action='style'>
					<gk-toolbar-spacer>
					<gk-toolbar-item icon='tablecells' label='Table' action='table'>
					<gk-toolbar-item icon='chart.bar' label='Chart' action='chart'>
					<gk-toolbar-item icon='text.quote' label='Quote' action='quote'>
					<gk-toolbar-item icon='link' label='Link' action='link'>
					<gk-toolbar-item icon='square.and.arrow.up' label='Share' action='share'>
