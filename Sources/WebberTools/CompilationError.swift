//
//  CompilationError.swift
//  WebberTools
//
//  Created by Mihael Isaev on 18.06.2021.
//

import Foundation

public class CompilationError {
    public let file: URL
    public struct Place {
        public let line: Int
        public let reason: String
        public let code: String
        public let pointer: String
    }
    public var places: [Place]
    
    public init (file: URL, places: [Place]) {
        self.file = file
        self.places = places
    }
}
