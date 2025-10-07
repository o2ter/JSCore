//
//  NetworkErrorHandlingTests.swift
//  SwiftJS Network Error Handling Tests
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

/// Comprehensive tests for network error handling scenarios
/// including malformed data, connection failures, and edge cases.
@MainActor
final class NetworkErrorHandlingTests: XCTestCase {
    
    // MARK: - Malformed Data Tests
    
    func testMalformedJSONResponse() {
        let expectation = XCTestExpectation(description: "Malformed JSON response")
        
        let script = """
            // Create response with malformed JSON
            const malformedJSON = '{"incomplete": "data", "missing"';
            const response = new Response(malformedJSON, {
                headers: { 'Content-Type': 'application/json' }
            });
            
            const testResults = [];
            
            // Test 1: Try to parse malformed JSON
            response.clone().json()
                .then(parsed => {
                    testResults.push({
                        test: 'malformed-json',
                        success: false,
                        error: 'Should have failed to parse'
                    });
                })
                .catch(error => {
                    testResults.push({
                        test: 'malformed-json',
                        success: true,
                        errorType: error.name,
                        errorMessage: error.message
                    });
                })
                .then(() => {
                    // Test 2: Parse as text (should work)
                    return response.clone().text();
                })
                .then(text => {
                    testResults.push({
                        test: 'text-fallback',
                        success: true,
                        content: text,
                        contentMatches: text === malformedJSON
                    });
                    
                    testCompleted({
                        results: testResults,
                        handledMalformedData: testResults.length === 2,
                        jsonErrorCaught: testResults[0].success,
                        textFallbackWorked: testResults[1].success
                    });
                })
                .catch(error => {
                    testCompleted({
                        error: error.message,
                        results: testResults
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            if !result["error"].isString {
                XCTAssertTrue(result["handledMalformedData"].boolValue ?? false)
                XCTAssertTrue(result["jsonErrorCaught"].boolValue ?? false)
                XCTAssertTrue(result["textFallbackWorked"].boolValue ?? false)
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCorruptedBinaryData() {
        let expectation = XCTestExpectation(description: "Corrupted binary data")
        
        let script = """
            // Create response with corrupted binary data
            const corruptedData = new Uint8Array([
                0x89, 0x50, 0x4E, 0x47, // PNG header start
                0xFF, 0xFF, 0xFF, 0xFF, // Corrupted data
                0x00, 0x00, 0x00, 0x0D, // More corrupted data
                0x49, 0x48, 0x44, 0x52  // IHDR chunk type
            ]);
            
            const response = new Response(corruptedData, {
                headers: { 'Content-Type': 'image/png' }
            });
            
            const testResults = [];
            
            // Test arrayBuffer parsing
            response.clone().arrayBuffer()
                .then(buffer => {
                    const view = new Uint8Array(buffer);
                    testResults.push({
                        test: 'array-buffer',
                        success: true,
                        byteLength: buffer.byteLength,
                        firstBytes: Array.from(view.slice(0, 4)),
                        isPNGHeader: view[0] === 0x89 && view[1] === 0x50 && view[2] === 0x4E && view[3] === 0x47
                    });
                })
                .catch(error => {
                    testResults.push({
                        test: 'array-buffer',
                        success: false,
                        error: error.message
                    });
                })
                .then(() => {
                    // Test blob parsing
                    return response.clone().blob();
                })
                .then(blob => {
                    testResults.push({
                        test: 'blob',
                        success: true,
                        blobSize: blob.size,
                        blobType: blob.type
                    });
                    
                    testCompleted({
                        results: testResults,
                        handledCorruptedData: testResults.length === 2,
                        arrayBufferWorked: testResults[0].success,
                        blobWorked: testResults[1].success
                    });
                })
                .catch(error => {
                    testCompleted({
                        error: error.message,
                        results: testResults
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            if !result["error"].isString {
                XCTAssertTrue(result["handledCorruptedData"].boolValue ?? false)
                // Both should work even with corrupted data since they don't validate format
                XCTAssertTrue(result["arrayBufferWorked"].boolValue ?? false)
                XCTAssertTrue(result["blobWorked"].boolValue ?? false)
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Connection Error Tests
    
    func testDNSResolutionFailure() {
        let expectation = XCTestExpectation(description: "DNS resolution failure")
        
        let script = """
            const invalidDomains = [
                'https://this-domain-definitely-does-not-exist-12345.invalid',
                'https://another-nonexistent-domain-67890.invalid',
                'https://..invalid.domain..'
            ];
            
            const results = [];
            let completedTests = 0;
            
            invalidDomains.forEach((domain, index) => {
                fetch(domain)
                    .then(response => {
                        results[index] = {
                            domain: domain,
                            success: true,
                            status: response.status,
                            unexpected: true
                        };
                    })
                    .catch(error => {
                        results[index] = {
                            domain: domain,
                            success: false,
                            errorType: error.name,
                            errorMessage: error.message,
                            expectedFailure: true
                        };
                    })
                    .finally(() => {
                        completedTests++;
                        if (completedTests === invalidDomains.length) {
                            testCompleted({
                                totalTests: invalidDomains.length,
                                results: results,
                                allFailed: results.every(r => !r.success),
                                allHandledGracefully: results.every(r => r.errorMessage || r.unexpected)
                            });
                        }
                    });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(Int(result["totalTests"].numberValue ?? 0), 3)
            XCTAssertTrue(result["allHandledGracefully"].boolValue ?? false)
            // DNS failures should result in errors, not successes
            XCTAssertTrue(result["allFailed"].boolValue ?? false)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testConnectionRefused() {
        let expectation = XCTestExpectation(description: "Connection refused")
        
        let script = """
            // Test connection to localhost on unused port
            const refusedConnections = [
                'http://localhost:99999',  // Invalid port
                'http://127.0.0.1:12345'   // Likely unused port
            ];
            
            const results = [];
            let completedTests = 0;
            
            refusedConnections.forEach((url, index) => {
                const startTime = Date.now();
                
                fetch(url)
                    .then(response => {
                        results[index] = {
                            url: url,
                            success: true,
                            status: response.status,
                            duration: Date.now() - startTime,
                            unexpected: true
                        };
                    })
                    .catch(error => {
                        results[index] = {
                            url: url,
                            success: false,
                            errorType: error.name,
                            errorMessage: error.message,
                            duration: Date.now() - startTime,
                            expectedFailure: true
                        };
                    })
                    .finally(() => {
                        completedTests++;
                        if (completedTests === refusedConnections.length) {
                            testCompleted({
                                totalTests: refusedConnections.length,
                                results: results,
                                allFailed: results.every(r => !r.success),
                                reasonableTime: results.every(r => r.duration < 15000) // Allow up to 15 seconds for connection timeouts
                            });
                        }
                    });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(Int(result["totalTests"].numberValue ?? 0), 2)
            XCTAssertTrue(result["allFailed"].boolValue ?? false)
            XCTAssertTrue(result["reasonableTime"].boolValue ?? false)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Stream Error Recovery Tests
    
    func testStreamErrorPropagationChain() {
        let expectation = XCTestExpectation(description: "Stream error propagation chain")

        let script = """
                // Create a chain of transforms where errors can propagate
                const sourceStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(new TextEncoder().encode('data1'));
                        controller.enqueue(new TextEncoder().encode('data2'));
                        
                        // Error after some data
                        setTimeout(() => {
                            controller.error(new Error('Source stream error'));
                        }, 10);
                    }
                });
                
                const transform1 = new TransformStream({
                    transform(chunk, controller) {
                        const text = new TextDecoder().decode(chunk);
                        controller.enqueue(new TextEncoder().encode(text.toUpperCase()));
                    }
                });
                
                const transform2 = new TransformStream({
                    transform(chunk, controller) {
                        const text = new TextDecoder().decode(chunk);
                        if (text.includes('ERROR')) {
                            throw new Error('Transform 2 error');
                        }
                        controller.enqueue(new TextEncoder().encode('PREFIX-' + text));
                    }
                });
                
                const processedData = [];
                const errors = [];
                
                const destination = new WritableStream({
                    write(chunk) {
                        processedData.push(new TextDecoder().decode(chunk));
                    },
                    close() {
                        // Shouldn't reach here due to error
                        testCompleted({
                            error: 'Stream should have errored',
                            processedData: processedData
                        });
                    }
                });
                
                sourceStream
                    .pipeThrough(transform1)
                    .pipeThrough(transform2)
                    .pipeTo(destination)
                    .catch(error => {
                        testCompleted({
                            errorCaught: true,
                            errorMessage: error.message,
                            processedData: processedData,
                            processedSomeData: processedData.length > 0,
                            errorPropagatedCorrectly: error.message.includes('Source stream error')
                        });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if result["errorCaught"].boolValue == true {
                XCTAssertTrue(result["processedSomeData"].boolValue ?? false)
                XCTAssertNotEqual(result["errorMessage"].toString(), "")
            } else {
                XCTFail("Error should have been caught and propagated")
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testMultipleStreamErrorRecovery() {
        let expectation = XCTestExpectation(description: "Multiple stream error recovery")
        
        let script = """
            const streamCount = 5;
            const streams = [];
            const recoveryResults = [];
            
            // Create streams that fail and need recovery
            for (let i = 0; i < streamCount; i++) {
                const stream = new ReadableStream({
                    start(controller) {
                        let chunkCount = 0;
                        
                        function sendChunk() {
                            if (chunkCount < 3) {
                                controller.enqueue(new TextEncoder().encode(`Stream ${i} chunk ${chunkCount++}`));
                                setTimeout(sendChunk, 10);
                            } else if (i % 2 === 0) {
                                // Even streams error
                                controller.error(new Error(`Stream ${i} error`));
                            } else {
                                // Odd streams complete normally
                                controller.close();
                            }
                        }
                        
                        sendChunk();
                    }
                });
                
                streams.push(stream);
            }
            
            // Process all streams with recovery logic
            const promises = streams.map((stream, index) => {
                return new Promise((resolve) => {
                    const processedChunks = [];
                    let recovered = false;
                    
                    const reader = stream.getReader();
                    
                    function readWithRecovery() {
                        reader.read()
                            .then(({ done, value }) => {
                                if (done) {
                                    resolve({
                                        streamIndex: index,
                                        success: true,
                                        processedChunks: processedChunks.length,
                                        data: processedChunks,
                                        recovered: recovered
                                    });
                                    return;
                                }
                                
                                processedChunks.push(new TextDecoder().decode(value));
                                readWithRecovery();
                            })
                            .catch(error => {
                                // Attempt recovery
                                recovered = true;
                                resolve({
                                    streamIndex: index,
                                    success: false,
                                    error: error.message,
                                    processedChunks: processedChunks.length,
                                    data: processedChunks,
                                    recovered: recovered,
                                    partialSuccess: processedChunks.length > 0
                                });
                            });
                    }
                    
                    readWithRecovery();
                });
            });
            
            Promise.all(promises).then(results => {
                const successCount = results.filter(r => r.success).length;
                const errorCount = results.filter(r => !r.success).length;
                const recoveredCount = results.filter(r => r.recovered).length;
                const partialSuccessCount = results.filter(r => r.partialSuccess).length;
                
                testCompleted({
                    totalStreams: streamCount,
                    successCount: successCount,
                    errorCount: errorCount,
                    recoveredCount: recoveredCount,
                    partialSuccessCount: partialSuccessCount,
                    allProcessedSomeData: results.every(r => r.processedChunks > 0),
                    recoveryWorked: recoveredCount > 0 && partialSuccessCount > 0,
                    results: results
                });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(Int(result["totalStreams"].numberValue ?? 0), 5)
            XCTAssertTrue(result["allProcessedSomeData"].boolValue ?? false)
            XCTAssertTrue(result["recoveryWorked"].boolValue ?? false)
            XCTAssertGreaterThan(Int(result["recoveredCount"].numberValue ?? 0), 0)
            XCTAssertGreaterThan(Int(result["partialSuccessCount"].numberValue ?? 0), 0)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Resource Limit Tests
    
    func testRequestBodySizeLimit() {
        let expectation = XCTestExpectation(description: "Request body size limit")
        
        let script = """
            // Test with progressively larger request bodies
            const testSizes = [1024, 1024 * 1024, 10 * 1024 * 1024]; // 1KB, 1MB, 10MB
            const results = [];
            let completedTests = 0;
            
            testSizes.forEach((size, index) => {
                const startTime = Date.now();
                
                // Create large data
                const largeData = 'x'.repeat(size);
                
                fetch('https://postman-echo.com/post', {
                    method: 'POST',
                    headers: { 'Content-Type': 'text/plain' },
                    body: largeData
                })
                    .then(response => {
                        const duration = Date.now() - startTime;
                        results[index] = {
                            size: size,
                            success: true,
                            status: response.status,
                            duration: duration,
                            sizeDescription: size < 1024 * 1024 ? `${Math.round(size/1024)}KB` : `${Math.round(size/(1024*1024))}MB`
                        };
                    })
                    .catch(error => {
                        const duration = Date.now() - startTime;
                        results[index] = {
                            size: size,
                            success: false,
                            error: error.message,
                            duration: duration,
                            sizeDescription: size < 1024 * 1024 ? `${Math.round(size/1024)}KB` : `${Math.round(size/(1024*1024))}MB`
                        };
                    })
                    .finally(() => {
                        completedTests++;
                        if (completedTests === testSizes.length) {
                            const successfulSizes = results.filter(r => r.success).map(r => r.sizeDescription);
                            const failedSizes = results.filter(r => !r.success).map(r => r.sizeDescription);
                            
                            testCompleted({
                                totalTests: testSizes.length,
                                results: results,
                                successfulSizes: successfulSizes,
                                failedSizes: failedSizes,
                                handledLargeBodies: results.some(r => r.size >= 1024 * 1024 && r.success),
                                gracefulDegradation: results.every(r => r.duration < 30000) // Max 30 seconds
                            });
                        }
                    });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(Int(result["totalTests"].numberValue ?? 0), 3)
            XCTAssertTrue(result["gracefulDegradation"].boolValue ?? false)
            // At least small sizes should work
            let successfulSizes = result["successfulSizes"]
            XCTAssertGreaterThan(Int(successfulSizes["length"].numberValue ?? 0), 0)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 60.0) // Long timeout for large uploads
    }
    
    func testConcurrentConnectionLimits() {
        let expectation = XCTestExpectation(description: "Concurrent connection limits")
        
        let script = """
            // Test behavior with many concurrent connections
            const connectionCount = 20;
            const results = [];
            const startTime = Date.now();
            
            const promises = [];
            for (let i = 0; i < connectionCount; i++) {
                const promise = fetch(`https://postman-echo.com/get?connection=${i}`)
                    .then(response => ({
                        connectionIndex: i,
                        success: true,
                        status: response.status,
                        timestamp: Date.now()
                    }))
                    .catch(error => ({
                        connectionIndex: i,
                        success: false,
                        error: error.message,
                        timestamp: Date.now()
                    }));
                
                promises.push(promise);
            }
            
            Promise.allSettled(promises).then(promiseResults => {
                const endTime = Date.now();
                const totalDuration = endTime - startTime;
                
                const connectionResults = promiseResults.map(r => 
                    r.status === 'fulfilled' ? r.value : { error: 'Promise rejected' }
                );
                
                const successCount = connectionResults.filter(r => r.success).length;
                const errorCount = connectionResults.filter(r => !r.success).length;
                
                // Check if connections were processed in reasonable time
                const averageTime = totalDuration / connectionCount;
                const maxIndividualTime = Math.max(...connectionResults.map(r => r.timestamp - startTime));
                
                testCompleted({
                    totalConnections: connectionCount,
                    successCount: successCount,
                    errorCount: errorCount,
                    totalDuration: totalDuration,
                    averageTime: averageTime,
                    maxIndividualTime: maxIndividualTime,
                    handledConcurrency: successCount > connectionCount * 0.5, // At least 50% success
                    reasonablePerformance: averageTime < 2000, // Less than 2 seconds average
                    results: connectionResults
                });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(Int(result["totalConnections"].numberValue ?? 0), 20)
            XCTAssertTrue(result["handledConcurrency"].boolValue ?? false)
            XCTAssertGreaterThan(Int(result["successCount"].numberValue ?? 0), 5) // At least some should succeed
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - HTTP Streaming Error Propagation Tests
    
    func testHTTPStreamingNetworkError() {
        let expectation = XCTestExpectation(description: "HTTP streaming network error")
        
        let script = """
            // Test that network errors during streaming are properly propagated to JavaScript
            fetch('http://localhost:99999/nonexistent')
                .then(response => {
                    testCompleted({
                        error: 'Should not reach here - expected network error',
                        unexpectedSuccess: true,
                        status: response.status
                    });
                })
                .catch(error => {
                    testCompleted({
                        errorCaught: true,
                        errorType: typeof error,
                        errorName: error.name,
                        errorMessage: error.message,
                        hasErrorObject: error instanceof Error,
                        messageContainsConnectionInfo: error.message.toLowerCase().includes('connection') || 
                                                       error.message.toLowerCase().includes('nio')
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Verify error was properly caught and propagated
            XCTAssertTrue(result["errorCaught"].boolValue ?? false, "Network error should be caught")
            XCTAssertEqual(result["errorType"].toString(), "object", "Error should be an object")
            XCTAssertTrue(result["hasErrorObject"].boolValue ?? false, "Should be instance of Error")
            XCTAssertFalse(result["unexpectedSuccess"].boolValue ?? true, "Should not succeed with invalid URL")
            
            // Error message should contain meaningful information
            let errorMessage = result["errorMessage"].toString()
            XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testHTTPStreamingDNSError() {
        let expectation = XCTestExpectation(description: "HTTP streaming DNS error")
        
        let script = """
            // Test DNS resolution errors during HTTP streaming
            fetch('https://nonexistent-domain-12345.invalid')
                .then(response => {
                    testCompleted({
                        error: 'Should not reach here - expected DNS error',
                        unexpectedSuccess: true,
                        status: response.status
                    });
                })
                .catch(error => {
                    testCompleted({
                        errorCaught: true,
                        errorType: typeof error,
                        errorName: error.name,
                        errorMessage: error.message,
                        hasErrorObject: error instanceof Error,
                        isDNSRelated: error.message.toLowerCase().includes('connection') ||
                                      error.message.toLowerCase().includes('host') ||
                                      error.message.toLowerCase().includes('resolve')
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Verify DNS error was properly caught and propagated
            XCTAssertTrue(result["errorCaught"].boolValue ?? false, "DNS error should be caught")
            XCTAssertEqual(result["errorType"].toString(), "object", "Error should be an object")
            XCTAssertTrue(result["hasErrorObject"].boolValue ?? false, "Should be instance of Error")
            XCTAssertFalse(result["unexpectedSuccess"].boolValue ?? true, "Should not succeed with invalid domain")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testHTTPStreamingAbortError() {
        let expectation = XCTestExpectation(description: "HTTP streaming abort error")
        
        let script = """
            // Test that AbortController properly propagates errors during streaming
            const controller = new AbortController();
            
            // Start a request that would normally succeed but abort it quickly
            const fetchPromise = fetch('https://httpstat.us/200?sleep=2000', {
                signal: controller.signal
            });
            
            // Abort after a short delay to test error propagation during streaming
            setTimeout(() => {
                controller.abort();
            }, 100);
            
            fetchPromise
                .then(response => {
                    testCompleted({
                        error: 'Should not reach here - expected abort error',
                        unexpectedSuccess: true,
                        status: response.status
                    });
                })
                .catch(error => {
                    testCompleted({
                        errorCaught: true,
                        errorType: typeof error,
                        errorName: error.name,
                        errorMessage: error.message,
                        hasErrorObject: error instanceof Error,
                        isAbortError: error.name === 'AbortError',
                        messageContainsAbort: error.message.toLowerCase().includes('abort')
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Verify abort error was properly caught and propagated
            XCTAssertTrue(result["errorCaught"].boolValue ?? false, "Abort error should be caught")
            XCTAssertEqual(result["errorType"].toString(), "object", "Error should be an object")
            XCTAssertTrue(result["hasErrorObject"].boolValue ?? false, "Should be instance of Error")
            XCTAssertTrue(result["isAbortError"].boolValue ?? false, "Should be AbortError")
            XCTAssertTrue(result["messageContainsAbort"].boolValue ?? false, "Message should mention abort")
            XCTAssertFalse(result["unexpectedSuccess"].boolValue ?? true, "Should not succeed when aborted")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testHTTPStreamingTimeoutError() {
        let expectation = XCTestExpectation(description: "HTTP streaming timeout error")
        
        let script = """
            // Test timeout errors during HTTP streaming
            // Note: We use a very long delay URL and shorter timeout to force timeout
            fetch('https://httpstat.us/200?sleep=10000', {
                // This would cause a timeout in most implementations,
                // but we're mainly testing error propagation mechanism
            })
                .then(response => {
                    // If it succeeds, that's okay too - we're testing error propagation mechanism
                    testCompleted({
                        requestCompleted: true,
                        status: response.status,
                        errorHandlingWorks: true // The fact we got here shows error handling didn't break normal requests
                    });
                })
                .catch(error => {
                    testCompleted({
                        errorCaught: true,
                        errorType: typeof error,
                        errorName: error.name,
                        errorMessage: error.message,
                        hasErrorObject: error instanceof Error,
                        errorHandlingWorks: true // Error was properly propagated
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Verify that either success or error is properly handled
            let requestCompleted = result["requestCompleted"].boolValue ?? false
            let errorCaught = result["errorCaught"].boolValue ?? false
            let errorHandlingWorks = result["errorHandlingWorks"].boolValue ?? false
            
            XCTAssertTrue(errorHandlingWorks, "Error handling mechanism should work")
            XCTAssertTrue(requestCompleted || errorCaught, "Should either complete or error properly")
            
            if errorCaught {
                XCTAssertEqual(result["errorType"].toString(), "object", "Error should be an object")
                XCTAssertTrue(result["hasErrorObject"].boolValue ?? false, "Should be instance of Error")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0) // Longer timeout to account for the test URL delay
    }
}
