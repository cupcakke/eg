tag gk-demo-controls
	prop toggleA = yes
	prop toggleB = no
	prop sliderVal = 42
	prop rangeLo = 20
	prop rangeHi = 70
	prop stepperVal = 3
	prop segmentIdx = 0
	prop pickerIdx = 1
	prop searchText = ''
	prop progressVal = 0.35
	prop textVal = ''
	prop tokens = ['design', 'motion']

	def rangeChanged e
		rangeLo = e.detail.value
		rangeHi = e.detail.valueEnd

	def animateProgress
		let tick = do
			progressVal = progressVal + 0.05
			if progressVal >= 1 then progressVal = 0
			imba.commit!
		progressVal = 0
		self.progressTimer = globalThis.setInterval tick, 240
		globalThis.setTimeout (do globalThis.clearInterval(self.progressTimer)), 5200

	def unmount
		if self.progressTimer then globalThis.clearInterval self.progressTimer

	def render
		<self>
			<gk-section header='Buttons'>
				<div .demo-block>
					<div .demo-row>
						<gk-button label='Bordered' variant='bordered'>
						<gk-button label='Filled' variant='filled'>
						<gk-button label='Tinted' variant='tinted' tint='#5e5ce6'>
						<gk-button label='Plain' variant='plain'>
						<gk-button icon='magnify' label='' aria-label='Search' variant='bordered'>
			<gk-section header='Toggles'>
				<div .demo-block>
					<div .demo-col>
						<gk-toggle checked=toggleA label='Glass refraction' @change=(do(e) toggleA = e.detail.checked)>
						<gk-toggle checked=toggleB kind='button' label='Pin toolbar'>
						<gk-toggle kind='checkbox' label='Include archived results'>
			<gk-section header='Sliders & Steppers' footer='Sliders settle on tick marks within ten points; ranges keep both thumbs'>
				<div .demo-block>
					<div .demo-col>
						<gk-slider value=sliderVal min=0 max=100 ticks=yes label='Intensity' @change=(do(e) sliderVal = e.detail.value)>
						<gk-slider range=yes value=20 valueEnd=70 min=0 max=100 label='Range' @change=(do self.rangeChanged(e))>
						<div .demo-row>
							<gk-stepper value=stepperVal min=0 max=9 label='Quantity' @change=(do(e) stepperVal = e.detail.value)>
							<span .demo-note> "× {stepperVal}"
			<gk-section header='Segmented & Pickers'>
				<div .demo-block>
					<div .demo-col>
						<gk-segmented-control items=['Day', 'Week', 'Month'] selected=segmentIdx label='Scale' @change=(do(e) segmentIdx = e.detail.index)>
						<gk-picker kind='menu' items=['Regular', 'Clear', 'Tinted', 'Solid'] selected=pickerIdx label='Appearance' @change=(do(e) pickerIdx = e.detail.index)>
			<gk-section header='Text & Search'>
				<div .demo-block>
					<div .demo-col>
						<gk-text-field value=textVal placeholder='Project name' label='Name' glass=yes @input=(do(e) textVal = e.detail.value)>
						<gk-search-field value=searchText suggestions=['Glass', 'Gloss', 'Glare', 'Glacier'] placeholder='Filter symbols' @input=(do(e) searchText = e.detail.value)>
			<gk-section header='Progress & Badges'>
				<div .demo-block>
					<div .demo-col>
						<div .demo-row>
							<gk-progress value=progressVal label='Rendering'>
							<gk-progress kind='circular' label='Indexing'>
							<gk-button label='Simulate work' variant='bordered' @activate=animateProgress>
					<div .demo-row>
						<span>
							"Inbox "
							<gk-badge value=3>
						<span>
							"Alerts "
							<gk-badge value=132>
						<span>
							"Muted "
							<gk-badge kind='dot'>
