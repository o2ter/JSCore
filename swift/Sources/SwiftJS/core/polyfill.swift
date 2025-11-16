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
        let timerLock = NSLock()

        var networkRequestId: Int = 0
        var networkRequests: Set<Int> = []
        private let networkLock = NSLock()

        // WebSocket connection tracking
        var activeWebSockets: Set<String> = []
        private let webSocketLock = NSLock()

        // File handle management for continuous reading
        var openFileHandles: [Int: FileHandle] = [:]
        var handleCounter = 0
        let handleLock = NSLock()
        
        // Directory enumerator management for streaming directory iteration
        var openDirectoryEnumerators: [Int: (FileManager.DirectoryEnumerator, String)] = [:]
        var nextHandleId: Int = 0

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

        /// Check if there are any active WebSocket connections
        var hasActiveWebSockets: Bool {
            webSocketLock.lock()
            defer { webSocketLock.unlock() }
            return !activeWebSockets.isEmpty
        }

        /// Get count of active WebSocket connections
        var activeWebSocketCount: Int {
            webSocketLock.lock()
            defer { webSocketLock.unlock() }
            return activeWebSockets.count
        }

        /// Start tracking a WebSocket connection
        func startWebSocket(_ socketId: String) {
            webSocketLock.lock()
            defer { webSocketLock.unlock() }
            activeWebSockets.insert(socketId)
        }

        /// Stop tracking a WebSocket connection
        func stopWebSocket(_ socketId: String) {
            webSocketLock.lock()
            defer { webSocketLock.unlock() }
            activeWebSockets.remove(socketId)
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
            
            // Clear all directory enumerators
            openDirectoryEnumerators.removeAll()
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

    func polyfill() {
        // Setup console APIs
        self.setupConsoleAPIs()

        // Setup timer APIs
        self.setupTimerAPIs()

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
                    "WebSocket": .init(
                        JSWebSocket(context: self.context, runloop: self.runloop), in: self),
                    "compression": .init(JSCompression(), in: self),
                    "performance": .init(JSPerformance(), in: self)
                ]
            ])
        }
    }
}
