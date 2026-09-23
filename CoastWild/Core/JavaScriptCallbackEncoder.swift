import Foundation

public enum JavaScriptCallbackEncoder {
    public static func backgroundLoginSuccess(_ value: JSONValue) throws -> String { try jsonCallback("backgroundLoginSuccess", value) }
    public static func closeInternalWeb() -> String { "newTppClose();" }
    public static func innerWebShow(isVisible: Bool) -> String { "innerWebShow(\"\(isVisible ? "1" : "0")\");" }

    private static func jsonCallback(_ function: String, _ value: JSONValue) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value.foundationObject, options: [.sortedKeys, .fragmentsAllowed])
        guard let json = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let argumentData = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
        guard let argument = String(data: argumentData, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        return "\(function)(\(argument));"
    }
}

public enum AppLifecycleState: String, Sendable { case resumed, paused }
public enum BridgeEventEncoder {
    public static func lifecycle(_ state: AppLifecycleState) -> String {
        "window.dispatchEvent(new CustomEvent(\"AppLifecycleState\",{detail:{result:\"\(state.rawValue)\"}}));"
    }
    public static func keyboard(height: Double, duration: Double) -> String {
        "window.dispatchEvent(new CustomEvent(\"KeyboardInset\",{detail:{height:\(number(height)),duration:\(number(duration))}}));"
    }
    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
