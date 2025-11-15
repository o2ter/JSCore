//
//  core.swift
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

public struct SwiftJS {
    
    public let virtualMachine: VirtualMachine
    
    let base: JSContext
    let context = Context()
    
    public init(_ virtualMachine: VirtualMachine = VirtualMachine()) {
        self.virtualMachine = virtualMachine
        self.base = JSContext(virtualMachine: virtualMachine.base)
        self.base.exceptionHandler = { context, exception in
            guard let message = exception?.toString() else { return }
            print(message)
        }
        self.polyfill()
    }
}

extension SwiftJS: @unchecked Sendable {}

extension SwiftJS {
    
    public var runloop: RunLoop {
        return self.virtualMachine.runloop
    }
    
    /// Check if there are any active JavaScript timers
    public var hasActiveTimers: Bool {
        return self.context.hasActiveTimers
    }

    /// Get the count of active JavaScript timers
    public var activeTimerCount: Int {
        return self.context.activeTimerCount
    }
    
    /// Check if there are any active network requests
    public var hasActiveNetworkRequests: Bool {
        return self.context.hasActiveNetworkRequests
    }

    /// Get the count of active network requests
    public var activeNetworkRequestCount: Int {
        return self.context.activeNetworkRequestCount
    }
    
    /// Check if there are any active file handles
    public var hasActiveFileHandles: Bool {
        return self.context.hasActiveFileHandles
    }

    /// Get the count of active file handles
    public var activeFileHandleCount: Int {
        return self.context.activeFileHandleCount
    }
    
    /// Check if there are any active WebSocket connections
    public var hasActiveWebSockets: Bool {
        return self.context.hasActiveWebSockets
    }

    /// Get the count of active WebSocket connections
    public var activeWebSocketCount: Int {
        return self.context.activeWebSocketCount
    }

    /// Check if there are any active async operations (timers, network, file handles, or WebSockets)
    public var hasActiveOperations: Bool {
        return hasActiveTimers || hasActiveNetworkRequests || hasActiveFileHandles
            || hasActiveWebSockets
    }
}

extension SwiftJS {
    
    public var globalObject: SwiftJS.Value {
        return SwiftJS.Value(self.base.globalObject)
    }
    
    public var exception: SwiftJS.Value {
        return self.base.exception.map(SwiftJS.Value.init) ?? .undefined
    }
    
    @discardableResult
    public func evaluateScript(_ script: String) -> SwiftJS.Value {
        let result = self.base.evaluateScript(script)
        return result.map(SwiftJS.Value.init) ?? .undefined
    }
    
    @discardableResult
    public func evaluateScript(_ script: String, withSourceURL sourceURL: URL) -> SwiftJS.Value {
        let result = self.base.evaluateScript(script, withSourceURL: sourceURL)
        return result.map(SwiftJS.Value.init) ?? .undefined
    }
}
