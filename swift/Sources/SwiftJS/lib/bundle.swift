//
//  bundle.swift
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

import JavaScriptCore

extension Bundle {
    
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    var buildVersion: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

@objc protocol JSBundleInfoExport: JSExport {
    static var main: Self { get }
    var appVersion: String? { get }
    var buildVersion: String? { get }
    var bundleIdentifier: String? { get }
    var infoDictionary: [String: Any] { get }
    var localizedInfoDictionary: [String: Any] { get }
}

@objc final class JSBundleInfo: NSObject, JSBundleInfoExport {
    
    let bundle: Bundle
    
    init(_ bundle: Bundle) {
        self.bundle = bundle
    }
}

extension JSBundleInfo {
    
    static var main: JSBundleInfo {
        return JSBundleInfo(Bundle.main)
    }
    
    var appVersion: String? {
        return self.bundle.appVersion
    }
    
    var buildVersion: String? {
        return self.bundle.buildVersion
    }
    
    var bundleIdentifier: String? {
        return self.bundle.bundleIdentifier
    }
    
    var infoDictionary: [String: Any] {
        return self.bundle.infoDictionary ?? [:]
    }
    
    var localizedInfoDictionary: [String: Any] {
        return self.bundle.localizedInfoDictionary ?? [:]
    }
}
