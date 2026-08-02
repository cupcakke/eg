import {settings} from '../core/settings'
import {safeArea} from './safe-area'

export class WindowFrameModel
	def constructor el, radius = null
		self.el = el
		self.radius = radius

	def attach
		let r = self.radius != null ? self.radius : settings.windowCornerRadius
		self.el.setAttribute 'data-gk-container-radius', String(r)
		self.el.style.setProperty '--gk-window-radius', "{r}px"
		let ins = safeArea.insets
		self.el.style.paddingTop = 'var(--gk-inset-top, 0px)'
		self.el.style.paddingBottom = 'var(--gk-inset-bottom, 0px)'
		self.el.style.paddingInlineStart = 'var(--gk-inset-leading, 0px)'
		self.el.style.paddingInlineEnd = 'var(--gk-inset-trailing, 0px)'

tag gk-window-frame
	prop radius = null

	def mount
		self.frameModel = new WindowFrameModel self, (radius == null ? null : Number(radius))
		self.frameModel.attach!
		self.setAttribute 'data-gk-window-frame', ''

	get model
		self.frameModel

	<self>
		<slot>
