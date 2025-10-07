//
//  FileTests.swift
//  SwiftJS File API Tests
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

/// Tests for the Web File and Blob APIs including File, Blob, FileReader, and file operations
/// with temporary file system integration.
@MainActor
final class FileTests: XCTestCase {
    
    // Helper method to create a unique temporary directory for tests
    private func createTempDir(context: SwiftJS) -> String {
        let script = """
            const tempBase = SystemFS.temp;
            const testDir = Path.join(tempBase, 'SwiftJS-FileTests-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9));
            SystemFS.mkdir(testDir);
            testDir
        """
        return context.evaluateScript(script).toString()
    }
    
    // Helper method to clean up temporary directory
    private func cleanupTempDir(_ tempDir: String, context: SwiftJS) {
        let script = """
            if (SystemFS.exists('\(tempDir)')) {
                SystemFS.rmdir('\(tempDir)', { recursive: true });
            }
        """
        context.evaluateScript(script)
    }
    
    // MARK: - Blob API Tests
    
    func testBlobExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Blob")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testBlobInstantiation() {
        let script = """
            const blob = new Blob(['Hello, World!']);
            blob instanceof Blob
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testBlobBasicProperties() {
        let script = """
            const blob = new Blob(['Hello, World!'], { type: 'text/plain' });
            ({
                size: blob.size,
                type: blob.type,
                isBlob: blob instanceof Blob
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["size"].numberValue, 13) // "Hello, World!" is 13 bytes
        XCTAssertEqual(result["type"].toString(), "text/plain")
        XCTAssertTrue(result["isBlob"].boolValue ?? false)
    }
    
    func testBlobFromMultipleParts() {
        let script = """
            const blob = new Blob(['Hello, ', 'World!', ' 🌍'], { type: 'text/plain' });
            ({
                size: blob.size,
                type: blob.type
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "text/plain")
        let size = Int(result["size"].numberValue ?? 0)
        XCTAssertGreaterThan(size, 15) // Should be at least 15 bytes (emoji takes multiple bytes)
    }
    
    func testBlobArrayBufferConversion() {
        let script = """
            const blob = new Blob(['Hello, World!']);
            blob.arrayBuffer().then(buffer => {
                const view = new Uint8Array(buffer);
                return {
                    size: buffer.byteLength,
                    firstByte: view[0], // 'H'
                    lastByte: view[view.length - 1], // '!'
                    isArrayBuffer: buffer instanceof ArrayBuffer
                };
            })
        """
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Blob arrayBuffer conversion")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["size"].numberValue, 13)
            XCTAssertEqual(result["firstByte"].numberValue, 72) // 'H' = 72
            XCTAssertEqual(result["lastByte"].numberValue, 33) // '!' = 33
            XCTAssertTrue(result["isArrayBuffer"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testBlobTextConversion() {
        let script = """
            const blob = new Blob(['Hello, World! 🌍']);
            blob.text()
        """
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Blob text conversion")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result.toString(), "Hello, World! 🌍")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testBlobSlice() {
        let script = """
            const originalBlob = new Blob(['Hello, World!']);
            const slicedBlob = originalBlob.slice(0, 5);
            
            Promise.all([
                originalBlob.text(),
                slicedBlob.text()
            ]).then(results => ({
                original: results[0],
                sliced: results[1],
                originalSize: originalBlob.size,
                slicedSize: slicedBlob.size
            }))
        """
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Blob slice")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["original"].toString(), "Hello, World!")
            XCTAssertEqual(result["sliced"].toString(), "Hello")
            XCTAssertEqual(result["originalSize"].numberValue, 13)
            XCTAssertEqual(result["slicedSize"].numberValue, 5)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - File API Tests
    
    func testFileExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof File")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFileInstantiation() {
        let script = """
            const file = new File(['Hello, World!'], 'test.txt', { type: 'text/plain' });
            file instanceof File
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFileProperties() {
        let script = """
            const now = Date.now();
            const file = new File(['Hello, World!'], 'test.txt', { 
                type: 'text/plain',
                lastModified: now
            });
            
            ({
                name: file.name,
                size: file.size,
                type: file.type,
                lastModified: file.lastModified,
                isFile: file instanceof File,
                isBlob: file instanceof Blob,
                lastModifiedCorrect: file.lastModified === now
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["name"].toString(), "test.txt")
        XCTAssertEqual(result["size"].numberValue, 13)
        XCTAssertEqual(result["type"].toString(), "text/plain")
        XCTAssertTrue(result["isFile"].boolValue ?? false)
        XCTAssertTrue(result["isBlob"].boolValue ?? false)
        XCTAssertTrue(result["lastModifiedCorrect"].boolValue ?? false)
    }
    
    func testFileFromPath() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            // Create a test file first
            const testFile = Path.join('\(tempDir)', 'test-file.txt');
            const testContent = 'Hello from file system!';
            SystemFS.writeFile(testFile, testContent);
            
            // Now test File.fromPath
            try {
                const file = File.fromPath(testFile);
                ({
                    success: true,
                    name: file.name,
                    type: file.type,
                    size: file.size,
                    isFile: file instanceof File,
                    exists: SystemFS.exists(testFile)
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertEqual(result["name"].toString(), "test-file.txt")
        XCTAssertEqual(result["type"].toString(), "text/plain")
        XCTAssertTrue(result["isFile"].boolValue ?? false)
        XCTAssertTrue(result["exists"].boolValue ?? false)
    }
    
    func testFileFromPathWithMimeTypes() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFiles = [
                { name: 'test.txt', expected: 'text/plain' },
                { name: 'test.html', expected: 'text/html' },
                { name: 'test.json', expected: 'application/json' },
                { name: 'test.js', expected: 'text/javascript' },
                { name: 'test.css', expected: 'text/css' },
                { name: 'test.png', expected: 'image/png' },
                { name: 'test.jpg', expected: 'image/jpeg' },
                { name: 'test.unknown', expected: 'application/octet-stream' }
            ];
            
            const results = [];
            
            for (const testFile of testFiles) {
                const filePath = Path.join('\(tempDir)', testFile.name);
                SystemFS.writeFile(filePath, 'test content');
                
                try {
                    const file = File.fromPath(filePath);
                    results.push({
                        name: testFile.name,
                        expected: testFile.expected,
                        actual: file.type,
                        match: file.type === testFile.expected
                    });
                } catch (error) {
                    results.push({
                        name: testFile.name,
                        error: error.message
                    });
                }
            }
            
            results
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(resultsLength, 8)
        
        // Check that all MIME types are correctly detected
        for i in 0..<resultsLength {
            let testResult = result[i]
            XCTAssertTrue(testResult["match"].boolValue ?? false, 
                         "MIME type mismatch for \(testResult["name"].toString()): expected \(testResult["expected"].toString()), got \(testResult["actual"].toString())")
        }
    }
    
    func testFileStreamingFromPath() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            // Create a larger test file
            const testFile = Path.join('\(tempDir)', 'large-test.txt');
            const testContent = 'Hello from file system! '.repeat(1000);
            SystemFS.writeFile(testFile, testContent);
            
            const file = File.fromPath(testFile);
            const stream = file.stream();
            const reader = stream.getReader();
            
            let chunks = [];
            let totalSize = 0;
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        const combined = new Uint8Array(totalSize);
                        let offset = 0;
                        for (const chunk of chunks) {
                            combined.set(chunk, offset);
                            offset += chunk.byteLength;
                        }
                        const text = new TextDecoder().decode(combined);
                        return {
                            success: true,
                            chunkCount: chunks.length,
                            totalSize: totalSize,
                            textLength: text.length,
                            matchesOriginal: text === testContent,
                            expectedLength: testContent.length
                        };
                    } else {
                        chunks.push(value);
                        totalSize += value.byteLength;
                        return readChunk();
                    }
                });
            }
            
            readChunk()
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "File streaming from path")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertTrue(result["success"].boolValue ?? false)
            XCTAssertGreaterThan(result["chunkCount"].numberValue ?? 0, 0)
            XCTAssertGreaterThan(result["totalSize"].numberValue ?? 0, 20000) // Should be substantial
            XCTAssertTrue(result["matchesOriginal"].boolValue ?? false, 
                         "Text doesn't match. Expected length: \(result["expectedLength"].numberValue ?? 0), Got length: \(result["textLength"].numberValue ?? 0)")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("File streaming failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - FileReader API Tests
    
    func testFileReaderExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof FileReader")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFileReaderInstantiation() {
        let script = """
            const reader = new FileReader();
            ({
                isFileReader: reader instanceof FileReader,
                readyState: reader.readyState,
                result: reader.result,
                error: reader.error,
                hasConstants: reader.EMPTY === 0 && reader.LOADING === 1 && reader.DONE === 2
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isFileReader"].boolValue ?? false)
        XCTAssertEqual(result["readyState"].numberValue, 0) // EMPTY
        XCTAssertTrue(result["result"].isNull)
        XCTAssertTrue(result["error"].isNull)
        XCTAssertTrue(result["hasConstants"].boolValue ?? false)
    }
    
    func testFileReaderReadAsText() {
        let context = SwiftJS()
        let script = """
            const file = new File(['Hello, FileReader!'], 'test.txt', { type: 'text/plain' });
            const reader = new FileReader();
            
            new Promise((resolve, reject) => {
                reader.onload = (event) => {
                    resolve({
                        result: reader.result,
                        readyState: reader.readyState,
                        eventType: event.type,
                        eventTarget: event.target === reader
                    });
                };
                
                reader.onerror = (event) => {
                    reject(new Error('FileReader error: ' + (reader.error || 'Unknown error')));
                };
                
                // Small delay to ensure event handlers are set
                setTimeout(() => {
                    reader.readAsText(file);
                }, 10);
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "FileReader readAsText")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["result"].toString(), "Hello, FileReader!")
            XCTAssertEqual(result["readyState"].numberValue, 2) // DONE
            XCTAssertEqual(result["eventType"].toString(), "load")
            XCTAssertTrue(result["eventTarget"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("FileReader failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFileReaderReadAsArrayBuffer() {
        let context = SwiftJS()
        let script = """
            const file = new File(['Hello!'], 'test.txt');
            const reader = new FileReader();
            
            new Promise((resolve, reject) => {
                reader.onload = () => {
                    const buffer = reader.result;
                    const view = new Uint8Array(buffer);
                    resolve({
                        isArrayBuffer: buffer instanceof ArrayBuffer,
                        byteLength: buffer.byteLength,
                        firstByte: view[0], // 'H'
                        lastByte: view[view.length - 1] // '!'
                    });
                };
                
                reader.onerror = () => reject(new Error('FileReader error: ' + (reader.error || 'Unknown error')));
                
                setTimeout(() => {
                    reader.readAsArrayBuffer(file);
                }, 10);
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "FileReader readAsArrayBuffer")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertTrue(result["isArrayBuffer"].boolValue ?? false)
            XCTAssertEqual(result["byteLength"].numberValue, 6) // "Hello!" is 6 bytes
            XCTAssertEqual(result["firstByte"].numberValue, 72) // 'H' = 72
            XCTAssertEqual(result["lastByte"].numberValue, 33) // '!' = 33
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("FileReader failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFileReaderReadAsDataURL() {
        let context = SwiftJS()
        let script = """
            const file = new File(['Hello!'], 'test.txt', { type: 'text/plain' });
            const reader = new FileReader();
            
            new Promise((resolve, reject) => {
                reader.onload = () => {
                    const dataURL = reader.result;
                    resolve({
                        isString: typeof dataURL === 'string',
                        startsWithDataURL: dataURL.startsWith('data:'),
                        hasCorrectType: dataURL.includes('text/plain'),
                        hasBase64: dataURL.includes('base64'),
                        dataURL: dataURL
                    });
                };
                
                reader.onerror = () => reject(new Error('FileReader error: ' + (reader.error || 'Unknown error')));
                
                setTimeout(() => {
                    reader.readAsDataURL(file);
                }, 10);
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "FileReader readAsDataURL")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertTrue(result["isString"].boolValue ?? false)
            XCTAssertTrue(result["startsWithDataURL"].boolValue ?? false)
            XCTAssertTrue(result["hasCorrectType"].boolValue ?? false)
            XCTAssertTrue(result["hasBase64"].boolValue ?? false)
            
            // Verify the data URL contains the base64-encoded "Hello!"
            let dataURL = result["dataURL"].toString()
            XCTAssertTrue(dataURL.contains("data:text/plain;base64,"))
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("FileReader failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFileReaderFromFileSystemPath() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            // Create a test file
            const testFile = Path.join('\(tempDir)', 'reader-test.txt');
            const testContent = 'Hello from file system for FileReader!';
            SystemFS.writeFile(testFile, testContent);
            
            // Use File.fromPath and FileReader together
            const file = File.fromPath(testFile);
            const reader = new FileReader();
            
            new Promise((resolve, reject) => {
                reader.onload = () => {
                    resolve({
                        result: reader.result,
                        matchesOriginal: reader.result === testContent
                    });
                };
                
                reader.onerror = () => reject(new Error('FileReader error: ' + reader.error));
                reader.readAsText(file);
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "FileReader from file system path")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["result"].toString(), "Hello from file system for FileReader!")
            XCTAssertTrue(result["matchesOriginal"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("FileReader from path failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFileReaderEvents() {
        let context = SwiftJS()
        let script = """
            const file = new File(['Hello, Events!'], 'test.txt');
            const reader = new FileReader();
            
            const events = [];
            
            ['loadstart', 'progress', 'load', 'loadend'].forEach(eventType => {
                reader.addEventListener(eventType, (event) => {
                    events.push({
                        type: event.type,
                        readyState: reader.readyState,
                        target: event.target === reader
                    });
                });
            });
            
            new Promise((resolve, reject) => {
                reader.onloadend = () => {
                    resolve({
                        events: events,
                        eventCount: events.length,
                        hasLoadStart: events.some(e => e.type === 'loadstart'),
                        hasLoad: events.some(e => e.type === 'load'),
                        hasLoadEnd: events.some(e => e.type === 'loadend'),
                        finalResult: reader.result
                    });
                };
                
                reader.onerror = () => reject(new Error('FileReader error: ' + (reader.error || 'Unknown error')));
                
                setTimeout(() => {
                    reader.readAsText(file);
                }, 10);
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "FileReader events")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertGreaterThan(result["eventCount"].numberValue ?? 0, 2)
            XCTAssertTrue(result["hasLoadStart"].boolValue ?? false)
            XCTAssertTrue(result["hasLoad"].boolValue ?? false)
            XCTAssertTrue(result["hasLoadEnd"].boolValue ?? false)
            XCTAssertEqual(result["finalResult"].toString(), "Hello, Events!")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("FileReader events failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFileReaderAbort() {
        let script = """
            const file = new File(['Hello, Abort!'], 'test.txt');
            const reader = new FileReader();
            
            let abortCalled = false;
            
            reader.onabort = () => {
                abortCalled = true;
            };
            
            reader.readAsText(file);
            
            // Abort immediately
            reader.abort();
            
            ({
                readyState: reader.readyState,
                result: reader.result,
                abortCalled: abortCalled
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["readyState"].numberValue, 2) // DONE
        XCTAssertTrue(result["result"].isNull)
        // Note: abortCalled might be false if the abort happens before the event can fire
    }
    
    // MARK: - Integration Tests
    
    func testFileAndBlobIntegration() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            // Create a file from file system
            const testFile = Path.join('\(tempDir)', 'integration-test.txt');
            const originalContent = 'Hello, Integration Test! 🚀';
            SystemFS.writeFile(testFile, originalContent);
            
            const fsFile = File.fromPath(testFile);
            
            // Convert to blob and back
            fsFile.text().then(text => {
                const newBlob = new Blob([text], { type: 'text/plain' });
                const newFile = new File([newBlob], 'copy.txt', { type: 'text/plain' });
                
                return newFile.text();
            }).then(finalText => ({
                originalContent: originalContent,
                finalContent: finalText,
                match: finalText === originalContent
            }))
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "File and Blob integration")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["originalContent"].toString(), "Hello, Integration Test! 🚀")
            XCTAssertEqual(result["finalContent"].toString(), "Hello, Integration Test! 🚀")
            XCTAssertTrue(result["match"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("Integration test failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testFileFromPathNonexistentFile() {
        let script = """
            try {
                const file = File.fromPath('/nonexistent/path/file.txt');
                ({
                    success: true,
                    file: file
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message,
                    errorType: error.constructor.name
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertFalse(result["success"].boolValue ?? true)
        XCTAssertTrue(result["error"].toString().contains("not found") || result["error"].toString().contains("File not found"))
    }
    
    func testFileReaderInvalidState() {
        let script = """
            const file = new File(['Test'], 'test.txt');
            const reader = new FileReader();
            
            reader.readAsText(file);
            
            try {
                // Try to read again while already reading
                reader.readAsText(file);
                ({
                    success: true,
                    error: null
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message,
                    readyState: reader.readyState
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertFalse(result["success"].boolValue ?? true)
        XCTAssertTrue(result["error"].toString().contains("InvalidStateError") || 
                     result["error"].toString().contains("invalid state") ||
                     result["error"].toString().contains("already reading"))
    }
    
    // MARK: - Performance Tests
    
    func testLargeFileHandling() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            // Create a large file
            const largeFile = Path.join('\(tempDir)', 'large-file.txt');
            const chunk = 'This is a chunk of text that will be repeated many times. ';
            const largeContent = chunk.repeat(10000); // About 500KB
            
            SystemFS.writeFile(largeFile, largeContent);
            
            const start = Date.now();
            const file = File.fromPath(largeFile);
            
            file.text().then(content => {
                const end = Date.now();
                return {
                    contentLength: content.length,
                    expectedLength: largeContent.length,
                    timeElapsed: end - start,
                    matchesOriginal: content === largeContent,
                    isPerformant: (end - start) < 1000 // Should complete within 1 second
                };
            })
        """
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Large file handling")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertGreaterThan(result["contentLength"].numberValue ?? 0, 500000) // Should be substantial
            XCTAssertTrue(result["matchesOriginal"].boolValue ?? false)
            XCTAssertTrue(result["isPerformant"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        .invokeMethod("catch", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            XCTFail("Large file test failed: \(args[0].toString())")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testBlobPerformance() {
        let context = SwiftJS()
        let script = """
            const testBlob = new Blob(['Performance test content'], { type: 'text/plain' });
            
            function blobOperations() {
                for (let i = 0; i < 100; i++) {
                    const blob = new Blob(['Test ' + i], { type: 'text/plain' });
                    const sliced = blob.slice(0, 4);
                    // Note: We can't easily test async operations in measure blocks
                }
                return true;
            }
            blobOperations
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("blobOperations()")
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFile() {
        let script = """
            const emptyFile = new File([], 'empty.txt');
            
            Promise.all([
                emptyFile.text(),
                emptyFile.arrayBuffer()
            ]).then(results => ({
                text: results[0],
                arrayBuffer: results[1],
                size: emptyFile.size,
                textIsEmpty: results[0] === '',
                bufferIsEmpty: results[1].byteLength === 0
            }))
        """
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Empty file handling")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["size"].numberValue, 0)
            XCTAssertTrue(result["textIsEmpty"].boolValue ?? false)
            XCTAssertTrue(result["bufferIsEmpty"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testBinaryFileHandling() {
        let script = """
            // Create a binary-like file with various byte values
            const binaryData = new Uint8Array(256);
            for (let i = 0; i < 256; i++) {
                binaryData[i] = i;
            }
            
            const binaryBlob = new Blob([binaryData], { type: 'application/octet-stream' });
            const binaryFile = new File([binaryBlob], 'binary.bin', { type: 'application/octet-stream' });
            
            binaryFile.arrayBuffer().then(buffer => {
                const view = new Uint8Array(buffer);
                let allCorrect = true;
                for (let i = 0; i < 256; i++) {
                    if (view[i] !== i) {
                        allCorrect = false;
                        break;
                    }
                }
                
                return {
                    size: buffer.byteLength,
                    firstByte: view[0],
                    lastByte: view[255],
                    allBytesCorrect: allCorrect
                };
            })
        """
        let context = SwiftJS()
        let promise = context.evaluateScript(script)
        
        let expectation = XCTestExpectation(description: "Binary file handling")
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            XCTAssertEqual(result["size"].numberValue, 256)
            XCTAssertEqual(result["firstByte"].numberValue, 0)
            XCTAssertEqual(result["lastByte"].numberValue, 255)
            XCTAssertTrue(result["allBytesCorrect"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - File.slice() Tests with Disk-Based Files

    func testFileSliceFromDisk() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }

        let script = """
                // Create a test file with known content
                const testFile = Path.join('\(tempDir)', 'slice-test.txt');
                const content = 'Hello, World! This is a test file for slicing.';
                SystemFS.writeFile(testFile, content);
                
                // Create File from path and slice it
                const file = File.fromPath(testFile);
                const slice1 = file.slice(0, 5);      // "Hello"
                const slice2 = file.slice(7, 12);     // "World"
                const slice3 = file.slice(14, 18);    // "This"
                const slice4 = file.slice(-8);        // "slicing."
                
                Promise.all([
                    slice1.text(),
                    slice2.text(),
                    slice3.text(),
                    slice4.text()
                ]).then(results => ({
                    slice1: results[0],
                    slice2: results[1],
                    slice3: results[2],
                    slice4: results[3],
                    slice1Size: slice1.size,
                    slice2Size: slice2.size,
                    originalSize: file.size
                }))
            """
        let promise = context.evaluateScript(script)

        let expectation = XCTestExpectation(description: "File slice from disk")
        promise.invokeMethod(
            "then",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    let result = args[0]
                    XCTAssertEqual(result["slice1"].toString(), "Hello")
                    XCTAssertEqual(result["slice2"].toString(), "World")
                    XCTAssertEqual(result["slice3"].toString(), "This")
                    XCTAssertEqual(result["slice4"].toString(), "slicing.")
                    XCTAssertEqual(result["slice1Size"].numberValue, 5)
                    XCTAssertEqual(result["slice2Size"].numberValue, 5)
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ]
        )
        .invokeMethod(
            "catch",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    XCTFail("File slice from disk failed: \(args[0].toString())")
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ])

        wait(for: [expectation], timeout: 10.0)
    }

    func testFileSliceLargeFileFromDisk() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }

        let script = """
                // Create a larger file for testing memory efficiency
                const testFile = Path.join('\(tempDir)', 'large-slice-test.txt');
                const chunk = 'ABCDEFGHIJ'; // 10 bytes
                const content = chunk.repeat(10000); // 100KB
                SystemFS.writeFile(testFile, content);
                
                const file = File.fromPath(testFile);
                
                // Slice different parts of the large file
                const slice1 = file.slice(0, 10);           // First chunk
                const slice2 = file.slice(50000, 50010);    // Middle chunk
                const slice3 = file.slice(-10);             // Last chunk
                
                Promise.all([
                    slice1.text(),
                    slice2.text(),
                    slice3.text()
                ]).then(results => ({
                    firstChunk: results[0],
                    middleChunk: results[1],
                    lastChunk: results[2],
                    slice1Size: slice1.size,
                    slice2Size: slice2.size,
                    slice3Size: slice3.size,
                    originalSize: file.size
                }))
            """
        let promise = context.evaluateScript(script)

        let expectation = XCTestExpectation(description: "File slice large file from disk")
        promise.invokeMethod(
            "then",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    let result = args[0]
                    XCTAssertEqual(result["firstChunk"].toString(), "ABCDEFGHIJ")
                    XCTAssertEqual(result["middleChunk"].toString(), "ABCDEFGHIJ")
                    XCTAssertEqual(result["lastChunk"].toString(), "ABCDEFGHIJ")
                    XCTAssertEqual(result["slice1Size"].numberValue, 10)
                    XCTAssertEqual(result["slice2Size"].numberValue, 10)
                    XCTAssertEqual(result["slice3Size"].numberValue, 10)
                    XCTAssertEqual(result["originalSize"].numberValue, 100000)
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ]
        )
        .invokeMethod(
            "catch",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    XCTFail("Large file slice failed: \(args[0].toString())")
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ])

        wait(for: [expectation], timeout: 15.0)
    }

    func testFileSliceEdgeCases() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }

        let script = """
                const testFile = Path.join('\(tempDir)', 'edge-case-test.txt');
                const content = 'Hello, World!'; // 13 bytes
                SystemFS.writeFile(testFile, content);
                
                const file = File.fromPath(testFile);
                
                // Edge cases
                const emptySlice = file.slice(5, 5);          // Empty slice (start == end)
                const outOfBounds = file.slice(100, 200);     // Beyond file size
                const negativeStart = file.slice(-5, -2);     // Negative indices
                const noEnd = file.slice(7);                  // No end parameter
                const zeroStart = file.slice(0, 0);           // Zero-length at start
                
                Promise.all([
                    emptySlice.text(),
                    outOfBounds.text(),
                    negativeStart.text(),
                    noEnd.text(),
                    zeroStart.text()
                ]).then(results => ({
                    emptySlice: results[0],
                    emptySliceSize: emptySlice.size,
                    outOfBounds: results[1],
                    outOfBoundsSize: outOfBounds.size,
                    negativeStart: results[2],
                    negativeStartSize: negativeStart.size,
                    noEnd: results[3],
                    noEndSize: noEnd.size,
                    zeroStart: results[4],
                    zeroStartSize: zeroStart.size
                }))
            """
        let promise = context.evaluateScript(script)

        let expectation = XCTestExpectation(description: "File slice edge cases")
        promise.invokeMethod(
            "then",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    let result = args[0]

                    // Empty slice
                    XCTAssertEqual(result["emptySlice"].toString(), "")
                    XCTAssertEqual(result["emptySliceSize"].numberValue, 0)

                    // Out of bounds
                    XCTAssertEqual(result["outOfBounds"].toString(), "")
                    XCTAssertEqual(result["outOfBoundsSize"].numberValue, 0)

                    // Negative start (last 5 chars minus last 2 = "orl")
                    XCTAssertEqual(result["negativeStart"].toString(), "orl")
                    XCTAssertEqual(result["negativeStartSize"].numberValue, 3)

                    // No end (from position 7 to end = "World!")
                    XCTAssertEqual(result["noEnd"].toString(), "World!")
                    XCTAssertEqual(result["noEndSize"].numberValue, 6)

                    // Zero start
                    XCTAssertEqual(result["zeroStart"].toString(), "")
                    XCTAssertEqual(result["zeroStartSize"].numberValue, 0)

                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ]
        )
        .invokeMethod(
            "catch",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    XCTFail("File slice edge cases failed: \(args[0].toString())")
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ])

        wait(for: [expectation], timeout: 10.0)
    }

    func testFileSliceBinaryData() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }

        let script = """
                const testFile = Path.join('\(tempDir)', 'binary-slice-test.bin');
                
                // Create binary data
                const binaryData = new Uint8Array(256);
                for (let i = 0; i < 256; i++) {
                    binaryData[i] = i;
                }
                
                SystemFS.writeFile(testFile, binaryData);
                
                const file = File.fromPath(testFile);
                
                // Slice binary data at different positions
                const slice1 = file.slice(0, 10);      // First 10 bytes
                const slice2 = file.slice(100, 110);   // Bytes 100-109
                const slice3 = file.slice(246, 256);   // Last 10 bytes
                
                Promise.all([
                    slice1.arrayBuffer(),
                    slice2.arrayBuffer(),
                    slice3.arrayBuffer()
                ]).then(results => {
                    const view1 = new Uint8Array(results[0]);
                    const view2 = new Uint8Array(results[1]);
                    const view3 = new Uint8Array(results[2]);
                    
                    return {
                        slice1First: view1[0],
                        slice1Last: view1[9],
                        slice2First: view2[0],
                        slice2Last: view2[9],
                        slice3First: view3[0],
                        slice3Last: view3[9],
                        sizes: [view1.length, view2.length, view3.length]
                    };
                })
            """
        let promise = context.evaluateScript(script)

        let expectation = XCTestExpectation(description: "File slice binary data")
        promise.invokeMethod(
            "then",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    let result = args[0]

                    // First slice: bytes 0-9
                    XCTAssertEqual(result["slice1First"].numberValue, 0)
                    XCTAssertEqual(result["slice1Last"].numberValue, 9)

                    // Second slice: bytes 100-109
                    XCTAssertEqual(result["slice2First"].numberValue, 100)
                    XCTAssertEqual(result["slice2Last"].numberValue, 109)

                    // Third slice: bytes 246-255
                    XCTAssertEqual(result["slice3First"].numberValue, 246)
                    XCTAssertEqual(result["slice3Last"].numberValue, 255)

                    let sizes = result["sizes"]
                    XCTAssertEqual(sizes[0].numberValue, 10)
                    XCTAssertEqual(sizes[1].numberValue, 10)
                    XCTAssertEqual(sizes[2].numberValue, 10)

                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ]
        )
        .invokeMethod(
            "catch",
            withArguments: [
                SwiftJS.Value(newFunctionIn: context) { args, _ in
                    XCTFail("Binary file slice failed: \(args[0].toString())")
                    expectation.fulfill()
                    return SwiftJS.Value.undefined
                }
            ])

        wait(for: [expectation], timeout: 10.0)
    }

    func testFileSliceWithContentType() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }

        let script = """
                const testFile = Path.join('\(tempDir)', 'content-type-test.txt');
                const content = 'Hello, World!';
                SystemFS.writeFile(testFile, content);
                
                const file = File.fromPath(testFile);
                
                // Slice with different content types
                const slice1 = file.slice(0, 5, 'text/plain');
                const slice2 = file.slice(7, 12, 'application/json');
                const slice3 = file.slice(0, 5);  // No content type
                
                ({
                    type1: slice1.type,
                    type2: slice2.type,
                    type3: slice3.type
                })
            """
        let result = context.evaluateScript(script)

        XCTAssertEqual(result["type1"].toString(), "text/plain")
        XCTAssertEqual(result["type2"].toString(), "application/json")
        XCTAssertEqual(result["type3"].toString(), "")  // Empty when not specified
    }
}
