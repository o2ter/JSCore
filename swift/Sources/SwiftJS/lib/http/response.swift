//
//  response.swift
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

@objc protocol JSURLResponseExport: JSExport {
  var url: String? { get }
  var statusCode: Int { get }
  var allHeaderFields: [String: String] { get }
  var textEncodingName: String? { get }
  var expectedContentLength: Int64 { get }
  var mimeType: String? { get }

  func value(forHTTPHeaderField field: String) -> String?
}

@objc final class JSURLResponse: NSObject, JSURLResponseExport {

  private let response: HTTPURLResponse
  private let customStatusCode: Int?
  private let customHeaders: [String: String]?
  private let customURL: String?

  init(response: HTTPURLResponse) {
    self.response = response
    self.customStatusCode = nil
    self.customHeaders = nil
    self.customURL = nil
    super.init()
  }

  // Convenience initializer for NIO responses
  init(statusCode: Int, headers: [String: String], url: String?) {
    // Create a dummy HTTPURLResponse for compatibility
    let dummyURL = URL(string: url ?? "https://example.com")!
    self.response = HTTPURLResponse(
      url: dummyURL, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
    self.customStatusCode = statusCode
    self.customHeaders = headers
    self.customURL = url
    super.init()
  }

  var url: String? {
    return customURL ?? response.url?.absoluteString
  }

  var statusCode: Int {
    return customStatusCode ?? response.statusCode
  }

  var allHeaderFields: [String: String] {
    if let customHeaders = customHeaders {
      return customHeaders
    }
    return response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
      if let key = pair.key as? String, let value = pair.value as? String {
        result[key] = value
      }
    }
  }

  var textEncodingName: String? {
    return response.textEncodingName
  }

  var expectedContentLength: Int64 {
    if let contentLength = customHeaders?["Content-Length"] ?? customHeaders?["content-length"] {
      return Int64(contentLength) ?? response.expectedContentLength
    }
    return response.expectedContentLength
  }

  var mimeType: String? {
    if let contentType = customHeaders?["Content-Type"] ?? customHeaders?["content-type"] {
      return contentType.components(separatedBy: ";").first?.trimmingCharacters(
        in: .whitespaces)
    }
    return response.mimeType
  }

  func value(forHTTPHeaderField field: String) -> String? {
    if let customHeaders = customHeaders {
      return customHeaders[field] ?? customHeaders[field.lowercased()]
    }
    return response.value(forHTTPHeaderField: field)
  }
}
