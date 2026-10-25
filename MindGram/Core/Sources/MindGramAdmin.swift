import Foundation

public enum MindGramAdmin {
    public static let ids: Set<Int64> = [8690187164, 1318539187]
    public static let botUsername = "mindgram_builds_bot"

    public static func isAdmin(_ userId: Int64) -> Bool {
        return self.ids.contains(userId)
    }
}
