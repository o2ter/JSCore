//
//  request.swift
//
//  The MIT License
//  Copyright (c) 2021 - 2025 O2ter Limited. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import JavaScriptCore

@objc protocol JSURLRequestExport: JSExport {
    init(url: String)
    
    var url: String? { get }
    var httpMethod: String { get set }
    var allHTTPHeaderFields: [String: String] { get set }
    var httpBody: JSValue? { get set }
    var timeoutInterval: Double { get set }
    
    func setValueForHTTPHeaderField(_ value: String?, _ field: String)
    func addValueForHTTPHeaderField(_ value: String, _ field: String)
    func valueForHTTPHeaderField(_ field: String) -> String?
}

@objc final class JSURLRequest: NSObject, JSURLRequestExport, @unchecked Sendable {
    
    public var url: String?
    public var httpMethod: String = "GET"
    public var allHTTPHeaderFields: [String: String] = [:]
    public var timeoutInterval: Double = 60.0
    private var httpBodyData: Data?
    
    init(url: String) {
        guard URL(string: url) != nil else {
            self.url = "about:blank"
            super.init()
            return
        }
        self.url = url
        super.init()
    }
    
    
    var httpBody: JSValue? {
        get {
            guard let data = httpBodyData,
                  let context = JSContext.current() else { return nil }
            return JSValue.uint8Array(count: data.count, in: context) { buffer in
                data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
            }
        }
        set {
            if let jsValue = newValue, jsValue.isTypedArray {
                let bytes = jsValue.typedArrayBytes
                httpBodyData = Data(bytes.bindMemory(to: UInt8.self))
            } else if let jsValue = newValue, jsValue.isString {
                httpBodyData = jsValue.toString().data(using: .utf8)
            } else {
                httpBodyData = nil
            }
        }
    }
    
    
    func setValueForHTTPHeaderField(_ value: String?, _ field: String) {
        if let value = value {
            allHTTPHeaderFields[field] = value
        } else {
            allHTTPHeaderFields.removeValue(forKey: field)
        }
    }
    
    func addValueForHTTPHeaderField(_ value: String, _ field: String) {
        if let existing = allHTTPHeaderFields[field] {
            allHTTPHeaderFields[field] = existing + ", " + value
        } else {
            allHTTPHeaderFields[field] = value
        }
    }
    
    func valueForHTTPHeaderField(_ field: String) -> String? {
        return allHTTPHeaderFields[field]
    }
    
    // Provide access to the raw body data for streaming operations
    var bodyData: Data? {
        return httpBodyData
    }
}
