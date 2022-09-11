//
//  String+SHA.swift
//  WebberTools
//
//  Created by Mihael Isaev on 19.06.2021.
//

import Foundation
import Crypto

import Foundation
import Crypto

extension String {
	public subscript (i: Int) -> Character {
		self[index(startIndex, offsetBy: i)]
	}
	
	public subscript (i: Int) -> String {
		String(self[i] as Character)
	}
}

extension String {
	var sha512: String {
		guard let data = self.data(using: .utf8) else { return "" }
		return data.sha512
	}
}

public extension Data {
    var sha512: String {
		return String(describing: SHA512.hash(data: self)).replacingOccurrences(of: "SHA512 digest: ", with: "")
	}
}
