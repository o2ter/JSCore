//
//  console.swift
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

extension SwiftJS {

    /// Format a JavaScript value for better console output
    func formatJSValue(_ value: SwiftJS.Value, depth: Int = 0, maxDepth: Int = 3) -> String {
        if depth > maxDepth {
            return "[Max Depth Reached]"
        }

        if value.isNull {
            return "null"
        }

        if value.isUndefined {
            return "undefined"
        }

        if value.isString {
            return value.toString()
        }

        if value.isNumber {
            return value.toString()
        }

        if value.isBool {
            return value.toString()
        }

        // Handle Symbol specially to avoid conversion errors
        if value.isSymbol {
            // Use String constructor to safely convert symbol to string representation
            let stringConstructor = self.globalObject["String"]
            return stringConstructor.call(withArguments: [value]).toString()
        }

        if value.isFunction {
            // Try to get function name
            let funcName = value["name"].stringValue ?? "anonymous"
            return "[Function: \(funcName)]"
        }

        if value.isArray {
            // Get array length
            let length = value["length"].numberValue.map(Int.init) ?? 0
            if length == 0 {
                return "[]"
            }

            if depth >= maxDepth {
                return "[Array(\(length))]"
            }

            var items: [String] = []
            let maxItems = min(length, 10)

            for i in 0..<maxItems {
                let item = value[i]
                items.append(formatJSValue(item, depth: depth + 1, maxDepth: maxDepth))
            }

            let result =
                length > 10
                ? "[ \(items.joined(separator: ", ")), ... \(length - 10) more ]"
                : "[ \(items.joined(separator: ", ")) ]"

            return result
        }

        if value.isObject {
            // Handle special object types
            let className = value["constructor"]["name"].stringValue ?? ""

            // Handle Date objects
            if className == "Date" {
                return value.toString()
            }

            // Handle Error objects
            if className == "Error" {
                let name = value["name"].stringValue ?? "Error"
                let message = value["message"].stringValue ?? ""
                return "\(name): \(message)"
            }

            // Handle RegExp objects
            if className == "RegExp" {
                return value.toString()
            }

            // Handle plain objects
            if depth >= maxDepth {
                return "[Object]"
            }

            // Get object keys using Object.keys method
            let objectConstructor = self.globalObject["Object"]
            let keys = objectConstructor.invokeMethod("keys", withArguments: [value])

            let keyCount = keys["length"].numberValue.map(Int.init) ?? 0

            if keyCount == 0 {
                return "{}"
            }

            var pairs: [String] = []
            let maxKeys = min(keyCount, 10)

            for i in 0..<maxKeys {
                if let key = keys[i].stringValue {
                    let objValue = value[key]
                    let formattedValue = formatJSValue(
                        objValue, depth: depth + 1, maxDepth: maxDepth)
                    pairs.append("\(key): \(formattedValue)")
                }
            }

            let result =
                keyCount > 10
                ? "{ \(pairs.joined(separator: ", ")), ... \(keyCount - 10) more }"
                : "{ \(pairs.joined(separator: ", ")) }"

            return result
        }

        // Safe fallback for other types - use String constructor
        let stringConstructor = self.globalObject["String"]
        return stringConstructor.call(withArguments: [value]).toString()
    }
}

extension SwiftJS {

    func setupConsoleAPIs() {
        // Enhanced console implementation with better formatting
        self.globalObject["console"] = [:]

        for level in LogLevel.allCases {
            self.globalObject["console"][level.name] = .init(in: self) { arguments, _ in
                // Use the logger with enhanced formatting
                self.context.logger(level, arguments)
            }
        }

        // Override the default logger to use enhanced formatting
        self.context.logger = { level, arguments in
            let formattedArguments = arguments.map { arg in
                // Create a new SwiftJS.Value with the formatted string
                SwiftJS.Value(self.formatJSValue(arg))
            }
            // Call the original print-based logger with formatted arguments
            print(
                "[\(level.name.uppercased())] \(formattedArguments.map { $0.toString() }.joined(separator: " "))"
            )
        }
    }
}
