//
// StreamingEncodingTests.swift
// SwiftJS
//
// MIT License
//
// Copyright (c) 2025 o2ter
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
@testable import SwiftJS

final class StreamingEncodingTests: XCTestCase {
    
    func testTextEncoderStream() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "TextEncoderStream encoding")
        
        context.base.exceptionHandler = { context, exception in
            if let error = exception?.toString() {
                XCTFail("JavaScript Error: \(error)")
            }
        }
        
        let script = """
        (async () => {
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue('Hello');
                    controller.enqueue(' ');
                    controller.enqueue('World');
                    controller.close();
                }
            });
            
            var encoderStream = new TextEncoderStream();
            var encoded = stream.pipeThrough(encoderStream);
            
            var chunks = [];
            var reader = encoded.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            return ({
                chunkCount: chunks.length,
                totalBytes: chunks.reduce((sum, chunk) => sum + chunk.length, 0),
                firstChunk: Array.from(chunks[0]),
                isUint8Array: chunks[0] instanceof Uint8Array
            });
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let chunkCount = Int(value["chunkCount"].numberValue ?? 0)
                let totalBytes = Int(value["totalBytes"].numberValue ?? 0)
                let isUint8Array = value["isUint8Array"].boolValue
                
                XCTAssertGreaterThan(chunkCount, 0, "Should have encoded chunks")
                XCTAssertEqual(totalBytes, 11, "Should encode 'Hello World' (11 bytes)")
                XCTAssertTrue(isUint8Array, "Chunks should be Uint8Array")
                
                resolve(value)
                expectation.fulfill()
            } catch: { error in
                XCTFail("Promise rejected: \(error)")
                reject(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTextDecoderStream() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "TextDecoderStream decoding")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode('Hello'));
                    controller.enqueue(encoder.encode(' '));
                    controller.enqueue(encoder.encode('World'));
                    controller.close();
                }
            });
            
            var decoderStream = new TextDecoderStream();
            var decoded = stream.pipeThrough(decoderStream);
            
            var chunks = [];
            var reader = decoded.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            return ({
                chunkCount: chunks.length,
                fullText: chunks.join(''),
                isString: typeof chunks[0] === 'string'
            });
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let chunkCount = Int(value["chunkCount"].numberValue ?? 0)
                let fullText = value["fullText"].stringValue ?? ""
                let isString = value["isString"].boolValue
                
                XCTAssertGreaterThan(chunkCount, 0, "Should have decoded chunks")
                XCTAssertEqual(fullText, "Hello World", "Should decode to 'Hello World'")
                XCTAssertTrue(isString, "Chunks should be strings")
                
                resolve(value)
                expectation.fulfill()
            } catch: { error in
                XCTFail("Promise rejected: \(error)")
                reject(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTextEncoderStreamUTF8() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "TextEncoderStream UTF-8 encoding")
        
        let script = """
        (async () => {
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue('Hello 世界 🌍');
                    controller.close();
                }
            });
            
            var encoderStream = new TextEncoderStream();
            var encoded = stream.pipeThrough(encoderStream);
            
            var chunks = [];
            var reader = encoded.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            var totalBytes = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
            return totalBytes;
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let totalBytes = Int(value.numberValue ?? 0)
                // "Hello 世界 🌍" = 5 + 1 + 6 + 1 + 4 = 17 bytes in UTF-8
                XCTAssertEqual(totalBytes, 17, "Should correctly encode multi-byte UTF-8 characters")
                
                resolve(value)
                expectation.fulfill()
            } catch: { error in
                XCTFail("Promise rejected: \(error)")
                reject(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTextDecoderStreamUTF8() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "TextDecoderStream UTF-8 decoding")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode('Hello 世界 🌍'));
                    controller.close();
                }
            });
            
            var decoderStream = new TextDecoderStream();
            var decoded = stream.pipeThrough(decoderStream);
            
            var chunks = [];
            var reader = decoded.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            return chunks.join('');
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let text = value.stringValue ?? ""
                XCTAssertEqual(text, "Hello 世界 🌍", "Should correctly decode multi-byte UTF-8 characters")
                
                resolve(value)
                expectation.fulfill()
            } catch: { error in
                XCTFail("Promise rejected: \(error)")
                reject(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTextEncoderDecoderRoundTrip() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "TextEncoder/Decoder round trip")
        
        let script = """
        (async () => {
            var original = 'Test string with émojis 🎉 and unicode ñ';
            
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(original);
                    controller.close();
                }
            });
            
            var encoded = stream.pipeThrough(new TextEncoderStream());
            var decoded = encoded.pipeThrough(new TextDecoderStream());
            
            var chunks = [];
            var reader = decoded.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            var result = chunks.join('');
            return ({
                original: original,
                result: result,
                match: original === result
            });
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let match = value["match"].boolValue
                XCTAssertTrue(match, "Encode/decode round trip should preserve original text")
                
                resolve(value)
                expectation.fulfill()
            } catch: { error in
                XCTFail("Promise rejected: \(error)")
                reject(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
