//
//  session.swift
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
import NIOHTTP1

@objc protocol JSURLSessionExport: JSExport {
    
    func shared() -> JSURLSession
    
    func httpRequestWithRequest(
        _ requestConfig: JSValue,
        _ bodyStream: JSValue,
        _ progressHandler: JSValue
    ) -> JSValue?
}

@objc final class JSURLSession: NSObject, JSURLSessionExport, @unchecked Sendable {
    
    // Store reference to SwiftJS context for network tracking
    private let context: SwiftJS.Context

    init(context: SwiftJS.Context) {
        self.context = context
        super.init()
    }

    func shared() -> JSURLSession {
        return self
    }

    /// Unified HTTP request method using plain JavaScript request config object
    func httpRequestWithRequest(
        _ requestConfig: JSValue,
        _ bodyStream: JSValue,
        _ progressHandler: JSValue
    ) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        return JSValue(newPromiseIn: context) { resolve, reject in
            Task {
                // Start network request tracking
                let networkId = self.context.startNetworkRequest()

                // Ensure endNetworkRequest is called exactly once when the response stream finishes or errors
                var didEndNetworkRequest = false
                let endLock = NSLock()
                let endOnce = {
                    endLock.lock()
                    let shouldEnd = !didEndNetworkRequest
                    if shouldEnd {
                        didEndNetworkRequest = true
                    }
                    endLock.unlock()

                    if shouldEnd {
                        self.context.endNetworkRequest(networkId)
                    }
                }

                do {
                    let streamController = StreamController(
                        context: context,
                        progressHandler: progressHandler,
                        onComplete: endOnce
                    )

                    let responseHead: HTTPResponseHead

                    if !bodyStream.isNull && !bodyStream.isUndefined {
                        // Upload with body stream
                        // Create AsyncStream from JavaScript stream
                        let streamReader = JSStreamReader(stream: bodyStream, context: context)
                        let dataStream = streamReader.createAsyncStream()

                        responseHead = try await NIOHTTPClient.shared.executeStreamingUpload(
                            requestConfig,
                            bodyStream: dataStream,
                            streamController: streamController
                        )
                    } else {
                        // Regular request (GET/POST without streaming body)
                        responseHead = try await NIOHTTPClient.shared.executeStreamingRequest(
                            requestConfig,
                            streamController: streamController
                        )
                    }

                    // Create JSURLResponse from NIO response head
                    // Handle duplicate headers by combining values with commas (HTTP spec)
                    var headersDict: [String: String] = [:]
                    for header in responseHead.headers {
                        let key = header.name
                        let value = header.value
                        if let existing = headersDict[key] {
                            headersDict[key] = existing + ", " + value
                        } else {
                            headersDict[key] = value
                        }
                    }

                    // Extract URL from request config
                    let urlString = requestConfig.forProperty("url").toString() ?? ""

                    let jsResponse = JSURLResponse(
                        statusCode: Int(responseHead.status.code),
                        headers: headersDict,
                        url: urlString
                    )

                    // resolve with JSURLResponse directly
                    resolve?.call(withArguments: [JSValue(object: jsResponse, in: context)!])
                } catch {
                    // Ensure we end network tracking on error as well
                    endOnce()
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: error.localizedDescription, in: context)!
                    ])
                }
            }
        }
    }
}
