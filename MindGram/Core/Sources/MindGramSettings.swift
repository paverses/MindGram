import Foundation

/// A MindGram feature switch. Every switch is off until the user turns it on in Settings > MindGram.
public enum MindGramToggle: String, CaseIterable {
    // Профиль
    case showPeerId
    case showDatacenter
    case fullViewCounts
    case hidePhoneNumber
    case exactCreationDate
    case approximateAccountAge
    case timestampSeconds
    case approximateLastSeen
    // Вкладки
    case hideContactsTab
    // Liquid Glass
    case glassMessages
    case glassProfile
    case glassBotButtons
    // Оформление → Эксперименты (only the owner account sees these)
    case plusAttachMenu
    case quickActionsMenu
    case noContextBlur
    case largerReactions
    case roundProfileButtons
    case squareProfileAvatar
    case avatarBackdrop
}

/// A row of the Settings screen that Разделы меню can hide.
public enum MindGramMenuSection: String, CaseIterable {
    case myProfile
    case wallet
    case proxy
    case miniApps
    case savedMessages
    case recentCalls
    case devices
    case chatFolders
    case notifications
    case privacy
    case dataAndStorage
    case appearance
    case powerSaving
    case language
    case premium
    case stars
    case ton
    case business
    case sendGift
    case passport
    case watch
    case support
    case faq
    case tips
    case proxySponsor
}

/// MindGram's settings, kept in UserDefaults. Writes post `didChangeNotification` on the main queue.
public enum MindGramSettings {
    public static let didChangeNotification = Notification.Name("MindGramSettingsDidChange")

    public static let navbarScaleRange: ClosedRange<Int> = 50 ... 150

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    public static let classicConflicts: Set<MindGramToggle> = [
        .glassMessages,
        .glassProfile,
        .glassBotButtons,
        .plusAttachMenu,
        .quickActionsMenu,
        .noContextBlur,
        .largerReactions,
        .roundProfileButtons,
        .squareProfileAvatar,
        .avatarBackdrop
    ]

    public static func isOn(_ toggle: MindGramToggle) -> Bool {
        if MindGramDesign.isClassic && self.classicConflicts.contains(toggle) {
            return false
        }
        return self.storedValue(toggle)
    }

    public static func storedValue(_ toggle: MindGramToggle) -> Bool {
        return self.defaults.bool(forKey: "MindGram.toggle.\(toggle.rawValue)")
    }

    public static func isLockedByClassicDesign(_ toggle: MindGramToggle) -> Bool {
        return MindGramDesign.isClassicOnNextLaunch && self.classicConflicts.contains(toggle)
    }

    public static var navbarCustomSize: Bool {
        get {
            if let value = self.defaults.object(forKey: "MindGram.navbar.custom") as? Bool {
                return value
            }
            return self.defaults.object(forKey: "MindGram.navbar.height") != nil || self.defaults.object(forKey: "MindGram.navbar.width") != nil
        }
        set {
            self.defaults.set(newValue, forKey: "MindGram.navbar.custom")
            self.notify()
        }
    }

    public static var navbarSizeIsActive: Bool {
        return self.navbarCustomSize && !MindGramDesign.isClassic
    }

    public static var storedNavbarHeightPercent: Int {
        return self.percent(forKey: "MindGram.navbar.height")
    }

    public static var storedNavbarWidthPercent: Int {
        return self.percent(forKey: "MindGram.navbar.width")
    }

    public static func set(_ toggle: MindGramToggle, _ value: Bool) {
        self.defaults.set(value, forKey: "MindGram.toggle.\(toggle.rawValue)")
        self.notify()
    }

    public static func isHidden(_ section: MindGramMenuSection) -> Bool {
        return self.defaults.bool(forKey: "MindGram.menu.\(section.rawValue)")
    }

    public static func setHidden(_ section: MindGramMenuSection, _ value: Bool) {
        self.defaults.set(value, forKey: "MindGram.menu.\(section.rawValue)")
        self.notify()
    }

    /// Height of the bottom tab bar, percent of Telegram's own (50–150, default 100).
    public static var navbarHeightPercent: Int {
        get {
            return self.navbarSizeIsActive ? self.percent(forKey: "MindGram.navbar.height") : 100
        }
        set {
            self.defaults.set(min(max(newValue, self.navbarScaleRange.lowerBound), self.navbarScaleRange.upperBound), forKey: "MindGram.navbar.height")
            self.notify()
        }
    }

    /// Width of the bottom tab bar, percent of Telegram's own (50–150, default 100).
    public static var navbarWidthPercent: Int {
        get {
            return self.navbarSizeIsActive ? self.percent(forKey: "MindGram.navbar.width") : 100
        }
        set {
            self.defaults.set(min(max(newValue, self.navbarScaleRange.lowerBound), self.navbarScaleRange.upperBound), forKey: "MindGram.navbar.width")
            self.notify()
        }
    }

    private static func percent(forKey key: String) -> Int {
        guard let value = self.defaults.object(forKey: key) as? Int else {
            return 100
        }
        return min(max(value, self.navbarScaleRange.lowerBound), self.navbarScaleRange.upperBound)
    }

    private static func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
            }
        }
    }
}

/// Telegram datacenters, for the DC row of a profile.
public enum MindGramDatacenter {
    public static func title(_ id: Int) -> String {
        let location: String
        switch id {
        case 1, 3:
            location = "Майами"
        case 2, 4:
            location = "Амстердам"
        case 5:
            location = "Сингапур"
        default:
            return "DC\(id)"
        }
        return "DC\(id) · \(location)"
    }
}

/// Estimates when a Telegram account was created from its user ID.
///
/// Telegram does not publish registration dates. User IDs grow over time, so the date is interpolated
/// between known (ID, date) pairs: the GetIDs table (MIT, github.com/amanoteam/python-getids) up to 2021,
/// and quarterly medians of publicly collected accounts for 2021–2025. Expect an error of a few months.
public enum MindGramAccountAge {
    public enum Estimate {
        case olderThan(Date)
        case approximately(Date)
        case newerThan(Date)
    }

    private static let points: [(id: Int64, timestamp: Int64)] = [
        (2768409, 1383264000),
        (7679610, 1388448000),
        (11538514, 1391212000),
        (15835244, 1392940000),
        (23646077, 1393459000),
        (38015510, 1393632000),
        (44634663, 1399334000),
        (46145305, 1400198000),
        (54845238, 1411257000),
        (63263518, 1414454000),
        (101260938, 1425600000),
        (101323197, 1426204000),
        (111220210, 1429574000),
        (116812045, 1437696000),
        (122600695, 1437782000),
        (124872445, 1439856000),
        (130029930, 1441324000),
        (133909606, 1444176000),
        (157242073, 1446768000),
        (171295414, 1457481000),
        (181783990, 1460246000),
        (222021233, 1465344000),
        (225034354, 1466208000),
        (278941742, 1473465000),
        (285253072, 1476835000),
        (294851037, 1479600000),
        (297621225, 1481846000),
        (328594461, 1482969000),
        (337808429, 1487707000),
        (341546272, 1487782000),
        (352940995, 1487894000),
        (369669043, 1490918000),
        (400169472, 1501459000),
        (805158066, 1563208000),
        (1974255900, 1634000000),
        (5022636255, 1636934400),
        (5170390109, 1644883200),
        (5349830748, 1652572800),
        (5468950164, 1660521600),
        (5705427359, 1668470400),
        (5869978651, 1676419200),
        (6001287799, 1684108800),
        (6523424924, 1692057600),
        (6545049031, 1700006400),
        (6715889959, 1707955200),
        (7085776398, 1715731200),
        (7357703634, 1723680000),
        (7664959631, 1731628800),
        (7964511972, 1739577600),
        (8179125032, 1755216000),
        (8325327280, 1763164800)
    ]

    public static func estimate(userId: Int64) -> Estimate {
        guard let first = self.points.first, let last = self.points.last else {
            return .approximately(Date())
        }
        if userId < first.id {
            return .olderThan(Date(timeIntervalSince1970: TimeInterval(first.timestamp)))
        }
        if userId > last.id {
            return .newerThan(Date(timeIntervalSince1970: TimeInterval(last.timestamp)))
        }
        var lower = first
        for point in self.points {
            if userId <= point.id {
                let span = Double(point.id - lower.id)
                let ratio = span > 0.0 ? Double(userId - lower.id) / span : 0.0
                let timestamp = Double(lower.timestamp) + ratio * Double(point.timestamp - lower.timestamp)
                return .approximately(Date(timeIntervalSince1970: timestamp))
            }
            lower = point
        }
        return .approximately(Date(timeIntervalSince1970: TimeInterval(last.timestamp)))
    }
}

/// The MindGram owner's accounts: the experimental design switches are shown only to them.
public enum MindGramOwner {
    public static let peerIds: Set<Int64> = [8690187164]
    public static let usernames: Set<String> = ["aftreen"]

    /// `peerId` is the account's user id (PeerId.id), `username` its @username without "@".
    public static func isOwner(userId: Int64, username: String?) -> Bool {
        if self.peerIds.contains(userId) {
            return true
        }
        if let username, self.usernames.contains(username.lowercased()) {
            return true
        }
        return false
    }
}
