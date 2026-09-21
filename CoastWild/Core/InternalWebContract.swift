import Foundation

public enum InternalWebContract {
    public static let usesDedicatedWebViewConfiguration = true
    public static let injectsBusinessBootstrap = false
    public static let messageNames = ["newTppClose"]

    public static func visibilityJavaScript(isVisible: Bool) -> String {
        "innerWebShow(\"\(isVisible ? "1" : "0")\");"
    }
}
