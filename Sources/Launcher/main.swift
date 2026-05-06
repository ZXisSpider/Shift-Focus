import Darwin

let realBinary = "/Users/zhouxiang/Codes/Shift-Focus/.build/release/Shift-Focus"

var cargs = CommandLine.arguments.map { strdup($0) }
cargs.append(nil)
execv(realBinary, &cargs)

// execv only returns on error
fatalError("Launcher failed: \(String(cString: strerror(errno)))")
