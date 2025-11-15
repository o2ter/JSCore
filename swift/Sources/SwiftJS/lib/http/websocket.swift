//
//  websocket.swift
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

@objc protocol JSWebSocketExport: JSExport {
    func createWebSocket(
        _ url: String, _ protocols: JSValue, _ onOpen: JSValue, _ onMessage: JSValue,
        _ onError: JSValue, _ onClose: JSValue
    ) -> String
    func send(_ socketId: String, _ data: JSValue) -> Bool
    func close(_ socketId: String, _ code: Int, _ reason: String) -> Bool
    func getReadyState(_ socketId: String) -> Int
    func getBufferedAmount(_ socketId: String) -> Int
}

@objc final class JSWebSocket: NSObject, JSWebSocketExport, @unchecked Sendable {

    private let context: SwiftJS.Context
    private let runloop: RunLoop
    private var sockets: [String: WebSocketConnection] = [:]
    private let socketsLock = NSLock()

    init(context: SwiftJS.Context, runloop: RunLoop) {
        self.context = context
        self.runloop = runloop
        super.init()
    }
    
    // Called by WebSocketConnection when connection fails/closes unexpectedly
    fileprivate func cleanupAfterError(socketId: String) {
        socketsLock.lock()
        sockets.removeValue(forKey: socketId)
        socketsLock.unlock()

        context.stopWebSocket(socketId)
    }

    func createWebSocket(
        _ url: String, _ protocols: JSValue, _ onOpen: JSValue, _ onMessage: JSValue,
        _ onError: JSValue, _ onClose: JSValue
    ) -> String {
        guard let socketURL = URL(string: url) else {
            // Call error callback with invalid URL error
            let errorMessage = "Invalid WebSocket URL: \(url)"
            runloop.perform {
                _ = onError.call(withArguments: [errorMessage])
            }
            return ""
        }

        // Parse protocols array
        var protocolArray: [String] = []
        if protocols.isArray {
            let length = protocols.forProperty("length").toInt32()
            for i in 0..<length {
                if let protocolStr = protocols.atIndex(Int(i))?.toString() {
                    protocolArray.append(protocolStr)
                }
            }
        }

        // Generate unique socket ID
        let socketId = UUID().uuidString

        // Create URLSessionWebSocketTask
        var request = URLRequest(url: socketURL)
        if !protocolArray.isEmpty {
            request.setValue(
                protocolArray.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }

        let session = URLSession(configuration: .default)
        let webSocketTask = session.webSocketTask(with: request)

        // Create connection object
        let connection = WebSocketConnection(
            socketId: socketId,
            task: webSocketTask,
            onOpen: onOpen,
            onMessage: onMessage,
            onError: onError,
            onClose: onClose,
            runloop: runloop,
            parent: self
        )

        socketsLock.lock()
        sockets[socketId] = connection
        socketsLock.unlock()

        // Start tracking WebSocket
        context.startWebSocket(socketId)

        // Start receiving messages
        connection.startReceiving()

        // Resume the task (establishes connection)
        webSocketTask.resume()

        return socketId
    }

    func send(_ socketId: String, _ data: JSValue) -> Bool {
        socketsLock.lock()
        guard let connection = sockets[socketId] else {
            socketsLock.unlock()
            return false
        }
        socketsLock.unlock()

        return connection.send(data)
    }

    func close(_ socketId: String, _ code: Int, _ reason: String) -> Bool {
        socketsLock.lock()
        guard let connection = sockets[socketId] else {
            socketsLock.unlock()
            return false
        }
        
        // Remove from dictionary immediately - close event is already scheduled with captured data
        sockets.removeValue(forKey: socketId)
        socketsLock.unlock()

        connection.close(code: code, reason: reason)

        // Stop tracking WebSocket immediately - the close event will still fire
        context.stopWebSocket(socketId)

        return true
    }

    func getReadyState(_ socketId: String) -> Int {
        socketsLock.lock()
        guard let connection = sockets[socketId] else {
            socketsLock.unlock()
            return 3  // CLOSED
        }
        socketsLock.unlock()

        return connection.readyState
    }

    func getBufferedAmount(_ socketId: String) -> Int {
        socketsLock.lock()
        guard let connection = sockets[socketId] else {
            socketsLock.unlock()
            return 0
        }
        socketsLock.unlock()

        return connection.bufferedAmount
    }
}

private class WebSocketConnection: @unchecked Sendable {
    let task: URLSessionWebSocketTask
    let onOpen: JSValue
    let onMessage: JSValue
    let onError: JSValue
    let onClose: JSValue
    let runloop: RunLoop
    let socketId: String
    weak var parent: JSWebSocket?

    private(set) var readyState: Int = 0  // 0=CONNECTING, 1=OPEN, 2=CLOSING, 3=CLOSED
    private(set) var bufferedAmount: Int = 0
    private var closeFired = false
    private let lock = NSLock()

    init(
        socketId: String,
        task: URLSessionWebSocketTask, onOpen: JSValue, onMessage: JSValue, onError: JSValue,
        onClose: JSValue, runloop: RunLoop, parent: JSWebSocket?
    ) {
        self.socketId = socketId
        self.task = task
        self.onOpen = onOpen
        self.onMessage = onMessage
        self.onError = onError
        self.onClose = onClose
        self.runloop = runloop
        self.parent = parent

        // Set initial state to CONNECTING
        self.readyState = 0
    }

    func startReceiving() {
        receiveNext()
    }

    private func receiveNext() {
        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                // Update ready state to OPEN when we receive first message
                self.lock.lock()
                if self.readyState == 0 {
                    self.readyState = 1
                    self.lock.unlock()

                    // Fire onopen event
                    self.runloop.perform {
                        _ = self.onOpen.call(withArguments: [])
                    }
                } else {
                    self.lock.unlock()
                }

                // Handle message
                switch message {
                case .string(let text):
                    self.runloop.perform {
                        let event = ["data": text]
                        _ = self.onMessage.call(withArguments: [event])
                    }

                case .data(let data):
                    self.runloop.perform {
                        guard let jsContext = JSContext.current() else { return }
                        let jsArrayBuffer = JSValue.uint8Array(count: data.count, in: jsContext) {
                            buffer in
                            _ = data.copyBytes(to: buffer.bindMemory(to: UInt8.self))
                        }
                        let event = ["data": jsArrayBuffer as Any]
                        _ = self.onMessage.call(withArguments: [event])
                    }

                @unknown default:
                    break
                }

                // Continue receiving
                self.receiveNext()

            case .failure(let error):
                // Update state to CLOSED
                self.lock.lock()
                self.readyState = 3
                let alreadyClosed = self.closeFired
                self.closeFired = true
                self.lock.unlock()

                // Only fire close event if not already fired
                if !alreadyClosed {
                    // Check if this is a normal close
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // Normal close from our close() method - don't fire duplicate event
                    } else {
                        // Fire error event for unexpected errors
                        self.runloop.perform {
                            _ = self.onError.call(withArguments: [error.localizedDescription])
                        }

                        // Fire close event
                        self.runloop.perform {
                            let closeEvent = [
                                "code": 1006,  // Abnormal closure
                                "reason": error.localizedDescription,
                                "wasClean": false,
                            ]
                            _ = self.onClose.call(withArguments: [closeEvent])
                        }
                        
                        // Clean up tracking when connection fails
                        self.parent?.cleanupAfterError(socketId: self.socketId)
                    }
                }
            }
        }
    }

    func send(_ data: JSValue) -> Bool {
        lock.lock()
        guard readyState == 1 else {
            lock.unlock()
            return false
        }
        lock.unlock()

        if data.isString {
            let message = URLSessionWebSocketTask.Message.string(data.toString())
            task.send(message) { [weak self] error in
                if let error = error, let self = self {
                    self.runloop.perform {
                        _ = self.onError.call(withArguments: [error.localizedDescription])
                    }
                }
            }
            return true
        } else if data.isObject {
            // Try to get ArrayBuffer or TypedArray
            var messageData: Data?
            guard let jsContext = JSContext.current() else { return false }

            if data.hasProperty("buffer") && data.hasProperty("byteLength") {
                // TypedArray
                if let arrayBuffer = data.forProperty("buffer") {
                    var length: size_t = 0
                    if let bytes = JSObjectGetArrayBufferBytesPtr(
                        jsContext.jsGlobalContextRef, arrayBuffer.jsValueRef, nil)
                    {
                        length = JSObjectGetArrayBufferByteLength(
                            jsContext.jsGlobalContextRef, arrayBuffer.jsValueRef, nil)
                        messageData = Data(bytes: bytes, count: length)
                    }
                }
            } else if let bytes = JSObjectGetArrayBufferBytesPtr(
                jsContext.jsGlobalContextRef, data.jsValueRef, nil)
            {
                // ArrayBuffer
                let length = JSObjectGetArrayBufferByteLength(
                    jsContext.jsGlobalContextRef, data.jsValueRef, nil)
                messageData = Data(bytes: bytes, count: length)
            }

            if let messageData = messageData {
                let message = URLSessionWebSocketTask.Message.data(messageData)
                task.send(message) { [weak self] error in
                    if let error = error, let self = self {
                        self.runloop.perform {
                            _ = self.onError.call(withArguments: [error.localizedDescription])
                        }
                    }
                }
                return true
            }
        }

        return false
    }

    func close(code: Int, reason: String) {
        lock.lock()
        guard readyState != 3 else {
            lock.unlock()
            return
        }
        readyState = 2  // CLOSING
        closeFired = true  // Mark that we're firing the close event
        lock.unlock()

        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
        task.cancel(with: closeCode, reason: reason.data(using: .utf8))

        lock.lock()
        readyState = 3  // CLOSED
        lock.unlock()

        // Fire close event
        runloop.perform {
            let closeEvent = [
                "code": code,
                "reason": reason,
                "wasClean": true,
            ]
            _ = self.onClose.call(withArguments: [closeEvent])
        }
    }
}
