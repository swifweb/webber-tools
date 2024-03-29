//
//  SwiftPackage.swift
//  WebberTools
//
//  Created by Mihael Isaev on 19.06.2021.
//

import Foundation

public struct SwiftPackage: Decodable {
    public struct Product: Decodable {
        public let name: String
        public let type: [String: String?]?
    }
    public let products: [Product]?
    public struct Target: Decodable {
        public let name: String
        public let path: String? // where to search target name
        public let sources: [String]?
        public struct Resource: Decodable {
            public enum Rule: String, Decodable {
                case process, copy
				
				public init(from decoder: Decoder) throws {
					let container = try decoder.singleValueContainer()
					if let ruleString = try? container.decode(String.self), let rule = Rule(rawValue: ruleString) {
						self = rule
					} else {
						let ruleDict = try container.decode([String: [String: String]?].self)
						if ruleDict.keys.contains("process") {
							self = .process
						} else {
							self = .copy
						}
					}
				}
            }
            public enum Localization: String, Decodable {
                case `default` = "default", base
            }
            public let path: String
            public let rule: Rule
            public let localization: Localization?
        }
        public let resources: [Resource]?
    }
    public let targets: [Target]?
    public struct Dependency: Decodable {
        public let identity: String
        public let local: Bool
        public let url: String?
        
        private enum CodingKeys : String, CodingKey {
            case identity, requirement, location
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            identity = try container.decode(String.self, forKey: .identity)
            if let requirement = try? container.decode([String: String?].self, forKey: .requirement) {
                local = requirement.keys.contains("localPackage") == true
            } else {
                local = false
            }
            url = try container.decode(String.self, forKey: .location)
        }
    }
    public struct NewDependency: Decodable {
        public let scm: [Dependency]?
    }
    public let dependencies: [NewDependency]?
}
