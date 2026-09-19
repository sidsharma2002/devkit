import Cocoa

// Disable stdout buffering so logs appear immediately in LaunchAgent log file
setbuf(stdout, nil)
setbuf(stderr, nil)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
