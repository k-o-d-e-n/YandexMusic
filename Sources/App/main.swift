import Foundation
import ConsoleKit

final class MultiThreadTerminal: Console {
    let base: Terminal = Terminal()
    let lock: NSRecursiveLock = NSRecursiveLock()

    var userInfo: [AnyHashable: Any] {
        get {
            defer { lock.unlock() }
            lock.lock()
            return base.userInfo
        }
        set {
            lock.lock()
            base.userInfo = newValue
            lock.unlock()
        }
    }
    public var size: (width: Int, height: Int) { base.size }

    public func clear(_ type: ConsoleClear) { base.clear(type) }
    public func input(isSecure: Bool) -> String { base.input(isSecure: isSecure) }
    public func output(_ text: ConsoleText, newLine: Bool) { base.output(text, newLine: newLine) }
    public func report(error: String, newLine: Bool) { base.report(error: error, newLine: newLine) }
}

do {
    var input = CommandInput(arguments: CommandLine.arguments)
    let signature = try Application.Signature(from: &input)

    let application = Application(signature: signature)
    let console = MultiThreadTerminal()

    try application.run(in: console)
} catch CommandError.missingRequiredArgument("client") {
    print("Required argument 'client' is missed. Usage: <executable> <CLIENT_ID[:CLIENT_SECRET]> [--options]")
} catch {
    throw error
}
