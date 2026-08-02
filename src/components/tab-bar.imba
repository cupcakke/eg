import {applyGlassEffect, removeGlassEffect} from '../material/glass-effect'
import {Glass} from '../material/glass'
import {Shape} from '../material/shape'
import {RovingGroup} from '../a11y/keyboard-nav'
import {bus} from '../core/event-bus'
import {uid} from '../core/id'
import {preferences} from '../a11y/preferences'

tag gk-tab-bar
	prop tabs = []
	prop selected = null
	prop minimizeBehavior = 'never'
	prop searchTab = yes
	prop adaptiveSidebarAt = null
	prop label = 'Tabs'

	def mount
		self.__gkOwnsGlassSurface = yes
		self.minimized = no
		self.lastScrollTop = 0
		self.scrollDirection = 0
		self.barId = uid 'gktb'
		self.glassHandle = applyGlassEffect self, Glass.regular.clone!, Shape.capsule!,
			namespace: 'tabs'
			glassId: 'bar:' + self.barId
			transition: 'materialize'
		self.group = new RovingGroup self, 'button[data-gk-tab]', {orientation: 'horizontal', onActivate: do(el) self.activateTabEl(el)}
		self.group.attach!
		self.scrollUnsub = bus.on 'scroll:updated', do(payload) self.handleScroll payload
		bindSelectionGlass!
		if adaptiveSidebarAt != null
			self.adaptiveResize = do self.checkAdaptive!
			globalThis.window.addEventListener 'resize', self.adaptiveResize
			checkAdaptive!

	def unmount
		self.group.detach!
		self.scrollUnsub!
		if self.glassHandle
			self.glassHandle.dispose!
			self.glassHandle = null
		releaseSelectionGlass!
		if self.adaptiveResize
			globalThis.window.removeEventListener 'resize', self.adaptiveResize

	def tabsList
		let list = typeof tabs == 'string' ? JSON.parse(tabs or '[]') : tabs
		list or []

	def checkAdaptive
		if adaptiveSidebarAt == null
			return
		let wide = globalThis.window.innerWidth >= Number(adaptiveSidebarAt)
		if wide != self.wasWide
			self.wasWide = wide
			self.dispatchEvent new CustomEvent('adaptivechange', {bubbles: yes, detail: {wide: wide}})

	def handleScroll payload
		if minimizeBehavior == 'never'
			return
		let top = payload.top
		let delta = top - self.lastScrollTop
		self.lastScrollTop = top
		if Math.abs(delta) < 4
			return
		let dir = delta > 0 ? 1 : -1
		if minimizeBehavior == 'onScrollDown' and top > 12
			setMinimized dir == 1
		elif minimizeBehavior == 'onScrollUp'
			setMinimized dir == -1

	def setMinimized value
		if self.minimized == value
			return
		self.minimized = value
		if value
			self.setAttribute 'data-minimized', '1'
		else
			self.removeAttribute 'data-minimized'

	def activateTabEl el
		let id = el.getAttribute 'data-gk-tab-id'
		selectTab id

	def selectTab id
		if selected != id
			selected = id
			bindSelectionGlass!
			self.dispatchEvent new CustomEvent 'change', {bubbles: yes, detail: {selected: id}}

	def bindSelectionGlass
		releaseSelectionGlass!
		globalThis.requestAnimationFrame do
			let el = self.querySelector "button[data-gk-tab-id='{selected}']"
			if el
				self.selectionGlass = applyGlassEffect el, Glass.regular.interactive(yes), Shape.capsule!,
					namespace: 'tabs'
					glassId: 'selection:' + self.barId
					transition: 'matchedGeometry'

	def releaseSelectionGlass
		if self.selectionGlass
			self.selectionGlass.dispose!
			self.selectionGlass = null

	def onSearchActivate
		self.dispatchEvent new CustomEvent 'searchtab', {bubbles: yes}

	def render
		let list = tabsList!
		<self role='tablist' aria-label=label data-separated-search=(searchTab ? '1' : null)>
			for tab in list
				<button data-gk-tab data-gk-tab-id=tab.id role='tab'
					aria-selected=(selected == tab.id ? 'true' : 'false')
					tabindex=(selected == tab.id ? 0 : -1)
					@click=(do selectTab(tab.id))>
					if tab.icon
						<gk-icon name=tab.icon>
					<span .gk-label> tab.label
			if searchTab
				<span .gk-search-divider aria-hidden='yes'>
				<button data-gk-tab data-gk-tab-id='__search' role='tab' data-role='search' aria-label='Search' aria-selected=(selected == '__search' ? 'true' : 'false') tabindex=(selected == '__search' ? 0 : -1) @click=onSearchActivate>
					<gk-icon name='search'>
					<span .gk-label> 'Search'
