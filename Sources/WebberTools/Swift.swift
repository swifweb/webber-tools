//
//  Swift.swift
//  Webber
//
//  Created by Mihael Isaev on 31.01.2021.
//

import Foundation

public class Swift {
    public let launchPath, workingDirectory: String
    
    public init (_ launchPath: String, _ workingDirectory: String) {
        self.launchPath = launchPath
        self.workingDirectory = workingDirectory
    }
    
    public enum Command {
        case dump
        case version
        case build(release: Bool, productName: String)
        case previews(moduleName: String, previewNames: [String])
        
        public func arguments(tripleWasm: Bool = true) -> [String] {
            switch self {
            case .dump: return ["package", "dump-package"]
            case .version: return ["--version"]
            case .build(let r, let p):
                var args: [String] = ["build", "-c", r ? "release" : "debug", "--product", p, "--enable-test-discovery"]
                if tripleWasm {
                    args.append(contentsOf: ["--triple", "wasm32-unknown-wasi", "-Xlinker", "-licuuc", "-Xlinker", "-licui18n", "-Xlinker", "--stack-first"])
                    return args
                } else {
                    args.append(contentsOf: ["--build-path", "./.build/.native"])
                    return args
                }
            case .previews(let moduleName, let previewNames):
                return ["run", "-Xswiftc", "-DWEBPREVIEW", moduleName, "--previews"] + [previewNames.map({ moduleName + "/" + $0 }).joined(separator: ",")] + ["--build-path", "./.build/.live"]
            }
        }
    }

    public enum SwiftError: Error, CustomStringConvertible {
        case lines(lines: [String])
        case another(Error)
        case text(String)
        case raw(String)
        case errors([CompilationError])
        
        public var description: String {
            switch self {
            case .lines(let lines): return "\(lines)"
            case .another(let error): return error.localizedDescription
            case .text(let text): return text
            case .raw(let raw): return raw
            case .errors(let errors):
                if errors.count > 1 {
                    return "found \(errors.count) errors ❗️❗️❗️"
                }
                return "found 1 error ❗️"
            }
        }
        
        public var localizedDescription: String { description }
    }
    
    public func version() throws -> String {
        try execute(.version, process: Process())
    }
    
    public func buildAsync(
        _ productName: String,
        release: Bool = false,
        tripleWasm: Bool = true,
        handler: @escaping (Result<String, Error>) -> Void
    ) -> Process {
        let process = Process()
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let result = try self.execute(.build(release: release, productName: productName), process: process, tripleWasm: tripleWasm)
                handler(.success(result))
            } catch {
                handler(.failure(error))
            }
        }
        return process
    }
    
    @discardableResult
    public func build(_ productName: String, release: Bool = false, tripleWasm: Bool) throws -> String {
        try execute(.build(release: release, productName: productName), process: Process(), tripleWasm: tripleWasm)
    }
    
    @discardableResult
    public func previews(_ moduleName: String, previewNames: [String], _ process: Process) throws -> [Preview] {
        struct Result: Decodable {
            let previews: [Preview]
        }
        guard let data = try execute(.previews(moduleName: moduleName, previewNames: previewNames), process: process, tripleWasm: false).data(using: .utf8) else {
            throw SwiftError.text("Unable to get preview")
        }
        return try JSONDecoder().decode(Result.self, from: data).previews
    }
    
    /// Swift command execution
    /// - Parameters:
    ///   - command: one of supported commands
    @discardableResult
    private func execute(_ command: Command, process: Process, tripleWasm: Bool = true) throws -> String {
        let stdout = Pipe()
        let stderr = Pipe()
        
        var env: [String: String] = [:]
        for (key, value) in ProcessInfo.processInfo.environment {
            env[key] = value
        }
        env["WEBBER"] = "TRUE"
        
        process.currentDirectoryPath = workingDirectory
        process.launchPath = launchPath
        process.environment = env
        process.arguments = command.arguments(tripleWasm: tripleWasm)
        process.standardOutput = stdout
        process.standardError = stderr
        
        var resultData = Data()
        let group = DispatchGroup()
        group.enter()
        stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if data.isEmpty { // EOF on the pipe
                stdout.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                resultData.append(data)
            }
        }
        process.launch()
        process.waitUntilExit()
        group.wait()
        guard process.terminationStatus == 0 else {
            let data = resultData
            guard data.count > 0, let rawError = String(data: data, encoding: .utf8) else {
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                if errData.count > 0 {
                    let separator = ": error:"
                    var errString = String(data: errData, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
                    errString = errString.contains(separator) ? errString.components(separatedBy: separator).last?.trimmingCharacters(in: .whitespaces) ?? "" : errString
                    throw SwiftError.text("Build failed: \(errString)")
                } else {
                    throw SwiftError.text("Build failed with exit code \(process.terminationStatus)")
                }
            }
            switch command {
            case .build:
                let errors: [CompilationError] = pasreCompilationErrors(rawError)
                guard errors.count > 0 else { throw SwiftError.text("Unable to parse errors") }
                throw SwiftError.errors(errors)
            default:
                throw SwiftError.raw(rawError)
            }
        }
        
        do {
            let data = resultData
            guard data.count > 0 else { return "" }
            guard let result = String(data: data, encoding: .utf8) else {
                throw SwiftError.text("Unable to read stdout")
            }
            return result
        } catch {
            return ""
        }
    }
    
    private var package: SwiftPackage?
    
    public func dumpPackage() throws -> SwiftPackage {
        if let package = package {
            return package
        }
        let dump = try execute(.dump, process: Process())
        
        guard let data = dump.data(using: .utf8) else {
            throw SwiftError.text("Unable to make dump data")
        }
        return try JSONDecoder().decode(SwiftPackage.self, from: data)
    }
    
    public func checkIfServiceWorkerProductPresent(_ targetName: String) throws {
        let package = try dumpPackage()
        guard let _ = package.products?.filter({
            targetName == $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            throw SwiftError.text("Unable to find service worker executable product with name `\(targetName)` in Package.swift")
        }
    }
    
    public func checkIfAppProductPresent(_ targetName: String) throws {
        let package = try dumpPackage()
        guard let _ = package.products?.filter({
            targetName == $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            throw SwiftError.text("Unable to find app executable product with name `\(targetName)` in Package.swift")
        }
    }
    
    public func lookupExecutableName(excluding serviceWorkerTarget: String?) throws -> String {
        let package = try dumpPackage()
        guard let product = package.products?.filter({
            serviceWorkerTarget != $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            let excluding = serviceWorkerTarget != nil ? " (excluding service worker: \(serviceWorkerTarget!)" : ""
            throw SwiftError.text("Unable to find app executable product in Package.swift\(excluding)")
        }
        return product.name
    }
    
    public func lookupLocalDependencies() throws -> [String] {
        let dump = try execute(.dump, process: Process())
        guard let data = dump.data(using: .utf8) else {
            throw SwiftError.text("Unable to make dump data")
        }
        let package = try JSONDecoder().decode(SwiftPackage.self, from: data)
        return package.dependencies?
            .flatMap { $0.scm ?? [] }
            .filter { $0.local }
            .compactMap { $0.url }
            .filter { !$0.hasPrefix("../") && !$0.hasPrefix("./") }
            .map { $0 + "/Sources" }
            ?? []
    }
}
