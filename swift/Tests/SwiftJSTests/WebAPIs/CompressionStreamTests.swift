//
// CompressionStreamTests.swift
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

final class CompressionStreamTests: XCTestCase {
    
    func testCompressionStreamGzip() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "CompressionStream gzip")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var original = 'Hello World! '.repeat(100); // Repetitive data compresses well
            
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode(original));
                    controller.close();
                }
            });
            
            var compressed = stream.pipeThrough(new CompressionStream('gzip'));
            
            var chunks = [];
            var reader = compressed.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            var compressedSize = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
            var originalSize = encoder.encode(original).length;
            
            return ({
                originalSize: originalSize,
                compressedSize: compressedSize,
                compressionRatio: compressedSize / originalSize,
                isSmaller: compressedSize < originalSize
            });
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let isSmaller = value["isSmaller"].boolValue
                let compressionRatio = value["compressionRatio"].numberValue ?? 1.0
                
                XCTAssertTrue(isSmaller, "Compressed data should be smaller than original")
                XCTAssertLessThan(compressionRatio, 0.5, "Compression ratio should be < 0.5 for repetitive data")
                
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
    
    func testDecompressionStreamGzip() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "DecompressionStream gzip")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var decoder = new TextDecoder();
            var original = 'Hello World! '.repeat(50);
            
            // Compress
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode(original));
                    controller.close();
                }
            });
            var compressed = stream.pipeThrough(new CompressionStream('gzip'));
            
            // Collect compressed chunks
            var compressedChunks = [];
            var reader = compressed.getReader();
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                compressedChunks.push(result.value);
            }
            
            // Decompress
            var compressedStream = new ReadableStream({
                start(controller) {
                    for (var chunk of compressedChunks) {
                        controller.enqueue(chunk);
                    }
                    controller.close();
                }
            });
            var decompressed = compressedStream.pipeThrough(new DecompressionStream('gzip'));
            
            // Collect decompressed chunks
            var decompressedChunks = [];
            reader = decompressed.getReader();
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                decompressedChunks.push(result.value);
            }
            
            var result = decoder.decode(decompressedChunks[0]);
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
                XCTAssertTrue(match, "Decompressed data should match original")
                
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
    
    func testCompressionStreamDeflate() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "CompressionStream deflate")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var original = 'Test data '.repeat(100);
            
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode(original));
                    controller.close();
                }
            });
            
            var compressed = stream.pipeThrough(new CompressionStream('deflate'));
            
            var chunks = [];
            var reader = compressed.getReader();
            
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                chunks.push(result.value);
            }
            
            var compressedSize = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
            var originalSize = encoder.encode(original).length;
            
            return compressedSize < originalSize;
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let isSmaller = value.boolValue
                XCTAssertTrue(isSmaller, "Deflate compressed data should be smaller")
                
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
    
    func testCompressionDecompressionRoundTrip() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "Compression/Decompression round trip")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var decoder = new TextDecoder();
            var original = 'The quick brown fox jumps over the lazy dog. '.repeat(20);
            
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode(original));
                    controller.close();
                }
            });
            
            var result = stream
                .pipeThrough(new CompressionStream('gzip'))
                .pipeThrough(new DecompressionStream('gzip'));
            
            var chunks = [];
            var reader = result.getReader();
            
            while (true) {
                var readResult = await reader.read();
                if (readResult.done) break;
                chunks.push(readResult.value);
            }
            
            var decompressed = decoder.decode(chunks[0]);
            return ({
                original: original,
                decompressed: decompressed,
                match: original === decompressed,
                length: decompressed.length
            });
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let match = value["match"].boolValue
                let originalLength = (value["original"].stringValue ?? "").count
                let decompressedLength = Int(value["length"].numberValue ?? 0)
                
                XCTAssertTrue(match, "Round trip should preserve data")
                XCTAssertEqual(decompressedLength, originalLength, "Lengths should match")
                
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
    
    func testCompressionStreamDeflateRaw() {
        let context = SwiftJS()
        let expectation = XCTestExpectation(description: "CompressionStream deflate-raw")
        
        let script = """
        (async () => {
            var encoder = new TextEncoder();
            var decoder = new TextDecoder();
            var original = 'Deflate-raw test data. '.repeat(30);
            
            var stream = new ReadableStream({
                start(controller) {
                    controller.enqueue(encoder.encode(original));
                    controller.close();
                }
            });
            
            var compressed = stream.pipeThrough(new CompressionStream('deflate-raw'));
            var compressedChunks = [];
            var reader = compressed.getReader();
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                compressedChunks.push(result.value);
            }
            
            // Decompress
            var compressedStream = new ReadableStream({
                start(controller) {
                    for (var chunk of compressedChunks) {
                        controller.enqueue(chunk);
                    }
                    controller.close();
                }
            });
            var decompressed = compressedStream.pipeThrough(new DecompressionStream('deflate-raw'));
            
            var decompressedChunks = [];
            reader = decompressed.getReader();
            while (true) {
                var result = await reader.read();
                if (result.done) break;
                decompressedChunks.push(result.value);
            }
            
            var result = decoder.decode(decompressedChunks[0]);
            return original === result;
        })()
        """
        
        SwiftJS.Value(newPromiseIn: context) { resolve, reject in
            let result = context.evaluateScript(script)
            result.then { value in
                let match = value.boolValue
                XCTAssertTrue(match, "Deflate-raw round trip should preserve data")
                
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
