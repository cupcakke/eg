import './env-setup'
import {runAll, results} from './harness'

import './sdf-math.test'
import './spring.test'
import './luminance-contrast.test'
import './shader-invariants.test'
import './functional-layer.test'
import './container-packing.test'
import './shape-packing.test'
import './transitions.test'
import './component-logic.test'
import './leak-stability.test'
import './golden-image.test'
import './quality-dirty.test'

let printer = do(msg) globalThis.console.log msg
runAll(printer).then do(counts)
	globalThis.console.log ""
	globalThis.console.log "————————————————————————————"
	globalThis.console.log "{counts.passed} passed, {counts.failed} failed, {counts.skipped} skipped"
	if counts.failed > 0
		globalThis.console.log "Failures:"
		for f in results.failures
			globalThis.console.log "  ✗ {f.name}"
			globalThis.console.log "    {f.message}"
	globalThis.process.exit(if counts.failed > 0 then 1 else 0)
