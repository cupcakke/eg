import '../src/index'
import {GlassKit} from '../src/index'
import {ProceduralBackdrop} from './procedural'
import {isBrowser} from '../src/core/env'
import './pages/overview'
import './pages/controls'
import './pages/navigation'
import './pages/morphing'
import './pages/sheets-and-menus'
import './pages/media-background'
import './pages/icons'
import './pages/accessibility'
import './pages/performance'

export const ROUTES = [
	{path: 'overview', title: 'Overview'}
	{path: 'controls', title: 'Controls'}
	{path: 'navigation', title: 'Navigation'}
	{path: 'morphing', title: 'Morphing & Unions'}
	{path: 'sheets-and-menus', title: 'Sheets & Menus'}
	{path: 'media-background', title: 'Live Backgrounds'}
	{path: 'icons', title: 'App Icons'}
	{path: 'accessibility', title: 'Accessibility'}
	{path: 'performance', title: 'Performance'}
]

export const demoState = {backdrop: null, currentRoute: 'overview'}

tag gk-demo-app
	prop route = 'overview'

	def mount
		self.onHash = do syncRoute!
		globalThis.window.addEventListener 'hashchange', self.onHash
		syncRoute!

	def unmount
		globalThis.window.removeEventListener 'hashchange', self.onHash

	def syncRoute
		let hash = globalThis.location.hash or ''
		let path = hash.replace(/^#\/?/, '')
		let found = no
		for r in ROUTES
			if r.path == path
				found = yes
		if !found then path = 'overview'
		if path != route
			route = path
			demoState.currentRoute = path
		imba.commit!

	def navTitle
		for r in ROUTES
			if r.path == route
				return r.title
		'GlassKit'

	def render
		<self>
			<div .demo-top>
				<gk-toolbar label='Demo toolbar'>
					<gk-toolbar-item icon='sparkles' label='GlassKit' action='home' @activate=(do globalThis.location.hash = '/overview')>
					<gk-toolbar-spacer>
					<strong> navTitle!
					<gk-toolbar-spacer>
					<gk-toolbar-item icon='magnify' label='Search' action='search'>
			<div .demo-body>
				<nav .demo-nav aria-label='Demo pages'>
					<div .demo-nav-list>
						for r in ROUTES
							<a key=r.path href="#/{r.path}" data-active=(route == r.path ? '1' : null)> r.title
				<main .demo-main key=route .demo-route-enter>
					if route == 'controls'
						<gk-demo-controls>
					elif route == 'navigation'
						<gk-demo-navigation>
					elif route == 'morphing'
						<gk-demo-morphing>
					elif route == 'sheets-and-menus'
						<gk-demo-sheets>
					elif route == 'media-background'
						<gk-demo-media-background>
					elif route == 'icons'
						<gk-demo-icons>
					elif route == 'accessibility'
						<gk-demo-accessibility>
					elif route == 'performance'
						<gk-demo-performance>
					else
						<gk-demo-overview>

export def bootDemo
	unless isBrowser
		return no
	GlassKit.mount globalThis.document.body, {debug: no}
	let backdrop = new ProceduralBackdrop 'mesh'
	backdrop.attach GlassKit.renderer
	backdrop.start!
	demoState.backdrop = backdrop
	imba.mount <gk-demo-app>, globalThis.document.body
	yes

bootDemo!
