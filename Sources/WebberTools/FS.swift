//
//  FS.swift
//  XLivePreview
//
//  Created by Mihael Isaev on 18.06.2021.
//

import Foundation

private let _fs = FS()
private var _networkCache: [URL: Data] = [:]

public final class FS {
    private var monitors: [DirectoryMonitor] = []
    
    fileprivate init () {}
    
    deinit {
        monitors.forEach { $0.stopMonitoring() }
    }
    
    public static func watch(_ path: String, closure: @escaping (URL) -> Void) {
        watch(URL(fileURLWithPath: path), closure: closure)
    }
    
    public static func watch(_ url: URL, closure: @escaping (URL) -> Void) {
        _fs.monitors.append(DirectoryMonitor(url).startMonitoring(closure))
    }
    
    public static func contains(path: String) -> Bool {
        _fs.monitors.contains(where: { $0.url.path == path })
    }
    
    public static func shutdown() {
        _fs.monitors.forEach { $0.stopMonitoring() }
    }
    
    public struct PreviewNamesAndHash {
        public let previewNames: [String]
        public let hash: String
    }
    public static func extractPreviewNamesAndHash(at path: String) -> PreviewNamesAndHash? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        return PreviewNamesAndHash(previewNames: string.matches(for: "(?<=class )(.*)(?=_Preview: WebPreview)"), hash: string.sha512)
    }
    
    public static func replaceContentLinksToBase64(at path: String, previews: [Preview]) -> [Preview] {
        guard path.contains("/Sources/") else { print("replaceContentLinksToBase64 case 1.1");return previews }
        let projectPath = path.components(separatedBy: "/Sources/")[0]
        let moduleName = path.components(separatedBy: "/Sources/")[1].components(separatedBy: "/")[0]
        let modulePath = projectPath + "/Sources/" + moduleName + "/"
        var modifiedPreviews: [Preview] = []
        for preview in previews {
            let preview = preview
            // TODO: also cover background-image: url("./images/embouchure.jpg");
            // TODO: also cover <link href="/media/examples/link-element-example.css" rel="stylesheet">
            if let data = Data(base64Encoded: preview.html), var decodedHTML = String(data: data, encoding: .utf8) {
                for match in Array(Set(decodedHTML.matches(for: "(?<=src=\\\")[\\s\\S]*?(?=\\\")"))) {
                    if let u = URL(string: match) {
                        if u.host != nil {
                            guard let mimeType = u.pathExtension.mimeType else { continue }
                            if let retrievedData = _networkCache[u] ?? (try? Data(contentsOf: u)) {
                                _networkCache[u] = retrievedData
                                let b64 = retrievedData.base64EncodedString()
                                let replacement = "data:\(mimeType);charset=utf-8;base64, \(b64)"
                                decodedHTML = decodedHTML.replacingOccurrences(of: "src=\"\(match)\"", with: "src=\"\(replacement)\"")
                            }
                        } else {
                            var fileURL = URL(fileURLWithPath: modulePath)
                            for pathComponent in match.components(separatedBy: "/") {
                                guard pathComponent.count > 0 else { continue }
                                fileURL.appendPathComponent(pathComponent)
                            }
                            guard let mimeType = fileURL.pathExtension.mimeType else { continue }
                            if let retrievedData = try? Data(contentsOf: fileURL) {
                                let b64 = retrievedData.base64EncodedString()
                                let replacement = "data:\(mimeType);charset=utf-8;base64, \(b64)"
                                decodedHTML = decodedHTML.replacingOccurrences(of: "src=\"\(match)\"", with: "src=\"\(replacement)\"")
                            }
                        }
                    }
                }
                if let updatedHTML = decodedHTML.data(using: .utf8)?.base64EncodedString() {
                    preview.html = updatedHTML
                    print("replaceContentLinksToBase64 \(preview.class) modified")
                } else {
                    print("replaceContentLinksToBase64 \(preview.class) not modified 1")
                }
                modifiedPreviews.append(preview)
            } else {
                print("replaceContentLinksToBase64 \(preview.class) not modified 2")
                modifiedPreviews.append(preview)
            }
        }
        return modifiedPreviews
    }
}

extension String {
    var mimeType: String? {
        switch self {
        case "png": return "image/png"
        case "jpg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "js": return "text/javascript"
        case "css": return "text/css"
        default: return nil
        }
    }
    
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
