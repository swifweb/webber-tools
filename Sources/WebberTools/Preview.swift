//
//  Preview.swift
//  WebberTools
//
//  Created by Mihael Isaev on 18.06.2021.
//

public class Preview: Codable {
    public let width, height: UInt
    public let title, module, `class`: String
    public var html: String
    
    public init (width: UInt, height: UInt, title: String, module: String, class: String, html: String) {
        self.width = width
        self.height = height
        self.title = title
        self.module = module
        self.class = `class`
        self.html = html
    }
}
