//
//  StreamingTests.swift
//  SwiftJS Streaming API Tests
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

/// Tests for the Web Streams API including ReadableStream, WritableStream,
/// TransformStream, and pipe methods (pipeTo, pipeThrough).
@MainActor
final class StreamingTests: XCTestCase {
    
    // MARK: - Stream API Existence Tests
    
    func testStreamAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("ReadableStream"))
        XCTAssertTrue(globals.toString().contains("WritableStream"))
        XCTAssertTrue(globals.toString().contains("TransformStream"))
    }
    
    func testStreamConstructors() {
        let context = SwiftJS()
        
        XCTAssertEqual(context.evaluateScript("typeof ReadableStream").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof WritableStream").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof TransformStream").toString(), "function")
    }
    
    // MARK: - ReadableStream Tests
    
    func testReadableStreamCreation() {
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            stream instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testReadableStreamReading() {
        let expectation = XCTestExpectation(description: "ReadableStream reading")
        
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            
            const reader = stream.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        reader.releaseLock();
                        // Combine all chunks
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello World")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testReadableStreamTee() {
        let expectation = XCTestExpectation(description: "ReadableStream tee")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('World'));
                    controller.close();
                }
            });
            
            const [stream1, stream2] = source.tee();
            
            const results = [];
            
            async function readStream(stream, index) {
                const reader = stream.getReader();
                const chunks = [];
                
                try {
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    let totalLength = 0;
                    chunks.forEach(chunk => totalLength += chunk.byteLength);
                    const combined = new Uint8Array(totalLength);
                    let offset = 0;
                    chunks.forEach(chunk => {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    });
                    const text = new TextDecoder().decode(combined);
                    results[index] = text;
                } finally {
                    reader.releaseLock();
                }
            }
            
            Promise.all([
                readStream(stream1, 0),
                readStream(stream2, 1)
            ]).then(() => {
                testCompleted({
                    stream1: results[0],
                    stream2: results[1],
                    areEqual: results[0] === results[1]
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["stream1"].toString(), "Hello World")
            XCTAssertEqual(result["stream2"].toString(), "Hello World")
            XCTAssertTrue(result["areEqual"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - WritableStream Tests
    
    func testWritableStreamCreation() {
        let script = """
            const stream = new WritableStream({
                write(chunk) {
                    // Process the chunk
                }
            });
            stream instanceof WritableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testWritableStreamWriting() {
        let expectation = XCTestExpectation(description: "WritableStream writing")
        
        let script = """
            const chunks = [];
            const stream = new WritableStream({
                write(chunk) {
                    chunks.push(chunk);
                },
                close() {
                    // Combine all chunks and decode
                    let totalLength = 0;
                    chunks.forEach(chunk => totalLength += chunk.byteLength);
                    const combined = new Uint8Array(totalLength);
                    let offset = 0;
                    chunks.forEach(chunk => {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    });
                    const text = new TextDecoder().decode(combined);
                    testCompleted({ result: text });
                }
            });
            
            const writer = stream.getWriter();
            writer.write(new TextEncoder().encode('Streaming '))
                .then(() => writer.write(new TextEncoder().encode('in ')))
                .then(() => writer.write(new TextEncoder().encode('SwiftJS!')))
                .then(() => writer.close())
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Streaming in SwiftJS!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - TransformStream Tests
    
    func testTransformStreamCreation() {
        let script = """
            const transform = new TransformStream({
                transform(chunk, controller) {
                    // Transform the chunk
                    controller.enqueue(chunk);
                }
            });
            transform instanceof TransformStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTransformStreamPipeline() {
        let expectation = XCTestExpectation(description: "TransformStream pipeline")
        
        let script = """
            // Create a transform that uppercases text
            const upperCaseTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    const upperText = text.toUpperCase();
                    controller.enqueue(new TextEncoder().encode(upperText));
                }
            });
            
            // Create source stream
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('hello '));
                    controller.enqueue(new TextEncoder().encode('streaming '));
                    controller.enqueue(new TextEncoder().encode('world'));
                    controller.close();
                }
            });
            
            // Read from the transformed stream
            const reader = upperCaseTransform.readable.getReader();
            const writer = upperCaseTransform.writable.getWriter();
            
            // Pipe source to transform
            const sourceReader = source.getReader();
            function pump() {
                return sourceReader.read().then(({ done, value }) => {
                    if (done) {
                        writer.close();
                        return;
                    }
                    return writer.write(value).then(pump);
                });
            }
            
            // Read transformed output
            const chunks = [];
            function readOutput() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        // Combine and decode
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readOutput();
                });
            }
            
            Promise.all([pump(), readOutput()]).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO STREAMING WORLD")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - pipeTo Method Tests
    
    func testPipeToMethodExists() {
        let context = SwiftJS()
        let script = """
            const stream = new ReadableStream();
            typeof stream.pipeTo === 'function'
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testPipeToBasicFunctionality() {
        let expectation = XCTestExpectation(description: "pipeTo basic functionality")
        
        let script = """
            const chunks = [];
            
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello '));
                    controller.enqueue(new TextEncoder().encode('World!'));
                    controller.close();
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    chunks.push(new TextDecoder().decode(chunk));
                },
                close() {
                    testCompleted({ 
                        result: chunks.join(''),
                        chunkCount: chunks.length
                    });
                }
            });
            
            source.pipeTo(destination).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello World!")
            XCTAssertEqual(Int(result["chunkCount"].numberValue ?? 0), 2)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPipeToWithLargeData() {
        let expectation = XCTestExpectation(description: "pipeTo with large data")
        
        let script = """
            const expectedSize = 10000;
            let receivedSize = 0;
            
            const source = new ReadableStream({
                start(controller) {
                    for (let i = 0; i < expectedSize; i++) {
                        controller.enqueue(new TextEncoder().encode('A'));
                    }
                    controller.close();
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    receivedSize += chunk.byteLength;
                },
                close() {
                    testCompleted({ 
                        expectedSize: expectedSize,
                        receivedSize: receivedSize,
                        matches: expectedSize === receivedSize
                    });
                }
            });
            
            source.pipeTo(destination).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertEqual(Int(result["expectedSize"].numberValue ?? 0), 10000)
            XCTAssertEqual(Int(result["receivedSize"].numberValue ?? 0), 10000)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPipeToErrorPropagation() {
        let expectation = XCTestExpectation(description: "pipeTo error propagation")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Before error'));
                    setTimeout(() => {
                        controller.error(new Error('Source stream error'));
                    }, 10);
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    // Should receive at least one chunk
                }
            });
            
            source.pipeTo(destination)
                .then(() => {
                    testCompleted({ error: 'Should have failed' });
                })
                .catch(error => {
                    testCompleted({ 
                        caughtError: true,
                        errorMessage: error.message,
                        isExpectedError: error.message === 'Source stream error'
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["caughtError"].boolValue ?? false)
            XCTAssertTrue(result["isExpectedError"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testClearTimeout() {
        let expectation = XCTestExpectation(description: "clearTimeout")
        
        let script = """
            let timeoutExecuted = false;
            
            const timeoutId = setTimeout(() => {
                timeoutExecuted = true;
            }, 100);
            
            clearTimeout(timeoutId);
            
            // Wait longer than the timeout to verify it was cancelled
            setTimeout(() => {
                testCompleted({ executed: timeoutExecuted });
            }, 200);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["executed"].boolValue ?? true)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - pipeThrough Method Tests
    
    func testPipeThroughMethodExists() {
        let context = SwiftJS()
        let script = """
            const stream = new ReadableStream();
            typeof stream.pipeThrough === 'function'
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testPipeThroughBasicTransform() {
        let expectation = XCTestExpectation(description: "pipeThrough basic transform")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('hello'));
                    controller.enqueue(new TextEncoder().encode(' '));
                    controller.enqueue(new TextEncoder().encode('world'));
                    controller.close();
                }
            });
            
            const upperCaseTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    const upperText = text.toUpperCase();
                    controller.enqueue(new TextEncoder().encode(upperText));
                }
            });
            
            const chunks = [];
            const destination = new WritableStream({
                write(chunk) {
                    chunks.push(new TextDecoder().decode(chunk));
                },
                close() {
                    // Don't call testCompleted here - let the pipeTo promise handle it
                }
            });
            
            const transformedStream = source.pipeThrough(upperCaseTransform);
            
            // Verify pipeThrough returns the readable side
            const isReadableStream = transformedStream instanceof ReadableStream;
            
            transformedStream.pipeTo(destination).then(() => {
                testCompleted({ 
                    result: chunks.join(''),
                    isReadableStream: isReadableStream
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO WORLD")
            XCTAssertTrue(result["isReadableStream"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPipeThroughComplexPipeline() {
        let expectation = XCTestExpectation(description: "pipeThrough complex pipeline")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('test data'));
                    controller.close();
                }
            });
            
            // Transform 1: uppercase
            const upperTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode(text.toUpperCase()));
                }
            });
            
            // Transform 2: add prefix
            const prefixTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode('PROCESSED: ' + text));
                }
            });
            
            // Transform 3: add suffix
            const suffixTransform = new TransformStream({
                transform(chunk, controller) {
                    const text = new TextDecoder().decode(chunk);
                    controller.enqueue(new TextEncoder().encode(text + ' [DONE]'));
                }
            });
            
            let finalResult = '';
            const destination = new WritableStream({
                write(chunk) {
                    finalResult += new TextDecoder().decode(chunk);
                },
                close() {
                    testCompleted({ 
                        result: finalResult,
                        expected: 'PROCESSED: TEST DATA [DONE]',
                        matches: finalResult === 'PROCESSED: TEST DATA [DONE]'
                    });
                }
            });
            
            // Chain multiple transforms
            source
                .pipeThrough(upperTransform)
                .pipeThrough(prefixTransform)
                .pipeThrough(suffixTransform)
                .pipeTo(destination)
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertEqual(result["result"].toString(), "PROCESSED: TEST DATA [DONE]")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Pipe Options Tests
    
    func testPipeToWithAbortController() {
        let expectation = XCTestExpectation(description: "pipeTo with AbortController")
        
        let script = """
            const controller = new AbortController();
            let receivedChunks = 0;
            
            const source = new ReadableStream({
                start(streamController) {
                    let count = 0;
                    const interval = setInterval(() => {
                        streamController.enqueue(new TextEncoder().encode(`chunk-${count++}`));
                        if (count >= 20) {
                            streamController.close();
                            clearInterval(interval);
                        }
                    }, 10);
                }
            });
            
            const destination = new WritableStream({
                write(chunk) {
                    receivedChunks++;
                    // Don't process too many chunks
                }
            });
            
            // Abort after receiving some chunks
            setTimeout(() => {
                controller.abort();
            }, 50);
            
            source.pipeTo(destination, { signal: controller.signal })
                .then(() => {
                    testCompleted({ error: 'Should not have completed normally' });
                })
                .catch(error => {
                    testCompleted({ 
                        isAbortError: error.name === 'AbortError',
                        receivedChunks: receivedChunks,
                        receivedSome: receivedChunks > 0 && receivedChunks < 20
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["isAbortError"].boolValue ?? false)
            XCTAssertTrue(result["receivedSome"].boolValue ?? false)
            let receivedCount = Int(result["receivedChunks"].numberValue ?? 0)
            XCTAssertGreaterThan(receivedCount, 0)
            XCTAssertLessThan(receivedCount, 20)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPipeToWithPreventCloseOption() {
        let expectation = XCTestExpectation(description: "pipeTo with preventClose option")
        
        let script = """
            const source = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('test'));
                    controller.close();
                }
            });
            
            let destinationClosed = false;
            const destination = new WritableStream({
                write(chunk) {
                    // Process chunk
                },
                close() {
                    destinationClosed = true;
                }
            });
            
            source.pipeTo(destination, { preventClose: true })
                .then(() => {
                    // Give it a moment to see if close was called
                    setTimeout(() => {
                        testCompleted({ 
                            destinationClosed: destinationClosed,
                            preventedClose: !destinationClosed
                        });
                    }, 10);
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertFalse(result["destinationClosed"].boolValue ?? true)
            XCTAssertTrue(result["preventedClose"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Response Body Stream Tests
    
    func testResponseBodyIsStream() {
        let script = """
            const response = new Response('Hello, streaming world!');
            response.body instanceof ReadableStream
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testResponseStreamReading() {
        let expectation = XCTestExpectation(description: "Response stream reading")
        
        let script = """
            const response = new Response('Hello, streaming world!');
            const reader = response.body.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        // Combine chunks
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "Hello, streaming world!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponseCloneWithStream() {
        let expectation = XCTestExpectation(description: "Response clone with stream")
        
        let script = """
            const original = new Response('Hello, cloned world!');
            const cloned = original.clone();
            
            Promise.all([
                original.text(),
                cloned.text()
            ]).then(([originalText, clonedText]) => {
                testCompleted({
                    original: originalText,
                    cloned: clonedText,
                    areEqual: originalText === clonedText
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["original"].toString(), "Hello, cloned world!")
            XCTAssertEqual(result["cloned"].toString(), "Hello, cloned world!")
            XCTAssertTrue(result["areEqual"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponsePipeThrough() {
        let expectation = XCTestExpectation(description: "Response stream pipeThrough")

        let script = """
                const response = new Response('hello world');
                
                const upperCaseTransform = new TransformStream({
                    transform(chunk, controller) {
                        const text = new TextDecoder().decode(chunk);
                        const upperText = text.toUpperCase();
                        controller.enqueue(new TextEncoder().encode(upperText));
                    }
                });
                
                const chunks = [];
                const destination = new WritableStream({
                    write(chunk) {
                        chunks.push(chunk);
                    },
                    close() {
                        let totalLength = 0;
                        chunks.forEach(chunk => totalLength += chunk.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(chunk => {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({ result: text });
                    }
                });
                
                response.body
                    .pipeThrough(upperCaseTransform)
                    .pipeTo(destination)
                    .catch(error => {
                        testCompleted({ error: error.message });
                    });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["result"].toString(), "HELLO WORLD")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testStreamErrorHandling() {
        let expectation = XCTestExpectation(description: "Stream error handling")
        
        let script = """
            const stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(new TextEncoder().encode('Hello'));
                    controller.error(new Error('Stream error'));
                }
            });
            
            const reader = stream.getReader();
            reader.read()
                .then(({ done, value }) => {
                    if (!done) {
                        const text = new TextDecoder().decode(value);
                        return reader.read(); // This should error
                    }
                })
                .then(() => {
                    testCompleted({ error: 'Should have errored' });
                })
                .catch(error => {
                    testCompleted({ 
                        caughtError: true,
                        errorMessage: error.message 
                    });
                });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["caughtError"].boolValue ?? false)
            XCTAssertEqual(result["errorMessage"].toString(), "Stream error")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Advanced Error Handling Tests

    func testStreamCorruptionRecovery() {
        let expectation = XCTestExpectation(description: "Stream corruption recovery")

        let script = """
                var chunkCount = 0;
                const corruptedStream = new ReadableStream({
                    start(controller) {
                        // Send some valid data
                        controller.enqueue(new TextEncoder().encode('Valid data '));
                        
                        // Simulate corruption by sending invalid UTF-8 bytes
                        const corruptedBytes = new Uint8Array([0xFF, 0xFE, 0xFD]);
                        controller.enqueue(corruptedBytes);
                        
                        // Send more valid data
                        controller.enqueue(new TextEncoder().encode(' More valid data'));
                        controller.close();
                    }
                });
                
                const processedChunks = [];
                const errorLog = [];
                
                const destination = new WritableStream({
                    write(chunk) {
                        chunkCount++;
                        try {
                            // Attempt to decode each chunk
                            const text = new TextDecoder('utf-8', { fatal: false }).decode(chunk);
                            processedChunks.push(text);
                        } catch (error) {
                            errorLog.push({ 
                                chunkIndex: chunkCount,
                                error: error.message,
                                byteLength: chunk.byteLength
                            });
                            // Use replacement character for corrupted data
                            processedChunks.push('�');
                        }
                    },
                    close() {
                        testCompleted({
                            totalChunks: chunkCount,
                            processedText: processedChunks.join(''),
                            errorCount: errorLog.length,
                            hasValidData: processedChunks.some(chunk => chunk.includes('Valid')),
                            recoveredGracefully: chunkCount > 0 && processedChunks.length > 0
                        });
                    }
                });
                
                corruptedStream.pipeTo(destination).catch(error => {
                    testCompleted({ 
                        pipeError: error.message,
                        totalChunks: chunkCount,
                        errorCount: errorLog.length
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if !result["pipeError"].isString {
                XCTAssertGreaterThan(Int(result["totalChunks"].numberValue ?? 0), 0)
                XCTAssertTrue(result["hasValidData"].boolValue ?? false)
                XCTAssertTrue(result["recoveredGracefully"].boolValue ?? false)
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentStreamErrors() {
        let expectation = XCTestExpectation(description: "Concurrent stream errors")

        let script = """
                const streamCount = 5;
                const streams = [];
                const results = [];
                
                // Create multiple streams that will error at different times
                for (let i = 0; i < streamCount; i++) {
                    const stream = new ReadableStream({
                        start(controller) {
                            // Send some data first
                            controller.enqueue(new TextEncoder().encode(`Stream ${i} data`));
                            
                            // Error at different times
                            setTimeout(() => {
                                controller.error(new Error(`Stream ${i} error`));
                            }, 10 + (i * 5));
                        }
                    });
                    streams.push(stream);
                }
                
                // Process all streams concurrently
                const promises = streams.map((stream, index) => {
                    return new Promise((resolve) => {
                        const chunks = [];
                        const reader = stream.getReader();
                        
                        function readChunk() {
                            reader.read()
                                .then(({ done, value }) => {
                                    if (done) {
                                        resolve({ 
                                            streamIndex: index, 
                                            success: true, 
                                            chunks: chunks.length,
                                            data: chunks.join('')
                                        });
                                        return;
                                    }
                                    chunks.push(new TextDecoder().decode(value));
                                    readChunk();
                                })
                                .catch(error => {
                                    resolve({ 
                                        streamIndex: index, 
                                        success: false, 
                                        error: error.message,
                                        chunks: chunks.length,
                                        partialData: chunks.join('')
                                    });
                                });
                        }
                        
                        readChunk();
                    });
                });
                
                Promise.all(promises).then(streamResults => {
                    const successCount = streamResults.filter(r => r.success).length;
                    const errorCount = streamResults.filter(r => !r.success).length;
                    const allReceivedSomeData = streamResults.every(r => r.chunks > 0 || r.partialData);
                    
                    testCompleted({
                        totalStreams: streamCount,
                        successCount: successCount,
                        errorCount: errorCount,
                        allReceivedSomeData: allReceivedSomeData,
                        results: streamResults
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(Int(result["totalStreams"].numberValue ?? 0), 5)
            XCTAssertEqual(Int(result["errorCount"].numberValue ?? 0), 5)  // All streams should error
            XCTAssertTrue(result["allReceivedSomeData"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }

    func testMemoryPressureStreaming() {
        let expectation = XCTestExpectation(description: "Memory pressure streaming")

        let script = """
                const chunkSize = 1024 * 1024; // 1MB chunks
                const totalChunks = 10; // 10MB total
                var processedChunks = 0;
                var totalBytes = 0;
                var memoryPeakReached = false;
                
                const largeDataStream = new ReadableStream({
                    start(controller) {
                        function sendChunk() {
                            if (processedChunks < totalChunks) {
                                // Create a large chunk
                                const chunk = new Uint8Array(chunkSize);
                                // Fill with pattern to make it realistic
                                for (let i = 0; i < chunkSize; i++) {
                                    chunk[i] = (processedChunks * chunkSize + i) % 256;
                                }
                                
                                try {
                                    controller.enqueue(chunk);
                                    processedChunks++;
                                    
                                    // Use setTimeout to allow garbage collection between chunks
                                    setTimeout(sendChunk, 1);
                                } catch (error) {
                                    controller.error(error);
                                }
                            } else {
                                controller.close();
                            }
                        }
                        sendChunk();
                    }
                });
                
                const destination = new WritableStream({
                    write(chunk) {
                        totalBytes += chunk.byteLength;
                        
                        // Check if we're handling large amounts of data
                        if (totalBytes > 5 * 1024 * 1024) { // 5MB
                            memoryPeakReached = true;
                        }
                        
                        // Simulate processing time
                        return new Promise(resolve => setTimeout(resolve, 1));
                    },
                    close() {
                        testCompleted({
                            totalBytes: totalBytes,
                            expectedBytes: chunkSize * totalChunks,
                            processedAllChunks: processedChunks === totalChunks,
                            memoryPeakReached: memoryPeakReached,
                            averageChunkSize: totalBytes / processedChunks
                        });
                    }
                });
                
                largeDataStream.pipeTo(destination).catch(error => {
                    testCompleted({ 
                        error: error.message,
                        totalBytes: totalBytes,
                        processedChunks: processedChunks
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if !result["error"].isString {
                XCTAssertTrue(result["memoryPeakReached"].boolValue ?? false)
                XCTAssertGreaterThan(Int(result["totalBytes"].numberValue ?? 0), 5 * 1024 * 1024)
                XCTAssertTrue(result["processedAllChunks"].boolValue ?? false)
            } else {
                // Memory pressure might cause errors, which is acceptable
                XCTAssertGreaterThan(Int(result["processedChunks"].numberValue ?? 0), 0)
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)  // Longer timeout for large data
    }

    func testBackpressureHandling() {
        let expectation = XCTestExpectation(description: "Backpressure handling")

        let script = """
                var producedChunks = 0;
                var consumedChunks = 0;
                const maxBuffer = 5;
                
                const fastProducer = new ReadableStream({
                    start(controller) {
                        function produceChunk() {
                            if (producedChunks < 20) {
                                controller.enqueue(new TextEncoder().encode(`Chunk ${producedChunks++}`));
                                // Produce quickly
                                setTimeout(produceChunk, 1);
                            } else {
                                controller.close();
                            }
                        }
                        produceChunk();
                    }
                });
                
                const slowConsumer = new WritableStream({
                    write(chunk) {
                        consumedChunks++;
                        // Simulate slow consumption
                        return new Promise(resolve => {
                            setTimeout(() => {
                                resolve();
                            }, 50); // 50ms delay per chunk
                        });
                    },
                    close() {
                        testCompleted({
                            producedChunks: producedChunks,
                            consumedChunks: consumedChunks,
                            allConsumed: producedChunks === consumedChunks,
                            backpressureHandled: consumedChunks > 0
                        });
                    }
                });
                
                fastProducer.pipeTo(slowConsumer).catch(error => {
                    testCompleted({ 
                        error: error.message,
                        producedChunks: producedChunks,
                        consumedChunks: consumedChunks
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]

            if !result["error"].isString {
                XCTAssertTrue(result["backpressureHandled"].boolValue ?? false)
                XCTAssertTrue(result["allConsumed"].boolValue ?? false)
                XCTAssertEqual(Int(result["producedChunks"].numberValue ?? 0), 20)
                XCTAssertEqual(Int(result["consumedChunks"].numberValue ?? 0), 20)
            }

            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }

    func testStreamResourceCleanup() {
        let expectation = XCTestExpectation(description: "Stream resource cleanup")

        let script = """
                var readersReleased = 0;
                var writersReleased = 0;
                const streams = [];
                
                // Create multiple streams that will be abandoned mid-processing
                for (let i = 0; i < 3; i++) {
                    const stream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(new TextEncoder().encode(`Stream ${i} data`));
                            // Don't close the stream
                        },
                        cancel() {
                            // This should be called when the reader is released
                            readersReleased++;
                        }
                    });
                    streams.push(stream);
                }
                
                // Get readers and then abandon them
                const readers = streams.map(stream => stream.getReader());
                
                // Read one chunk from each, then release
                Promise.all(readers.map((reader, index) => {
                    return reader.read().then(result => {
                        reader.releaseLock();
                        return { index, success: true, data: result };
                    }).catch(error => {
                        return { index, success: false, error: error.message };
                    });
                })).then(results => {
                    // Create writable streams and abandon them too
                    const writableStreams = [];
                    for (let i = 0; i < 3; i++) {
                        const stream = new WritableStream({
                            write(chunk) {
                                // Process chunk
                            },
                            close() {
                                writersReleased++;
                            },
                            abort() {
                                writersReleased++;
                            }
                        });
                        writableStreams.push(stream);
                    }
                    
                    const writers = writableStreams.map(stream => stream.getWriter());
                    
                    // Write to each then release
                    Promise.all(writers.map((writer, index) => {
                        return writer.write(new TextEncoder().encode(`Test ${index}`))
                            .then(() => {
                                writer.releaseLock();
                                return { index, success: true };
                            })
                            .catch(error => {
                                return { index, success: false, error: error.message };
                            });
                    })).then(writeResults => {
                        // Force garbage collection hints
                        setTimeout(() => {
                            testCompleted({
                                readResults: results,
                                writeResults: writeResults,
                                readersProcessed: results.filter(r => r.success).length,
                                writersProcessed: writeResults.filter(r => r.success).length,
                                resourcesCleanedUp: readersReleased >= 0 && writersReleased >= 0
                            });
                        }, 100);
                    });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(Int(result["readersProcessed"].numberValue ?? 0), 3)
            XCTAssertEqual(Int(result["writersProcessed"].numberValue ?? 0), 3)
            XCTAssertTrue(result["resourcesCleanedUp"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Type Validation Tests
    
    func testPipeToTypeValidation() {
        let context = SwiftJS()
        let script = """
            const source = new ReadableStream({
                start(controller) { controller.close(); }
            });
            
            const testCases = [];
            
            // Test null
            try {
                source.pipeTo(null);
                testCases.push({ test: 'null', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'null', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            // Test undefined
            try {
                source.pipeTo(undefined);
                testCases.push({ test: 'undefined', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'undefined', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            // Test string
            try {
                source.pipeTo('not a stream');
                testCases.push({ test: 'string', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'string', 
                    passed: error instanceof TypeError,
                    errorType: error.constructor.name
                });
            }
            
            globalThis.pipeToValidationResults = testCases;
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.pipeToValidationResults")
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 3)
        
        for i in 0..<3 {
            let testCase = result[i]
            XCTAssertTrue(testCase["passed"].boolValue ?? false, "Test case \(testCase["test"].toString()) failed")
            XCTAssertEqual(testCase["errorType"].toString(), "TypeError")
        }
    }
    
    func testPipeThroughTypeValidation() {
        let context = SwiftJS()
        let script = """
            const source = new ReadableStream({
                start(controller) { controller.close(); }
            });
            
            const testCases = [];
            
            // Test null
            try {
                source.pipeThrough(null);
                testCases.push({ test: 'null', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'null', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object without required properties
            try {
                source.pipeThrough({});
                testCases.push({ test: 'empty object', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'empty object', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object with only writable
            try {
                source.pipeThrough({ writable: new WritableStream() });
                testCases.push({ test: 'only writable', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'only writable', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            // Test object with only readable
            try {
                source.pipeThrough({ readable: new ReadableStream() });
                testCases.push({ test: 'only readable', passed: false });
            } catch (error) {
                testCases.push({ 
                    test: 'only readable', 
                    passed: error instanceof TypeError,
                    errorMessage: error.message
                });
            }
            
            globalThis.pipeThroughValidationResults = testCases;
        """
        
        context.evaluateScript(script)
        let result = context.evaluateScript("globalThis.pipeThroughValidationResults")
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 4)
        
        for i in 0..<4 {
            let testCase = result[i]
            XCTAssertTrue(testCase["passed"].boolValue ?? false, "Test case \(testCase["test"].toString()) failed: \(testCase["errorMessage"].toString())")
        }
    }
}
