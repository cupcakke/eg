let consoleRef = globalThis.console

if consoleRef and typeof consoleRef.warn == 'function'
	consoleRef.warn = do(msg) null
