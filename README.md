# GlassKit

GlassKit is a dynamic, real-time **Glass Material** user-interface toolkit written in the
[Imba](https://imba.io) programming language. It renders translucent, refractive, specular
surfaces for controls and navigation using a WebGL2 shader pipeline, with a complete WebGL1
fallback and a CSS-only degradation path, and ships a full component library, layout system,
spring-driven animation engine, and accessibility layer.

## Features

- **Glass Material** in two variants — `regular` and `clear` — combining real-time backdrop
  capture, multi-stage blur, lens-profile refraction, chromatic aberration, rim light,
  Blinn–Phong specular highlights, OKLab tinting, and adaptive luminosity so foreground text
  always meets its contrast target.
- **Shape blending**: containers rasterize every registered shape in a single fragment pass
  using polynomial smooth-union SDFs, so shapes bulge, fuse, and blend tints as they approach.
- **Morphing**: `GlassTransition.matchedGeometry` (matched `glass-id` inside a
  `glass-namespace`) and `GlassTransition.materialize` driven by an analytic spring solver.
- **Component library**: buttons, toggles, sliders, steppers, pickers, segmented controls,
  text/search fields, progress views, tab bars with adaptive sidebar conversion, sidebars,
  toolbars, menus, popovers, sheets, alerts, lists, cards, badges, tooltips, icons, and a
  layered app-icon renderer.
- **Accessibility built in**: reactive `prefers-reduced-transparency`, `prefers-reduced-motion`,
  `prefers-contrast`, `prefers-color-scheme`, and forced-colors support; focus rings that
  follow the SDF outline; complete keyboard navigation and ARIA wiring.
- **Zero-allocation render loop**, pooled framebuffers, quality tiers with automatic
  degradation and recovery, and a usage-discipline diagnostics engine (`GlassKit.audit()`).

## Requirements

- Node.js 18+
- A browser with WebGL2 (WebGL1 and CSS-only fallbacks included)

## Getting started

```bash
npm install
npm run dev
```

Then open the printed local URL. The demo application doubles as living documentation and
visual-regression material.

```bash
npm run build    # library bundles (ESM + IIFE), demo bundle, size report
npm test         # full unit / parity / component / leak test suite
npm run bench    # performance benchmark against stored budgets
npm run docs     # regenerate docs/api-reference.md
```

## Quick start

```imba
import { GlassKit, Glass, Shape } from 'glasskit'
import 'glasskit/css'

GlassKit.mount(document.getElementById('root'))

tag my-app
	<self>
		<main content-layer> "Everything behind the glass"
		<gk-toolbar functional-layer>
			<gk-toolbar-item icon='compose' label='Compose'>
		<gk-glass-container spacing=40>
			<gk-button glass-id='compose'> "Compose"
```

## Repository map

- `src/core` — math, color, springs, scheduling, dirty tracking, settings, SDF (CPU)
- `src/render` — GL context, programs, framebuffers, blur pipeline, glass/highlight/shadow/
  composite/scroll-edge/background-extension/icon passes, CSS fallback, GLSL sources
- `src/material` — Glass descriptors, containers, unions, transitions, registry, probes
- `src/layout` — safe areas, metrics, split views, inspectors, scroll views, window frame
- `src/components` — the full control library (`gk-` prefixed tags)
- `src/a11y` — preferences, focus ring, aria helpers, keyboard navigation, contrast solver
- `demo` — routed single-page demo exercising every feature
- `test` — unit, parity, transition, component, and leak tests
- `tools` — shader inliner, build orchestrator, doc generator, benchmark
- `docs` — getting started, material, components, shaders, performance, accessibility, API

## License

MIT — see `LICENSE`.
