//
//  CompressionTests.swift
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

/// Tests for the Compression Streams API
@MainActor
final class CompressionTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testCompressionStreamExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof CompressionStream")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testDecompressionStreamExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof DecompressionStream")
        XCTAssertEqual(result.toString(), "function")
    }
    
    // MARK: - Basic Compression/Decompression Tests
    
    func testGzipCompressionDecompression() {
        let expectation = XCTestExpectation(description: "gzip compression/decompression")
        
        let script = """
            (async () => {
                const input = 'Hello, World! This is a test of gzip compression.';
                const inputBytes = new TextEncoder().encode(input);
                
                // Compress
                const compressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(inputBytes);
                        controller.close();
                    }
                }).pipeThrough(new CompressionStream('gzip'));
                
                const compressedReader = compressedStream.getReader();
                const compressedChunks = [];
                while (true) {
                    const { done, value } = await compressedReader.read();
                    if (done) break;
                    compressedChunks.push(value);
                }
                
                // Combine compressed chunks
                const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const compressed = new Uint8Array(totalLength);
                let offset = 0;
                for (const chunk of compressedChunks) {
                    compressed.set(chunk, offset);
                    offset += chunk.length;
                }
                
                // Decompress
                const decompressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(compressed);
                        controller.close();
                    }
                }).pipeThrough(new DecompressionStream('gzip'));
                
                const decompressedReader = decompressedStream.getReader();
                const decompressedChunks = [];
                while (true) {
                    const { done, value } = await decompressedReader.read();
                    if (done) break;
                    decompressedChunks.push(value);
                }
                
                // Combine decompressed chunks
                const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const decompressed = new Uint8Array(decompressedTotalLength);
                let decompressedOffset = 0;
                for (const chunk of decompressedChunks) {
                    decompressed.set(chunk, decompressedOffset);
                    decompressedOffset += chunk.length;
                }
                
                const output = new TextDecoder().decode(decompressed);
                
                testCompleted({
                    input: input,
                    output: output,
                    match: input === output,
                    compressedSize: compressed.length,
                    originalSize: inputBytes.length
                });
            })().catch(error => testCompleted({ error: error.message }));
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["match"].boolValue, true)
            XCTAssertEqual(result["input"].toString(), result["output"].toString())
            
            let originalSize = Int(result["originalSize"].numberValue ?? 0)
            let compressedSize = Int(result["compressedSize"].numberValue ?? 0)
            XCTAssertGreaterThan(originalSize, 0)
            XCTAssertGreaterThan(compressedSize, 0)
            XCTAssertLessThan(compressedSize, originalSize, "Compressed size should be smaller")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDeflateCompressionDecompression() {
        let expectation = XCTestExpectation(description: "deflate compression/decompression")
        
        let script = """
            (async () => {
                const input = 'Testing deflate compression with a moderately long string to ensure compression works.';
                const inputBytes = new TextEncoder().encode(input);
                
                // Compress
                const compressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(inputBytes);
                        controller.close();
                    }
                }).pipeThrough(new CompressionStream('deflate'));
                
                const compressedReader = compressedStream.getReader();
                const compressedChunks = [];
                while (true) {
                    const { done, value } = await compressedReader.read();
                    if (done) break;
                    compressedChunks.push(value);
                }
                
                const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const compressed = new Uint8Array(totalLength);
                let offset = 0;
                for (const chunk of compressedChunks) {
                    compressed.set(chunk, offset);
                    offset += chunk.length;
                }
                
                // Decompress
                const decompressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(compressed);
                        controller.close();
                    }
                }).pipeThrough(new DecompressionStream('deflate'));
                
                const decompressedReader = decompressedStream.getReader();
                const decompressedChunks = [];
                while (true) {
                    const { done, value } = await decompressedReader.read();
                    if (done) break;
                    decompressedChunks.push(value);
                }
                
                const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const decompressed = new Uint8Array(decompressedTotalLength);
                let decompressedOffset = 0;
                for (const chunk of decompressedChunks) {
                    decompressed.set(chunk, decompressedOffset);
                    decompressedOffset += chunk.length;
                }
                
                const output = new TextDecoder().decode(decompressed);
                
                testCompleted({
                    input: input,
                    output: output,
                    match: input === output
                });
            })().catch(error => testCompleted({ error: error.message }));
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["match"].boolValue, true)
            XCTAssertEqual(result["input"].toString(), result["output"].toString())
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDeflateRawCompressionDecompression() {
        let expectation = XCTestExpectation(description: "deflate-raw compression/decompression")
        
        let script = """
            (async () => {
                const input = 'Raw deflate test string with sufficient content for compression benefits.';
                const inputBytes = new TextEncoder().encode(input);
                
                // Compress
                const compressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(inputBytes);
                        controller.close();
                    }
                }).pipeThrough(new CompressionStream('deflate-raw'));
                
                const compressedReader = compressedStream.getReader();
                const compressedChunks = [];
                while (true) {
                    const { done, value } = await compressedReader.read();
                    if (done) break;
                    compressedChunks.push(value);
                }
                
                const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const compressed = new Uint8Array(totalLength);
                let offset = 0;
                for (const chunk of compressedChunks) {
                    compressed.set(chunk, offset);
                    offset += chunk.length;
                }
                
                // Decompress
                const decompressedStream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(compressed);
                        controller.close();
                    }
                }).pipeThrough(new DecompressionStream('deflate-raw'));
                
                const decompressedReader = decompressedStream.getReader();
                const decompressedChunks = [];
                while (true) {
                    const { done, value } = await decompressedReader.read();
                    if (done) break;
                    decompressedChunks.push(value);
                }
                
                const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                const decompressed = new Uint8Array(decompressedTotalLength);
                let decompressedOffset = 0;
                for (const chunk of decompressedChunks) {
                    decompressed.set(chunk, decompressedOffset);
                    decompressedOffset += chunk.length;
                }
                
                const output = new TextDecoder().decode(decompressed);
                
                testCompleted({
                    input: input,
                    output: output,
                    match: input === output
                });
            })().catch(error => testCompleted({ error: error.message }));
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["match"].boolValue, true)
            XCTAssertEqual(result["input"].toString(), result["output"].toString())
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCompressionFormat() {
        let context = SwiftJS()
        
        let script = """
            try {
                new CompressionStream('invalid-format');
                'no-error';
            } catch (e) {
                e.message;
            }
        """
        
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.toString().contains("Unsupported compression format"))
    }
    
    func testInvalidDecompressionFormat() {
        let context = SwiftJS()
        
        let script = """
            try {
                new DecompressionStream('invalid-format');
                'no-error';
            } catch (e) {
                e.message;
            }
        """
        
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.toString().contains("Unsupported compression format"))
    }
    
    // MARK: - Integration Tests
    
    func testCompressionStreamReadableWritable() {
        let context = SwiftJS()
        
        let script = """
            const stream = new CompressionStream('gzip');
            const hasReadable = stream.readable instanceof ReadableStream;
            const hasWritable = stream.writable instanceof WritableStream;
            ({ hasReadable, hasWritable });
        """
        
        let result = context.evaluateScript(script)
        XCTAssertEqual(result["hasReadable"].boolValue, true)
        XCTAssertEqual(result["hasWritable"].boolValue, true)
    }
    
    func testDecompressionStreamReadableWritable() {
        let context = SwiftJS()
        
        let script = """
            const stream = new DecompressionStream('deflate');
            const hasReadable = stream.readable instanceof ReadableStream;
            const hasWritable = stream.writable instanceof WritableStream;
            ({ hasReadable, hasWritable });
        """
        
        let result = context.evaluateScript(script)
        XCTAssertEqual(result["hasReadable"].boolValue, true)
        XCTAssertEqual(result["hasWritable"].boolValue, true)
    }
}
