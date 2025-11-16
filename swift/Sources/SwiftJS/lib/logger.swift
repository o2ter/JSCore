//
//  logger.swift
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
    
    public enum LogLevel {
        case log
        case trace
        case debug
        case info
        case warn
        case error
    }
}

extension SwiftJS.LogLevel {
    
    public static var allCases: [SwiftJS.LogLevel] {
        return [.log, .trace, .debug, .info, .warn, .error]
    }
    
    public var name: String {
        switch self {
        case .log: return "log"
        case .trace: return "trace"
        case .debug: return "debug"
        case .info: return "info"
        case .warn: return "warn"
        case .error: return "error"
        }
    }
}

extension SwiftJS {
    
    public var logger: @Sendable (LogLevel, [SwiftJS.Value]) -> Void {
        get { self.context.logger }
        nonmutating set {
            self.runloop.perform {
                self.context.logger = newValue
            }
        }
    }
}
