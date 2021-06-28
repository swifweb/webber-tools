//
//  DirectoryMonitor.swift
//  XLivePreview
//
//  Created by Mihael Isaev on 18.06.2021.
//

import Foundation

public class DirectoryMonitor {
    lazy var dispatchQueue = DispatchQueue(label: "xlivepreview.directorymonitor", attributes: .concurrent)
    
    var fileDescriptor: Int32 = -1
    var dispatchSource: DispatchSourceFileSystemObject?
    
    enum Mode { case dir, file }
    
    let url: URL
    let mode: Mode
    let parent: DirectoryMonitor?
    
    /// when child changed it should update this flag at its parent
    private var _childChanged = false
    private var childChanged: Bool {
        get { _childChanged }
        set {
            _childChanged = newValue
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                guard self._childChanged else { return }
                self._childChanged = false
            }
        }
    }
    
    private var submonitors: [String: DirectoryMonitor] = [:]
    
    private var lastChangedDate: Date?
    private var fileLastChangedDate: Date?
    
    init(_ url: URL, parent: DirectoryMonitor? = nil) {
        self.url = url
        var isDir : ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.mode = isDir.boolValue ? .dir : .file
        self.parent = parent
    }
    
    convenience init(_ path: String, watchSubdirectoryCreation: Bool = false) {
        self.init(URL(fileURLWithPath: path))
    }
    
    @discardableResult
    func startMonitoring(_ closure: @escaping (URL) -> Void) -> Self {
        guard dispatchSource == nil && fileDescriptor == -1 else { return self }
        func scanSubfolders() -> [String] {
            guard let content = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
            return content.filter {
                let path = url.appendingPathComponent($0).path
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            }
        }
        func checkSubfolders() {
            scanSubfolders().forEach { relativePath in
                guard !self.submonitors.keys.contains(relativePath) else { return }
                self.submonitors[relativePath] = DirectoryMonitor(self.url.appendingPathComponent(relativePath), parent: self).startMonitoring(closure)
            }
        }
        
        if mode == .dir {
            checkSubfolders()
        }
        
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return self }
        
        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: dispatchQueue)
        dispatchSource?.setEventHandler {
            if let lastChangedDate = self.lastChangedDate {
                if Date().timeIntervalSince(lastChangedDate) < 1 {
                    self.lastChangedDate = Date()
                    return
                }
            }
            guard let data = self.dispatchSource?.data else { return }
            switch self.mode {
            case .file:
                self.parent?.childChanged = true
                // don't react on only attributes change
                guard data.rawValue != DispatchSource.FileSystemEvent.attrib.rawValue else { return }
                self.lastChangedDate = Date()
                closure(self.url)
                if data.contains(.link) {
                    self.dispatchSource?.cancel()
                    self.dispatchQueue.asyncAfter(deadline: .now() + 1) {
                        self.startMonitoring(closure)
                    }
                }
            case .dir:
                self.parent?.childChanged = true
                self.lastChangedDate = Date()
                if let urls = try? FileManager.default.contentsOfDirectory(atPath: self.url.path).map({ self.url.appendingPathComponent($0) }) {
                    struct Item {
                        let url: URL
                        let modificationDate: Date
                    }
                    var items: [Item] = []
                    for url in urls {
                        if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                            items.append(.init(url: url, modificationDate: date))
                        }
                    }
                    if let newest = items.sorted(by: { $0.modificationDate < $1.modificationDate }).last {
                        if let flcd = self.fileLastChangedDate {
                            if newest.modificationDate > flcd {
                                self.fileLastChangedDate = newest.modificationDate
                                closure(newest.url)
                                return
                            }
                        } else {
                            self.fileLastChangedDate = newest.modificationDate
                            closure(newest.url)
                            return
                        }
                    }
                }
                closure(self.url)
                guard data.contains(.write) else { return }
                checkSubfolders()
            }
        }
        dispatchSource?.setCancelHandler {
            close(self.fileDescriptor)
            self.fileDescriptor = -1
            self.dispatchSource = nil
            self.submonitors.forEach { $0.value.stopMonitoring() }
        }
        dispatchSource?.resume()

        return self
    }
    
    func stopMonitoring() {
        dispatchSource?.cancel()
    }
}
