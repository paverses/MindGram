import Foundation

/// What a file is, by its extension, and what the «Файл» editor can do with it.
public enum MindGramFileKind {
    case audio
    case video
    case image
    case text
    case other

    public static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf", "flac", "alac", "ogg", "oga", "opus", "wma", "amr", "m4b", "m4r"]
    public static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "3gp", "3g2", "avi", "mkv", "webm", "mpg", "mpeg", "ts", "mts", "wmv", "flv"]
    public static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif", "ico", "dng"]

    /// Code and text formats the editor opens, with a readable language name.
    public static let textLanguages: [String: String] = [
        "txt": "Text", "text": "Text", "md": "Markdown", "markdown": "Markdown", "rst": "reStructuredText", "log": "Log",
        "py": "Python", "pyw": "Python", "pyi": "Python", "ipynb": "Jupyter",
        "js": "JavaScript", "mjs": "JavaScript (ES module)", "cjs": "JavaScript (CommonJS)", "jsx": "JSX",
        "ts": "TypeScript", "tsx": "TSX", "mts": "TypeScript (ES module)", "cts": "TypeScript (CommonJS)",
        "java": "Java", "kt": "Kotlin", "kts": "Kotlin Script", "scala": "Scala", "groovy": "Groovy", "gradle": "Gradle",
        "swift": "Swift", "m": "Objective-C", "mm": "Objective-C++", "h": "C header", "hpp": "C++ header", "hh": "C++ header",
        "c": "C", "cc": "C++", "cpp": "C++", "cxx": "C++", "cs": "C#", "fs": "F#", "vb": "Visual Basic",
        "go": "Go", "rs": "Rust", "zig": "Zig", "nim": "Nim", "d": "D", "dart": "Dart",
        "rb": "Ruby", "php": "PHP", "pl": "Perl", "pm": "Perl", "lua": "Lua", "r": "R", "jl": "Julia",
        "ex": "Elixir", "exs": "Elixir", "erl": "Erlang", "hs": "Haskell", "clj": "Clojure", "elm": "Elm", "ml": "OCaml",
        "sh": "Shell", "bash": "Bash", "zsh": "Zsh", "fish": "Fish", "ps1": "PowerShell", "bat": "Batch", "cmd": "Batch",
        "sql": "SQL", "graphql": "GraphQL", "gql": "GraphQL", "proto": "Protocol Buffers",
        "json": "JSON", "jsonc": "JSON", "json5": "JSON5", "yaml": "YAML", "yml": "YAML", "toml": "TOML",
        "ini": "INI", "cfg": "Config", "conf": "Config", "env": "Env", "properties": "Properties", "plist": "Property List",
        "xml": "XML", "html": "HTML", "htm": "HTML", "xhtml": "XHTML", "svg": "SVG",
        "css": "CSS", "scss": "SCSS", "sass": "Sass", "less": "Less", "vue": "Vue", "svelte": "Svelte", "astro": "Astro",
        "csv": "CSV", "tsv": "TSV", "tex": "LaTeX", "bib": "BibTeX",
        "srt": "Subtitles", "vtt": "Subtitles", "ass": "Subtitles",
        "dockerfile": "Dockerfile", "makefile": "Makefile", "cmake": "CMake", "mk": "Makefile",
        "gitignore": "Git", "editorconfig": "EditorConfig", "lock": "Lock file", "diff": "Diff", "patch": "Patch"
    ]

    /// Formats the editor can convert to, per kind.
    public static let audioTargets = ["mp3", "m4a", "wav", "aiff", "caf"]
    public static let videoTargets = ["mp4", "mov", "m4a"]
    public static let imageTargets = ["jpg", "png", "heic"]

    public static func of(extension ext: String) -> MindGramFileKind {
        let ext = ext.lowercased()
        if self.audioExtensions.contains(ext) {
            return .audio
        } else if self.videoExtensions.contains(ext) && ext != "ts" {
            return .video
        } else if self.imageExtensions.contains(ext) {
            return .image
        } else if self.textLanguages[ext] != nil {
            return .text
        }
        return .other
    }

    /// Formats iOS can read (and so convert from).
    public static func canConvert(from ext: String) -> Bool {
        switch self.of(extension: ext) {
        case .audio:
            return !["ogg", "oga", "opus", "wma", "amr"].contains(ext.lowercased())
        case .video:
            return ["mp4", "mov", "m4v", "3gp", "3g2"].contains(ext.lowercased())
        case .image:
            return true
        default:
            return false
        }
    }
}

/// The editor's switch in «Чат и перевод».
public enum MindGramFileTools {
    public static var isEnabled: Bool {
        get { return UserDefaults.standard.object(forKey: "MindGram.fileEditor.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.fileEditor.enabled")
            NotificationCenter.default.post(name: Notification.Name("MindGramSettingsDidChange"), object: nil)
        }
    }

    /// Bitrate of MP3 conversion, kbit/s.
    public static var mp3Bitrate: Int {
        get { return UserDefaults.standard.object(forKey: "MindGram.fileEditor.mp3Bitrate") as? Int ?? 192 }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.fileEditor.mp3Bitrate")
            NotificationCenter.default.post(name: Notification.Name("MindGramSettingsDidChange"), object: nil)
        }
    }
}

public extension MindGramFileTools {
    /// Offer to send text over Telegram's limit as one file.
    static var longTextAsFile: Bool {
        get { return UserDefaults.standard.object(forKey: "MindGram.longText.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "MindGram.longText.enabled")
            NotificationCenter.default.post(name: Notification.Name("MindGramSettingsDidChange"), object: nil)
        }
    }

    /// Telegram's message length limit.
    static let longTextLimit = 4096
}
