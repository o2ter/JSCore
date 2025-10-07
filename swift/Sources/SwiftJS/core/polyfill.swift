//
//  polyfill.swift
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

extension SwiftJS {

    class Context {

        var timerId: Int = 0
        var timer: [Int: Timer] = [:]
        fileprivate let timerLock = NSLock()

        var networkRequestId: Int = 0
        var networkRequests: Set<Int> = []
        private let networkLock = NSLock()

        // File handle management for continuous reading
        var openFileHandles: [Int: FileHandle] = [:]
        var handleCounter = 0
        let handleLock = NSLock()

        var logger: @Sendable (LogLevel, [SwiftJS.Value]) -> Void

        init() {
            self.logger = { level, message in
                print(
                    "[\(level.name.uppercased())] \(message.map { $0.toString() }.joined(separator: " "))"
                )
            }
        }
        /// Check if there are any active timers
        var hasActiveTimers: Bool {
            timerLock.lock()
            defer { timerLock.unlock() }
            return !timer.isEmpty
        }

        /// Get count of active timers
        var activeTimerCount: Int {
            timerLock.lock()
            defer { timerLock.unlock() }
            return timer.count
        }

        /// Check if there are any active network requests
        var hasActiveNetworkRequests: Bool {
            networkLock.lock()
            defer { networkLock.unlock() }
            return !networkRequests.isEmpty
        }

        /// Get count of active network requests
        var activeNetworkRequestCount: Int {
            networkLock.lock()
            defer { networkLock.unlock() }
            return networkRequests.count
        }

        /// Check if there are any active file handles
        var hasActiveFileHandles: Bool {
            handleLock.lock()
            defer { handleLock.unlock() }
            return !openFileHandles.isEmpty
        }

        /// Get count of active file handles
        var activeFileHandleCount: Int {
            handleLock.lock()
            defer { handleLock.unlock() }
            return openFileHandles.count
        }

        /// Start tracking a network request
        func startNetworkRequest() -> Int {
            networkLock.lock()
            defer { networkLock.unlock() }
            let id = networkRequestId
            networkRequests.insert(id)
            networkRequestId += 1
            return id
        }

        /// Stop tracking a network request
        func endNetworkRequest(_ id: Int) {
            networkLock.lock()
            defer { networkLock.unlock() }
            networkRequests.remove(id)
        }

        deinit {
            for (_, timer) in self.timer {
                timer.invalidate()
            }
            timer = [:]

            // Close all open file handles
            handleLock.lock()
            for (_, fileHandle) in openFileHandles {
                fileHandle.closeFile()
            }
            openFileHandles.removeAll()
            handleLock.unlock()
        }
    }
}

extension SwiftJS {

    public typealias Export = JSExport & NSObject

}

extension SwiftJS.Value {

    public init(_ value: SwiftJS.Export, in context: SwiftJS) {
        self.init(JSValue(object: value, in: context.base))
    }

    public init(_ value: SwiftJS.Export.Type, in context: SwiftJS) {
        self.init(JSValue(object: value, in: context.base))
    }
}

extension SwiftJS.Context: @unchecked Sendable {}

extension SwiftJS {

    fileprivate func createTimer(
        callback: SwiftJS.Value, ms: Double, repeats: Bool, arguments: [SwiftJS.Value]
    ) -> Int {
        // Generate timer ID atomically
        context.timerLock.lock()
        let timerId = context.timerId
        context.timerId += 1
        context.timerLock.unlock()

        // Create timer directly - we're already on the JavaScript context's thread
        context.timerLock.lock()
        context.timer[timerId] = Timer.scheduledTimer(
            withTimeInterval: ms / 1000,
            repeats: repeats,
            block: { _ in
                _ = callback.call(withArguments: arguments)

                // Auto-cleanup non-repeating timers (setTimeout)
                if !repeats {
                    self.context.timerLock.lock()
                    let timer = self.context.timer.removeValue(forKey: timerId)
                    self.context.timerLock.unlock()
                    timer?.invalidate()
                }
            }
        )
        context.timerLock.unlock()

        return timerId
    }

    fileprivate func removeTimer(identifier: Int) {
        // Remove timer directly - we're already on the JavaScript context's thread
        context.timerLock.lock()
        let timer = context.timer.removeValue(forKey: identifier)
        context.timerLock.unlock()
        timer?.invalidate()
    }
    /// Start tracking a network request and return its ID
    public func startNetworkRequest() -> Int {
        return self.context.startNetworkRequest()
    }

    /// Stop tracking a network request by ID
    public func endNetworkRequest(_ id: Int) {
        self.context.endNetworkRequest(id)
    }

}

extension SwiftJS {

    /// Format a JavaScript value for better console output
    private func formatJSValue(_ value: SwiftJS.Value, depth: Int = 0, maxDepth: Int = 3) -> String
    {
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

    func polyfill() {
        // Enhanced console implementation with better formatting
        self.globalObject["console"] = [:]

        for level in LogLevel.allCases {
            self.globalObject["console"][level.name] = .init(in: self) { arguments, _ in
                // Use the original logger but with enhanced arguments
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
        self.globalObject["setTimeout"] = .init(in: self) { arguments, _ in
            guard arguments.count > 0,
                !arguments[0].isNull,
                !arguments[0].isUndefined,
                arguments[0].isFunction
            else {
                throw SwiftJS.Value(newErrorFromMessage: "Invalid type of callback", in: self)
            }
            let ms = arguments.count > 1 ? (arguments[1].numberValue ?? 0) : 0
            let id = self.createTimer(
                callback: arguments[0], ms: ms, repeats: false,
                arguments: Array(arguments.dropFirst(2)))
            return .init(integerLiteral: id)
        }
        self.globalObject["clearTimeout"] = .init(in: self) { arguments, _ -> Void in
            guard arguments.count > 0,
                let numberValue = arguments[0].numberValue,
                numberValue.isFinite,
                let id = Int(exactly: numberValue)
            else {
                // Silently ignore invalid IDs like browsers do
                return
            }
            self.removeTimer(identifier: id)
        }
        self.globalObject["setInterval"] = .init(in: self) { arguments, _ in
            guard arguments.count > 0,
                !arguments[0].isNull,
                !arguments[0].isUndefined,
                arguments[0].isFunction
            else {
                throw SwiftJS.Value(newErrorFromMessage: "Invalid type of callback", in: self)
            }
            let ms = arguments.count > 1 ? (arguments[1].numberValue ?? 0) : 0
            let id = self.createTimer(
                callback: arguments[0], ms: ms, repeats: true,
                arguments: Array(arguments.dropFirst(2)))
            return .init(integerLiteral: id)
        }
        self.globalObject["clearInterval"] = .init(in: self) { arguments, _ -> Void in
            guard arguments.count > 0,
                let numberValue = arguments[0].numberValue,
                numberValue.isFinite,
                let id = Int(exactly: numberValue)
            else {
                // Silently ignore invalid IDs like browsers do
                return
            }
            self.removeTimer(identifier: id)
        }

        if let polyfillJs = String(data: Data(PackageResources.polyfill_js), encoding: .utf8) {
            self.evaluateScript(polyfillJs).call(withArguments: [
                [
                    "crypto": .init(JSCrypto(), in: self),
                    "processInfo": .init(JSProcessInfo(), in: self),
                    "processControl": .init(JSProcessControl(), in: self),
                    "deviceInfo": .init(JSDeviceInfo(), in: self),
                    "bundleInfo": .init(JSBundleInfo.main, in: self),
                    "FileSystem": .init(
                        JSFileSystem(context: self.context, runloop: self.runloop), in: self),
                    "URLSession": .init(JSURLSession(context: self.context), in: self),
                    "URLRequest": .init(JSURLRequest.self, in: self)
                ]
            ])
        }
    }
}
