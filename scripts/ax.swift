// Drives a running macOS app through the Accessibility API, for the
// verify-in-app skill. Build once: xcrun swiftc -O scripts/ax.swift -o .dart_tool/hermes-dev/ax
import AppKit
import ApplicationServices
import Foundation

let usage = """
usage: ax <pid> <command> [args]
  wake                 ask a Flutter app to build its accessibility tree
  texts                visible elements that have a name, one per line
  dump [depth]         the whole tree
  press <text>         press the first element whose name contains <text>
  focus <n>            focus the n-th text field (0-based)
  type <text>          type real key events into the focused app
  key <code>           press one key (36 Return, 53 Escape, 48 Tab)
  wid                  the main window's id, for screencapture -l
"""

let args = CommandLine.arguments
guard args.count >= 3, let pid = pid_t(args[1]) else {
    print(usage)
    exit(2)
}

guard AXIsProcessTrusted() else {
    print("NOT_TRUSTED: give the terminal Accessibility permission")
    exit(3)
}

let app = AXUIElementCreateApplication(pid)

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}

func str(_ e: AXUIElement, _ name: String) -> String {
    guard let v = attr(e, name) else { return "" }
    if let s = v as? String {
        return s
    }
    if let n = v as? NSNumber {
        return n.stringValue
    }
    return ""
}

func children(_ e: AXUIElement) -> [AXUIElement] {
    (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func role(_ e: AXUIElement) -> String {
    str(e, kAXRoleAttribute)
}

func name(_ e: AXUIElement) -> String {
    [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute]
        .map { str(e, $0) }.filter { !$0.isEmpty }.joined(separator: " | ")
}

func frame(_ e: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = attr(e, kAXPositionAttribute) {
        AXValueGetValue(v as! AXValue, .cgPoint, &p)
    }
    if let v = attr(e, kAXSizeAttribute) {
        AXValueGetValue(v as! AXValue, .cgSize, &s)
    }
    return CGRect(origin: p, size: s)
}

func describe(_ f: CGRect) -> String {
    "@\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))"
}

func walk(_ e: AXUIElement, _ visit: (AXUIElement, Int) -> Bool, _ depth: Int = 0) {
    guard visit(e, depth), role(e) != "AXMenuBar" else { return }
    children(e).forEach { walk($0, visit, depth + 1) }
}

func activate() {
    NSRunningApplication(processIdentifier: pid)?.activate()
    usleep(200_000)
}

switch args[2] {
case "wake":
    // Flutter answers neither attribute, but being asked is what builds its
    // tree, and the content shows up only on a later request.
    for _ in 0 ..< 20 {
        for a in ["AXEnhancedUserInterface", "AXManualAccessibility"] {
            AXUIElementSetAttributeValue(app, a as CFString, kCFBooleanTrue)
        }
        var deepest = 0
        walk(app) { _, depth in
            deepest = max(deepest, depth)
            return true
        }
        if deepest > 4 {
            print("ok")
            exit(0)
        }
        usleep(500_000)
    }
    print("no content after 10 s")
    exit(1)
case "texts":
    walk(app) { e, _ in
        let n = name(e), f = frame(e)
        if !n.isEmpty, f.height > 3 {
            print(role(e), "\"\(n.replacingOccurrences(of: "\n", with: " ").prefix(100))\"", describe(f))
        }
        return true
    }
case "dump":
    let max = args.count > 3 ? Int(args[3]) ?? 40 : 40
    walk(app) { e, depth in
        let n = name(e)
        print(String(repeating: "  ", count: depth) + role(e) + (n.isEmpty ? "" : " \"\(n.prefix(120))\"") + " " + describe(frame(e)))
        return depth < max
    }
case "press":
    var hit: AXUIElement?
    walk(app) { e, _ in
        if hit == nil, name(e).localizedCaseInsensitiveContains(args[3]) {
            hit = e
        }
        return hit == nil
    }
    guard let e = hit else { print("NOT_FOUND"); exit(1) }
    let r = AXUIElementPerformAction(e, kAXPressAction as CFString)
    print(r == .success ? "pressed" : "press failed \(r.rawValue)", role(e), name(e).prefix(60))
case "focus":
    var fields: [AXUIElement] = []
    walk(app) { e, _ in
        if role(e) == "AXTextField" || role(e) == "AXTextArea" {
            fields.append(e)
        }
        return true
    }
    let i = Int(args[3]) ?? 0
    guard i < fields.count else { print("only \(fields.count) text fields"); exit(1) }
    AXUIElementSetAttributeValue(fields[i], kAXFocusedAttribute as CFString, kCFBooleanTrue)
    print("focused", describe(frame(fields[i])))
case "type":
    activate()
    for unit in args[3].utf16 {
        var c = unit
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
            e?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
            e?.post(tap: .cghidEventTap)
        }
        usleep(15000)
    }
    print("typed")
case "key":
    activate()
    let k = CGKeyCode(args[3]) ?? 36
    for down in [true, false] {
        CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)?.post(tap: .cghidEventTap)
    }
    print("key", k)
case "wid":
    let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    let main = windows.first { w in
        (w[kCGWindowOwnerPID as String] as? Int32) == pid
            && (w[kCGWindowLayer as String] as? Int) == 0
            && ((w[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0) > 200
    }
    guard let id = main?[kCGWindowNumber as String] else { print("NOT_FOUND"); exit(1) }
    print(id)
default:
    print(usage)
    exit(2)
}
