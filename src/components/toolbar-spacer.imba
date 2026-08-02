tag gk-toolbar-spacer
	prop fixed = no
	prop size = 8

	def render
		<self role='separator' aria-hidden='true' style=(fixed ? "flex:none;width:{Number(size) or 8}px" : "flex:1;min-width:{Number(size) or 8}px")>
