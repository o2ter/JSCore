//
//  timer.swift
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

    func createTimer(
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

    func removeTimer(identifier: Int) {
        // Remove timer directly - we're already on the JavaScript context's thread
        context.timerLock.lock()
        let timer = context.timer.removeValue(forKey: identifier)
        context.timerLock.unlock()
        timer?.invalidate()
    }
}

extension SwiftJS {

    func setupTimerAPIs() {
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
    }
}
