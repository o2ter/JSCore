//
//  streaming.swift
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
import NIO
import NIOHTTP1
import NIOFoundationCompat
import AsyncHTTPClient

/// Stream controller that calls progress handler for each chunk
/// Used for streaming methods that need to report progress
final class StreamController: @unchecked Sendable {
    private let context: JSContext
    private let progressHandler: JSValue
    private let onComplete: () -> Void

    init(context: JSContext, progressHandler: JSValue, onComplete: @escaping () -> Void) {
        self.context = context
        self.progressHandler = progressHandler
        self.onComplete = onComplete
    }

    func enqueue(_ chunk: Data) {
        // Call progress handler if provided - ensure we call on the JSContext's thread
        guard !chunk.isEmpty else { return }
        
        let uint8Array = JSValue.uint8Array(count: chunk.count, in: self.context) {
            buffer in
            chunk.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: chunk.count)
        }
        // Call progress handler with data chunk and no error
        progressHandler.call(withArguments: [uint8Array, false])
    }

    func error(_ error: Error) {
        // Also call progressHandler with error indicator (empty chunk + completion)
        // This allows the JavaScript polyfill to handle cleanup if needed
        let emptyArray = JSValue.uint8Array(count: 0, in: context) { _ in }
        let jsError = JSValue(newErrorFromMessage: error.localizedDescription, in: context)!
        progressHandler.call(withArguments: [emptyArray, jsError])
        // Notify completion/error to caller
        onComplete()
    }

    func close() {
        let emptyArray = JSValue.uint8Array(count: 0, in: self.context) { _ in }
        progressHandler.call(withArguments: [emptyArray, false])
        // Notify completion when stream closed
        onComplete()
    }
}

/// NIO-based HTTP client for streaming requests and responses
final class NIOHTTPClient: @unchecked Sendable {
    private let httpClient: HTTPClient
    private let eventLoopGroup: EventLoopGroup
    
    static let shared = NIOHTTPClient()
    
    private init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // Configure HTTP client to NOT follow redirects automatically
        // This allows our JavaScript fetch implementation to handle redirects according to the Fetch API spec
        var configuration = HTTPClient.Configuration()
        configuration.redirectConfiguration = .disallow

        self.httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(eventLoopGroup),
            configuration: configuration
        )
    }
    
    deinit {
        try? httpClient.syncShutdown()
        try? eventLoopGroup.syncShutdownGracefully()
    }
    
    /// Execute a streaming HTTP request
    func executeStreamingRequest(
        _ request: JSURLRequest,
        streamController: StreamController
    ) async throws -> HTTPResponseHead {
        
        // Convert JSURLRequest to HTTPClient.Request
        guard let urlString = request.url else {
            throw HTTPClientError.invalidURL
        }
        
        var httpRequest = HTTPClientRequest(url: urlString)
        httpRequest.method = HTTPMethod(rawValue: request.httpMethod.uppercased())
        
        // Add headers
        for (key, value) in request.allHTTPHeaderFields {
            httpRequest.headers.add(name: key, value: value)
        }
        
        // Handle request body
        // First check the bodyData property directly
        if let httpBodyData = request.bodyData {
            httpRequest.body = .bytes(httpBodyData)
        } else if let httpBody = request.httpBody {
            // Fallback to JSValue property if no body data
            if httpBody.isTypedArray {
                let bodyData = httpBody.typedArrayBytes
                let data = Data(bodyData.bindMemory(to: UInt8.self))
                httpRequest.body = .bytes(data)
            } else if httpBody.isString {
                let data = httpBody.toString().data(using: .utf8) ?? Data()
                httpRequest.body = .bytes(data)
            }
        }
        
        // Execute request and stream response
        let response = try await httpClient.execute(
            httpRequest,
            deadline: .now() + .seconds(Int64(request.timeoutInterval))
        )
        
        // Stream response body in a detached task to avoid data races
        let controller = streamController
        Task.detached {
            do {
                for try await buffer in response.body {
                    let data = Data(buffer: buffer)
                    controller.enqueue(data)
                }
                controller.close()
            } catch {
                controller.error(error)
            }
        }
        
        return HTTPResponseHead(
            version: response.version,
            status: HTTPResponseStatus(statusCode: Int(response.status.code)),
            headers: HTTPHeaders(response.headers.map { ($0.name, $0.value) })
        )
    }
    
    /// Execute a streaming upload request with body stream
    func executeStreamingUpload(
        _ request: JSURLRequest,
        bodyStream: AsyncStream<Data>,
        streamController: StreamController
    ) async throws -> HTTPResponseHead {
        
        guard let urlString = request.url else {
            throw HTTPClientError.invalidURL
        }
        
        var httpRequest = HTTPClientRequest(url: urlString)
        httpRequest.method = HTTPMethod(rawValue: request.httpMethod.uppercased())
        
        // Add headers
        for (key, value) in request.allHTTPHeaderFields {
            httpRequest.headers.add(name: key, value: value)
        }
        
        // Create streaming body from AsyncStream
        httpRequest.body = .stream(
            bodyStream.map { ByteBuffer(data: $0) },
            length: .unknown
        )
        
        // Execute request and stream response
        let response = try await httpClient.execute(
            httpRequest,
            deadline: .now() + .seconds(Int64(request.timeoutInterval))
        )
        
        // Stream response body in a detached task to avoid data races
        let controller = streamController
        Task.detached {
            do {
                for try await buffer in response.body {
                    let data = Data(buffer: buffer)
                    controller.enqueue(data)
                }
                controller.close()
            } catch {
                controller.error(error)
            }
        }
        
        return HTTPResponseHead(
            version: response.version,
            status: HTTPResponseStatus(statusCode: Int(response.status.code)),
            headers: HTTPHeaders(response.headers.map { ($0.name, $0.value) })
        )
    }
}

/// JavaScript ReadableStream reader for request bodies
final class JSStreamReader: @unchecked Sendable {
    private let reader: JSValue
    private let context: JSContext
    
    init(stream: JSValue, context: JSContext) {
        self.context = context
        // Use invokeMethod to preserve the JS 'this' binding when calling getReader
        if let invoked = stream.invokeMethod("getReader", withArguments: []) {
            self.reader = invoked
        } else {
            self.reader = JSValue(nullIn: context)!
        }
    }
    
    /// Create an AsyncStream from a JavaScript ReadableStream
    func createAsyncStream() -> AsyncStream<Data> {
        AsyncStream { continuation in
            Task {
                await self.readAllChunks(continuation: continuation)
            }
        }
    }
    
    @MainActor
    private func readAllChunks(continuation: AsyncStream<Data>.Continuation) async {
        while true {
            guard let readPromise = reader.invokeMethod("read", withArguments: []),
                !readPromise.isUndefined
            else {
                continuation.finish()
                return
            }
            
            // Convert JS Promise to Swift async
            do {
                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<JSValue, Error>) in
                    // Use invokeMethod("then") to preserve the promise as 'this' when calling then
                    readPromise.invokeMethod(
                        "then",
                        withArguments: [
                        JSValue(newFunctionIn: context) { args, this in
                            if !args.isEmpty {
                                cont.resume(returning: args[0])
                            } else {
                                cont.resume(throwing: JSStreamError.invalidResult)
                            }
                            return JSValue(undefinedIn: self.context)!
                        },
                        JSValue(newFunctionIn: context) { args, this in
                            if !args.isEmpty {
                                cont.resume(throwing: JSStreamError.streamError(args[0].toString()))
                            } else {
                                cont.resume(throwing: JSStreamError.unknownError)
                            }
                            return JSValue(undefinedIn: self.context)!
                        }
                    ])
                }
                
                let done = result.objectForKeyedSubscript("done")?.toBool() ?? true
                if done {
                    continuation.finish()
                    return
                }
                
                if let value = result.objectForKeyedSubscript("value"),
                   value.isTypedArray {
                    let bytes = value.typedArrayBytes
                    let data = Data(bytes.bindMemory(to: UInt8.self))
                    continuation.yield(data)
                }
                
            } catch {
                continuation.finish()
                return
            }
        }
    }
}

enum JSStreamError: Error {
    case invalidResult
    case streamError(String)
    case unknownError
}

enum HTTPClientError: Error {
    case invalidURL
    case invalidResponse
}
