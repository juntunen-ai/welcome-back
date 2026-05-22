import Foundation

/// Drop-in replacement for `print` that compiles to nothing in release builds.
/// Use `dprint(...)` everywhere you would use `print(...)` for debug-only logging.
@inline(__always)
func dprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
#endif
}
