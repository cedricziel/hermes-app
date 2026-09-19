// Prints the on-screen window number of the first normal window owned by the
// given process ID, for `screencapture -l`. Run with: xcrun swift window-id.swift <pid>
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: window-id.swift <pid>\n".utf8))
    exit(2)
}

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows
    where (window[kCGWindowOwnerPID as String] as? Int32) == pid
    && (window[kCGWindowLayer as String] as? Int) == 0
{
    print(window[kCGWindowNumber as String] as? Int ?? 0)
    exit(0)
}

FileHandle.standardError.write(Data("no on-screen window for pid \(pid)\n".utf8))
exit(1)
