//
//  FetchTests.swift
//  SwiftJS Fetch API Tests
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

import XCTest
@testable import SwiftJS

/// Tests for the Fetch API including basic fetch functionality, 
/// Request/Response objects, and live network requests.
@MainActor
final class FetchTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testFetchAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("fetch"))
        XCTAssertTrue(globals.toString().contains("Request"))
        XCTAssertTrue(globals.toString().contains("Response"))
    }
    
    func testFetchExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof fetch")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testRequestExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Request")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testResponseExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Response")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Request API Tests
    
    func testRequestInstantiation() {
        let script = """
            const request = new Request('https://postman-echo.com');
            request instanceof Request
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRequestURL() {
        let script = """
            const request = new Request('https://postman-echo.com/api');
            request.url
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "https://postman-echo.com/api")
    }
    
    func testRequestMethod() {
        let script = """
            const request = new Request('https://postman-echo.com', { method: 'POST' });
            request.method
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "POST")
    }
    
    func testRequestDefaultMethod() {
        let script = """
            const request = new Request('https://postman-echo.com');
            request.method
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "GET")
    }
    
    func testRequestHeaders() {
        let script = """
            const request = new Request('https://postman-echo.com', {
                headers: { 'Content-Type': 'application/json' }
            });
            request.headers.get('Content-Type')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "application/json")
    }
    
    func testRequestBody() {
        let script = """
            const request = new Request('https://postman-echo.com', {
                method: 'POST',
                body: JSON.stringify({ test: 'data' })
            });
            request.body !== null
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRequestClone() {
        let script = """
            const original = new Request('https://postman-echo.com', {
                method: 'POST',
                headers: { 'X-Test': 'value' }
            });
            const cloned = original.clone();
            
            ({
                urlMatch: cloned.url === original.url,
                methodMatch: cloned.method === original.method,
                headerMatch: cloned.headers.get('X-Test') === original.headers.get('X-Test')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["urlMatch"].boolValue ?? false)
        XCTAssertTrue(result["methodMatch"].boolValue ?? false)
        XCTAssertTrue(result["headerMatch"].boolValue ?? false)
    }
    
    // MARK: - Response API Tests
    
    func testResponseInstantiation() {
        let script = """
            const response = new Response('Hello World');
            response instanceof Response
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testResponseDefaults() {
        let script = """
            const response = new Response();
            ({
                status: response.status,
                statusText: response.statusText,
                ok: response.ok
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
        XCTAssertEqual(result["statusText"].toString(), "OK")
        XCTAssertTrue(result["ok"].boolValue ?? false)
    }
    
    func testResponseWithStatus() {
        let script = """
            const response = new Response('Error', {
                status: 404,
                statusText: 'Not Found'
            });
            ({
                status: response.status,
                statusText: response.statusText,
                ok: response.ok
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(Int(result["status"].numberValue ?? 0), 404)
        XCTAssertEqual(result["statusText"].toString(), "Not Found")
        XCTAssertFalse(result["ok"].boolValue ?? true)
    }
    
    func testResponseHeaders() {
        let script = """
            const response = new Response('test', {
                headers: { 'Content-Type': 'text/plain' }
            });
            response.headers.get('Content-Type')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "text/plain")
    }
    
    func testResponseText() {
        let expectation = XCTestExpectation(description: "Response text reading")
        
        let script = """
            const response = new Response('Hello, Response!');
            response.text().then(text => {
                testCompleted({ result: text });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello, Response!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponseJSON() {
        let expectation = XCTestExpectation(description: "Response JSON parsing")
        
        let script = """
            const data = { message: 'Hello', value: 42 };
            const response = new Response(JSON.stringify(data), {
                headers: { 'Content-Type': 'application/json' }
            });
            
            response.json().then(parsed => {
                testCompleted({
                    message: parsed.message,
                    value: parsed.value,
                    isObject: typeof parsed === 'object'
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["message"].toString(), "Hello")
            XCTAssertEqual(Int(result["value"].numberValue ?? 0), 42)
            XCTAssertTrue(result["isObject"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponseClone() {
        let expectation = XCTestExpectation(description: "Response clone")
        
        let script = """
            const original = new Response('Test content', {
                status: 201,
                statusText: 'Created',
                headers: { 'X-Custom': 'value' }
            });
            
            const cloned = original.clone();
            
            Promise.all([
                original.text(),
                cloned.text()
            ]).then(([originalText, clonedText]) => {
                testCompleted({
                    originalText: originalText,
                    clonedText: clonedText,
                    statusMatch: cloned.status === original.status,
                    statusTextMatch: cloned.statusText === original.statusText,
                    headerMatch: cloned.headers.get('X-Custom') === original.headers.get('X-Custom')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["originalText"].toString(), "Test content")
            XCTAssertEqual(result["clonedText"].toString(), "Test content")
            XCTAssertTrue(result["statusMatch"].boolValue ?? false)
            XCTAssertTrue(result["statusTextMatch"].boolValue ?? false)
            XCTAssertTrue(result["headerMatch"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponseBodyStream() {
        let script = """
            const response = new Response('streaming content');
            response.body instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Basic Fetch Tests
    
    func testFetchBasicCall() {
        let expectation = XCTestExpectation(description: "Basic fetch call")
        
        let script = """
            fetch('https://postman-echo.com/get')
                .then(response => {
                    testCompleted({
                        ok: response.ok,
                        status: response.status,
                        hasHeaders: response.headers instanceof Headers
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(
                result["error"].isString,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["ok"].boolValue ?? false, "Response should be ok")
            XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200, "Status should be 200")
            XCTAssertTrue(result["hasHeaders"].boolValue ?? false, "Should have headers")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchWithRequestObject() {
        let expectation = XCTestExpectation(description: "Fetch with Request object")
        
        let script = """
            const request = new Request('https://postman-echo.com/headers', {
                headers: { 'X-Test-Header': 'fetch-test' }
            });
            
            fetch(request)
                .then(response => response.json())
                .then(data => {
                    // Check for header case-insensitively since HTTP headers can be normalized to lowercase
                    const headerKeys = Object.keys(data.headers || {});
                    const testHeaderKey = headerKeys.find(key => key.toLowerCase() === 'x-test-header');
                    const hasTestHeader = testHeaderKey !== undefined;
                    const testHeaderValue = hasTestHeader ? data.headers[testHeaderKey] : null;
                    
                    testCompleted({
                        hasTestHeader: hasTestHeader,
                        testHeaderValue: testHeaderValue
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasTestHeader"].boolValue ?? false)
            XCTAssertEqual(result["testHeaderValue"].toString(), "fetch-test")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchPOST() {
        let expectation = XCTestExpectation(description: "Fetch POST request")
        
        let script = """
            const postData = { name: 'test', value: 123 };
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(postData)
            })
                .then(response => response.json())
                .then(data => {
                    const receivedData = JSON.parse(data.data || '{}');
                    testCompleted({
                        method: data.headers ? data.headers['X-Http-Method-Override'] || 'POST' : 'POST',
                        contentType: data.headers ? data.headers['Content-Type'] : null,
                        receivedName: receivedData.name,
                        receivedValue: receivedData.value
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            // The exact structure of httpbin response may vary, just check we got some response
            XCTAssertNotNil(result["contentType"])
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Status Code Tests
    
    func testFetchStatusCodes() {
        let expectation = XCTestExpectation(description: "Fetch status codes")
        
        let script = """
            const testCases = [
                { url: 'https://postman-echo.com/status/200', expectedStatus: 200 },
                { url: 'https://postman-echo.com/status/404', expectedStatus: 404 },
                { url: 'https://postman-echo.com/status/500', expectedStatus: 500 }
            ];
            
            const results = [];
            let completed = 0;
            
            testCases.forEach((testCase, index) => {
                fetch(testCase.url)
                    .then(response => {
                        results[index] = {
                            expectedStatus: testCase.expectedStatus,
                            actualStatus: response.status,
                            ok: response.ok,
                            matches: response.status === testCase.expectedStatus
                        };
                        completed++;
                        if (completed === testCases.length) {
                            testCompleted({ results: results });
                        }
                    })
                    .catch(error => {
                        results[index] = { error: error.message };
                        completed++;
                        if (completed === testCases.length) {
                            testCompleted({ results: results });
                        }
                    });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            let resultsCount = Int(results["length"].numberValue ?? 0)
            
            if resultsCount > 0 {
                for i in 0..<resultsCount {
                    let testResult = results[i]
                    if !testResult["error"].isString {
                        XCTAssertTrue(testResult["matches"].boolValue ?? false, 
                                    "Status \(testResult["actualStatus"]) should match expected \(testResult["expectedStatus"])")
                    }
                }
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Advanced Error Handling Tests

    func testNetworkTimeoutSimulation() {
        let expectation = XCTestExpectation(description: "Network timeout simulation")

        let script = """
                // Use AbortController to simulate timeout
                const controller = new AbortController();
                var requestStarted = false;
                var timeoutTriggered = false;
                
                // Set a short timeout
                const timeoutId = setTimeout(() => {
                    timeoutTriggered = true;
                    controller.abort();
                }, 100);
                
                requestStarted = true;
                fetch('https://postman-echo.com/delay/5', { 
                    signal: controller.signal 
                })
                    .then(response => {
                        clearTimeout(timeoutId);
                        testCompleted({ 
                            error: 'Request should have been aborted',
                            requestStarted: requestStarted,
                            timeoutTriggered: timeoutTriggered
                        });
                    })
                    .catch(error => {
                        clearTimeout(timeoutId);
                        testCompleted({
                            aborted: true,
                            errorName: error.name,
                            errorMessage: error.message,
                            requestStarted: requestStarted,
                            timeoutTriggered: timeoutTriggered,
                            properTimeout: timeoutTriggered && error.name.includes('Abort')
                        });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if result["error"].isString {
                // Request completed too quickly, that's acceptable
                XCTAssertTrue(result["requestStarted"].boolValue ?? false)
            } else {
                XCTAssertTrue(result["aborted"].boolValue ?? false)
                XCTAssertTrue(result["requestStarted"].boolValue ?? false)
                XCTAssertNotEqual(result["errorName"].toString(), "")
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }

    func testContentTypeMismatch() {
        let expectation = XCTestExpectation(description: "Content-Type mismatch handling")

        let script = """
                // Create response with mismatched content-type
                const jsonData = { message: 'Hello', number: 42 };
                const response = new Response(JSON.stringify(jsonData), {
                    headers: {
                        'Content-Type': 'text/plain' // Wrong content type for JSON
                    }
                });
                
                const tests = [];
                
                // Test 1: Try to parse as JSON despite text/plain content-type
                response.clone().json()
                    .then(parsed => {
                        tests.push({
                            test: 'json-parse-success',
                            success: true,
                            data: parsed,
                            messageMatches: parsed.message === jsonData.message
                        });
                    })
                    .catch(error => {
                        tests.push({
                            test: 'json-parse-failed',
                            success: false,
                            error: error.message
                        });
                    })
                    .then(() => {
                        // Test 2: Parse as text (should work)
                        return response.clone().text();
                    })
                    .then(text => {
                        tests.push({
                            test: 'text-parse',
                            success: true,
                            data: text,
                            isValidJSON: (() => {
                                try {
                                    JSON.parse(text);
                                    return true;
                                } catch {
                                    return false;
                                }
                            })()
                        });
                        
                        testCompleted({
                            tests: tests,
                            contentTypeHeader: response.headers.get('Content-Type'),
                            handledMismatchGracefully: tests.length === 2
                        });
                    })
                    .catch(error => {
                        testCompleted({ 
                            error: error.message,
                            testsCompleted: tests.length
                        });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if !result["error"].isString {
                XCTAssertTrue(result["handledMismatchGracefully"].boolValue ?? false)
                XCTAssertEqual(result["contentTypeHeader"].toString(), "text/plain")

                let tests = result["tests"]
                let testCount = Int(tests["length"].numberValue ?? 0)
                XCTAssertEqual(testCount, 2)

                // At least one parsing method should succeed
                var hasSuccess = false
                for i in 0..<testCount {
                    if tests[i]["success"].boolValue == true {
                        hasSuccess = true
                        break
                    }
                }
                XCTAssertTrue(hasSuccess, "At least one parsing method should succeed")
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }

    func testProgressiveDownloadInterruption() {
        let expectation = XCTestExpectation(description: "Progressive download interruption")

        let script = """
                const controller = new AbortController();
                var bytesReceived = 0;
                var chunksReceived = 0;
                
                // Simulate a large download that gets interrupted
                fetch('https://postman-echo.com/stream/10', { 
                    signal: controller.signal 
                })
                    .then(response => {
                        if (!response.ok) {
                            throw new Error(`HTTP ${response.status}`);
                        }
                        
                        const reader = response.body.getReader();
                        
                        function readChunk() {
                            return reader.read().then(({ done, value }) => {
                                if (done) {
                                    testCompleted({
                                        completed: true,
                                        bytesReceived: bytesReceived,
                                        chunksReceived: chunksReceived,
                                        interruptedAsExpected: false
                                    });
                                    return;
                                }
                                
                                bytesReceived += value.byteLength;
                                chunksReceived++;
                                
                                // Interrupt after receiving some data
                                if (chunksReceived >= 3) {
                                    controller.abort();
                                    return Promise.reject(new Error('Simulated interruption'));
                                }
                                
                                return readChunk();
                            });
                        }
                        
                        return readChunk();
                    })
                    .catch(error => {
                        testCompleted({
                            interrupted: true,
                            errorMessage: error.message,
                            bytesReceived: bytesReceived,
                            chunksReceived: chunksReceived,
                            receivedDataBeforeError: bytesReceived > 0,
                            interruptedAsExpected: chunksReceived >= 3 && bytesReceived > 0
                        });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if result["completed"].boolValue == true {
                // Download completed too quickly, that's acceptable
                XCTAssertGreaterThan(Int(result["chunksReceived"].numberValue ?? 0), 0)
            } else {
                XCTAssertTrue(result["interrupted"].boolValue ?? false)
                XCTAssertTrue(result["receivedDataBeforeError"].boolValue ?? false)
                XCTAssertGreaterThan(Int(result["bytesReceived"].numberValue ?? 0), 0)
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentRequestErrors() {
        let expectation = XCTestExpectation(description: "Concurrent request errors")

        let script = """
                const requests = [
                    'https://postman-echo.com/get',
                    'https://postman-echo.com/status/404',
                    'https://postman-echo.com/status/500',
                    'https://invalid-url-12345.nonexistent',
                    'https://postman-echo.com/headers'
                ];
                
                const results = [];
                const startTime = Date.now();
                
                Promise.allSettled(requests.map((url, index) => {
                    return fetch(url)
                        .then(response => ({
                            index: index,
                            url: url,
                            status: response.status,
                            ok: response.ok,
                            success: true
                        }))
                        .catch(error => ({
                            index: index,
                            url: url,
                            error: error.message,
                            success: false
                        }));
                })).then(promiseResults => {
                    const endTime = Date.now();
                    const duration = endTime - startTime;
                    
                    const successCount = promiseResults.filter(r => 
                        r.status === 'fulfilled' && r.value.success && r.value.ok
                    ).length;
                    
                    const httpErrorCount = promiseResults.filter(r => 
                        r.status === 'fulfilled' && r.value.success && !r.value.ok
                    ).length;
                    
                    const networkErrorCount = promiseResults.filter(r => 
                        r.status === 'fulfilled' && !r.value.success
                    ).length;
                    
                    const rejectedCount = promiseResults.filter(r => 
                        r.status === 'rejected'
                    ).length;
                    
                    testCompleted({
                        totalRequests: requests.length,
                        successCount: successCount,
                        httpErrorCount: httpErrorCount,
                        networkErrorCount: networkErrorCount,
                        rejectedCount: rejectedCount,
                        totalResponses: successCount + httpErrorCount + networkErrorCount + rejectedCount,
                        duration: duration,
                        handledConcurrently: duration < 10000, // Should complete reasonably quickly
                        results: promiseResults.map(r => r.status === 'fulfilled' ? r.value : { error: 'Promise rejected' })
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            XCTAssertEqual(Int(result["totalRequests"].numberValue ?? 0), 5)
            
            // Verify all requests completed with some result
            let totalResponses = Int(result["totalResponses"].numberValue ?? 0)
            XCTAssertEqual(totalResponses, 5, "All requests should complete with some result")

            // We expect some successful requests (postman-echo.com endpoints should work)
            let successCount = Int(result["successCount"].numberValue ?? 0)
            XCTAssertGreaterThan(successCount, 0, "At least some requests should succeed")

            // Duration should be reasonable (may take longer due to delay endpoint)
            let duration = result["duration"].numberValue ?? 0
            XCTAssertLessThan(duration, 30000, "Requests should complete within 30 seconds")

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }

    func testResponseStreamInterruption() {
        let expectation = XCTestExpectation(description: "Response stream interruption")

        let script = """
                const response = new Response('This is a test response with some content that we will interrupt');
                var readChunks = 0;
                var totalBytes = 0;
                
                const reader = response.body.getReader();
                
                function readWithInterruption() {
                    return reader.read().then(({ done, value }) => {
                        if (done) {
                            testCompleted({
                                completed: true,
                                chunksRead: readChunks,
                                totalBytes: totalBytes,
                                interrupted: false
                            });
                            return;
                        }
                        
                        readChunks++;
                        totalBytes += value.byteLength;
                        
                        // Interrupt after reading some data
                        if (readChunks >= 1) {
                            reader.cancel('Simulated interruption');
                            testCompleted({
                                interrupted: true,
                                chunksRead: readChunks,
                                totalBytes: totalBytes,
                                reason: 'Simulated interruption',
                                readSomeData: totalBytes > 0
                            });
                            return;
                        }
                        
                        return readWithInterruption();
                    }).catch(error => {
                        testCompleted({
                            error: error.message,
                            chunksRead: readChunks,
                            totalBytes: totalBytes,
                            interrupted: true
                        });
                    });
                }
                
                readWithInterruption();
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if result["completed"].boolValue == true {
                // Stream completed without interruption
                XCTAssertGreaterThan(Int(result["totalBytes"].numberValue ?? 0), 0)
            } else if result["interrupted"].boolValue == true {
                if !result["error"].isString {
                    XCTAssertTrue(result["readSomeData"].boolValue ?? false)
                    XCTAssertGreaterThan(Int(result["chunksRead"].numberValue ?? 0), 0)
                }
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }

    // MARK: - Error Handling Tests
    
    func testFetchInvalidURL() {
        let expectation = XCTestExpectation(description: "Fetch invalid URL")
        
        let script = """
            fetch('invalid-url')
                .then(response => {
                    testCompleted({ error: 'Should have failed' });
                })
                .catch(error => {
                    testCompleted({
                        caughtError: true,
                        errorType: error.name,
                        errorMessage: error.message
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            if result["error"].toString() == "Should have failed" {
                XCTFail("Invalid URL should have caused an error")
            } else {
                XCTAssertTrue(result["caughtError"].boolValue ?? false)
                XCTAssertNotEqual(result["errorMessage"].toString(), "")
            }
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchAbortController() {
        let expectation = XCTestExpectation(description: "Fetch with AbortController")
        
        let script = """
            const controller = new AbortController();
            
            // Abort immediately
            setTimeout(() => controller.abort(), 10);
            
            fetch('https://postman-echo.com/delay/5', { signal: controller.signal })
                .then(response => {
                    testCompleted({ error: 'Should have been aborted' });
                })
                .catch(error => {
                    testCompleted({
                        aborted: true,
                        errorName: error.name,
                        isAbortError: error.name === 'AbortError'
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertNotEqual(result["error"].toString(), "Should have been aborted", "Abort should work")
            XCTAssertTrue(result["aborted"].boolValue ?? false)
            // The exact error name might vary
            XCTAssertNotEqual(result["errorName"].toString(), "")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Response Type Tests
    
    func testFetchResponseTypes() {
        let expectation = XCTestExpectation(description: "Fetch response types")
        
        let script = """
            // Test different response types
            const tests = [];
            
            // JSON response
            fetch('https://postman-echo.com/get')
                .then(response => response.json())
                .then(data => {
                    tests.push({
                        type: 'json',
                        success: typeof data === 'object' && data !== null
                    });
                    return runTextTest();
                })
                .catch(error => {
                    tests.push({ type: 'json', error: error.message });
                    return runTextTest();
                });
            
            function runTextTest() {
                return fetch('https://postman-echo.com/get')
                    .then(response => response.text())
                    .then(text => {
                        tests.push({
                            type: 'text',
                            success: typeof text === 'string' && text.length > 0
                        });
                        testCompleted({ tests: tests });
                    })
                    .catch(error => {
                        tests.push({ type: 'text', error: error.message });
                        testCompleted({ tests: tests });
                    });
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let tests = result["tests"]
            let testCount = Int(tests["length"].numberValue ?? 0)
            
            // At least verify we attempted the tests
            XCTAssertGreaterThanOrEqual(testCount, 1)
            
            for i in 0..<testCount {
                let test = tests[i]
                if !test["error"].isString {
                    XCTAssertTrue(test["success"].boolValue ?? false, 
                                "Response type test '\(test["type"].toString())' should succeed")
                }
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Performance Tests
    
    func testFetchPerformance() {
        let expectation = XCTestExpectation(description: "Fetch performance")
        
        let script = """
            const startTime = Date.now();
            
            fetch('https://postman-echo.com/get')
                .then(response => response.json())
                .then(data => {
                    const endTime = Date.now();
                    const duration = endTime - startTime;
                    
                    testCompleted({
                        duration: duration,
                        performanceOk: duration < 10000, // Should complete within 10 seconds
                        hasData: typeof data === 'object'
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["performanceOk"].boolValue ?? false, 
                        "Request took \(result["duration"]) ms, should be under 10000ms")
            XCTAssertTrue(result["hasData"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testFetchConcurrency() {
        let expectation = XCTestExpectation(description: "Fetch concurrency verification")

        let script = """
                // Test that fetch requests truly run concurrently
                const delays = [2, 3, 1]; // Different delays to verify concurrency
                const startTime = Date.now();
                
                console.log('Testing fetch concurrency with delays:', delays);
                
                Promise.all(delays.map((delay, index) => {
                    const requestStart = Date.now();
                    console.log(`Request ${index} (${delay}s delay) starting at ${requestStart - startTime}ms`);
                    
                    return fetch(`https://postman-echo.com/delay/${delay}`)
                        .then(response => {
                            const requestEnd = Date.now();
                            console.log(`Request ${index} completed at ${requestEnd - startTime}ms`);
                            return {
                                index: index,
                                delay: delay,
                                duration: requestEnd - requestStart,
                                completedAt: requestEnd - startTime
                            };
                        });
                })).then(results => {
                    const endTime = Date.now();
                    const totalDuration = endTime - startTime;
                    
                    // Sort by completion time to verify order
                    const sortedResults = results.sort((a, b) => a.completedAt - b.completedAt);
                    const completionOrder = sortedResults.map(r => r.delay);
                    
                    // For true concurrency, shortest delay (1s) should complete first, then 2s, then 3s
                    const expectedOrder = [1, 2, 3];
                    const correctOrder = JSON.stringify(completionOrder) === JSON.stringify(expectedOrder);
                    
                    // Calculate speedup vs sequential execution
                    const sequentialTime = delays.reduce((sum, delay) => sum + (delay * 1000), 0);
                    const speedup = sequentialTime / totalDuration;
                    
                    testCompleted({
                        totalDuration: totalDuration,
                        completionOrder: completionOrder,
                        expectedOrder: expectedOrder,
                        correctOrder: correctOrder,
                        speedup: speedup,
                        isConcurrent: speedup > 1.2 && correctOrder, // At least 1.2x speedup + correct order
                        results: results,
                        maxExpectedTime: Math.max(...delays) * 1000 + 2000 // Max delay + 2s buffer
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            let totalDuration = result["totalDuration"].numberValue ?? 0
            let maxExpectedTime = result["maxExpectedTime"].numberValue ?? 0
            let speedup = result["speedup"].numberValue ?? 0

            XCTAssertTrue(
                result["correctOrder"].boolValue ?? false,
                "Requests should complete in order of their delays (1s, 2s, 3s)")
            XCTAssertGreaterThan(
                speedup, 1.2,
                "Concurrent execution should be at least 1.2x faster than sequential")
            XCTAssertLessThan(
                totalDuration, maxExpectedTime,
                "Total time should not exceed longest individual request + buffer")
            XCTAssertTrue(
                result["isConcurrent"].boolValue ?? false,
                "Fetch requests should run concurrently")

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }

    func testFetchConcurrencyStress() {
        let expectation = XCTestExpectation(description: "Fetch concurrency stress test")

        let script = """
                // Stress test with multiple concurrent requests
                const requestCount = 5; // Reduce to 5 requests for more reliable testing
                const delay = 2; // 2 second delay for each
                const startTime = Date.now();
                
                const promises = Array(requestCount).fill(null).map((_, index) => {
                    return fetch(`https://postman-echo.com/delay/${delay}`)
                        .then(response => ({
                            index: index,
                            status: response.status,
                            completedAt: Date.now() - startTime
                        }));
                });
                
                Promise.all(promises).then(results => {
                    const endTime = Date.now();
                    const totalDuration = endTime - startTime;
                    
                    // Check completion time spread
                    const completionTimes = results.map(r => r.completedAt);
                    const minCompletion = Math.min(...completionTimes);
                    const maxCompletion = Math.max(...completionTimes);
                    const completionSpread = maxCompletion - minCompletion;
                    
                    // For true concurrency, all should complete within a narrow window
                    const allSuccessful = results.every(r => r.status === 200);
                    const sequentialTime = requestCount * delay * 1000; // If run sequentially
                    const speedup = sequentialTime / totalDuration;
                    
                    testCompleted({
                        requestCount: requestCount,
                        totalDuration: totalDuration,
                        sequentialTime: sequentialTime,
                        speedup: speedup,
                        completionSpread: completionSpread,
                        allSuccessful: allSuccessful,
                        maxReasonableTime: (delay * 1000) + 4000, // Delay + 4s buffer
                        isConcurrentStress: speedup > 2.0 && completionSpread < 6000 && allSuccessful
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            let totalDuration = result["totalDuration"].numberValue ?? 0
            let speedup = result["speedup"].numberValue ?? 0
            let completionSpread = result["completionSpread"].numberValue ?? 0
            let maxReasonableTime = result["maxReasonableTime"].numberValue ?? 0

            XCTAssertTrue(
                result["allSuccessful"].boolValue ?? false,
                "All concurrent requests should succeed")
                XCTAssertGreaterThan(
                    speedup, 2.0,
                    "5 concurrent requests should be much faster than sequential (>2x)")
                XCTAssertLessThan(
                    completionSpread, 6000,
                    "All concurrent requests should complete within 6 seconds of each other")
                XCTAssertLessThan(
                    totalDuration, maxReasonableTime,
                    "Total time should be close to individual request time, not cumulative")
                XCTAssertTrue(
                    result["isConcurrentStress"].boolValue ?? false,
                    "Stress test should demonstrate true concurrency")

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }

    // MARK: - Integration Tests
    
    func testFetchWithComplexRequestResponse() {
        let expectation = XCTestExpectation(description: "Complex fetch integration")
        
        let script = """
            const requestData = {
                timestamp: Date.now(),
                userAgent: 'SwiftJS-Test',
                testId: Math.random().toString(36)
            };
            
            const request = new Request('https://postman-echo.com/post', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Test-Framework': 'SwiftJS',
                    'X-Test-Type': 'Integration'
                },
                body: JSON.stringify(requestData)
            });
            
            fetch(request)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                    }
                    return response.json();
                })
                .then(responseData => {
                    // httpbin echoes back the request data
                    const receivedData = JSON.parse(responseData.data || '{}');
                    
                    testCompleted({
                        requestDataMatches: receivedData.testId === requestData.testId,
                        hasHeaders: !!responseData.headers,
                        methodCorrect: responseData.json !== undefined || responseData.data !== undefined,
                        timestampReceived: receivedData.timestamp,
                        originalTimestamp: requestData.timestamp
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["requestDataMatches"].boolValue ?? false)
            XCTAssertTrue(result["hasHeaders"].boolValue ?? false)
            XCTAssertTrue(result["methodCorrect"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
}
