//
//  CompilationErrorsParser.swift
//  WebberTools
//
//  Created by Mihael Isaev on 18.06.2021.
//

import Foundation

public func pasreCompilationErrors(_ rawError: String) -> [CompilationError] {
    var errors: [CompilationError] = []
    var lines = rawError.components(separatedBy: "\n")
    while !lines.isEmpty {
        var places: [CompilationError.Place] = []
        let line = lines.removeFirst()
        func lineIsPlace(_ line: String) -> Bool {
            line.hasPrefix("/") && line.components(separatedBy: "/").count > 1 && line.contains(".swift:")
        }
        func placeErrorComponents(_ line: String) -> [String]? {
            let components = line.components(separatedBy: ":")
            guard components.count == 5, components[3].contains("error") else {
                return nil
            }
            return components
        }
        guard lineIsPlace(line) else { continue }
        func parsePlace(_ line: String) {
            guard let components = placeErrorComponents(line) else { return }
            let filePath = URL(fileURLWithPath: components[0])
            func gracefulExit() {
                if places.count > 0 {
                    if let error = errors.first(where: { $0.file == filePath }) {
                        places.forEach { place in
                            guard error.places.first(where: { $0.line == place.line && $0.reason == place.reason }) == nil
                                else { return }
                            error.places.append(place)
                        }
                        error.places.sort(by: { $0.line < $1.line })
                    } else {
                        places.sort(by: { $0.line < $1.line })
                        errors.append(.init(file: filePath, places: places))
                    }
                }
            }
            guard let lineInFile = Int(components[1]) else {
                gracefulExit()
                return
            }
            let reason = components[4]
            let lineWithCode = lines.removeFirst()
            let lineWithPointer = lines.removeFirst()
            guard lineWithPointer.contains("^") else {
                gracefulExit()
                return
            }
            places.append(.init(line: lineInFile, reason: reason, code: lineWithCode, pointer: lineWithPointer))
            if let nextLine = lines.first, lineIsPlace(nextLine), placeErrorComponents(nextLine)?.first == filePath.path {
                parsePlace(lines.removeFirst())
            } else {
                gracefulExit()
            }
        }
        parsePlace(line)
    }
    guard errors.count > 0 else { return [] }
    errors.sort(by: { $0.file.lastPathComponent < $1.file.lastPathComponent })
    return errors
}
