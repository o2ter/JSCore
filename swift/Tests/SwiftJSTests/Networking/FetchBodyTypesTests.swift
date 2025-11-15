//
//  FetchBodyTypesTests.swift
//  SwiftJS Fetch Body Types Tests
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

/// Tests for various fetch request body types including string, ArrayBuffer, Blob, 
/// DataView, File, FormData, TypedArray, URLSearchParams, and ReadableStream.
@MainActor
final class FetchBodyTypesTests: XCTestCase {
    
    // MARK: - String Body Tests
    
    func testFetchStringBody() {
        let expectation = XCTestExpectation(description: "Fetch with string body")
        
        let script = """
            const testData = 'Hello, World! This is a string body test.';
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: testData,
                headers: { 'Content-Type': 'text/plain' }
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    receivedData: data.data,
                    matches: data.data === testData,
                    contentType: data.headers['content-type'] || data.headers['Content-Type']
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["matches"].boolValue ?? false, "String body should match")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - ArrayBuffer Body Tests
    
    func testFetchArrayBufferBody() {
        let expectation = XCTestExpectation(description: "Fetch with ArrayBuffer body")
        
        let script = """
            const testString = 'ArrayBuffer test data 🚀';
            const encoder = new TextEncoder();
            const arrayBuffer = encoder.encode(testString).buffer;
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: arrayBuffer,
                headers: { 'Content-Type': 'application/octet-stream' }
            })
            .then(response => response.json())
            .then(data => {
                // postman-echo returns the body as base64 or raw data
                testCompleted({
                    success: true,
                    hasData: !!data.data,
                    bodyType: typeof data.data,
                    originalSize: arrayBuffer.byteLength
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasData"].boolValue ?? false, "Should have received data")
            XCTAssertGreaterThan(
                Int(result["originalSize"].numberValue ?? 0), 0, "ArrayBuffer should have size")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Blob Body Tests
    
    func testFetchBlobBody() {
        let expectation = XCTestExpectation(description: "Fetch with Blob body")
        
        let script = """
            const testContent = 'This is blob content for testing! 📄';
            const blob = new Blob([testContent], { type: 'text/plain' });
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: blob,
                // Content-Type should be set automatically from blob.type
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    receivedData: data.data,
                    blobSize: blob.size,
                    blobType: blob.type,
                    hasContentTypeHeader: !!(data.headers['content-type'] || data.headers['Content-Type'])
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertGreaterThan(
                Int(result["blobSize"].numberValue ?? 0), 0, "Blob should have size")
            XCTAssertEqual(
                result["blobType"].toString(), "text/plain", "Blob type should be preserved")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - TypedArray Body Tests
    
    func testFetchUint8ArrayBody() {
        let expectation = XCTestExpectation(description: "Fetch with Uint8Array body")
        
        let script = """
            const testData = new Uint8Array([72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100]); // "Hello World"
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: testData,
                headers: { 'Content-Type': 'application/octet-stream' }
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    hasData: !!data.data,
                    arrayLength: testData.length,
                    arrayByteLength: testData.byteLength
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasData"].boolValue ?? false, "Should have received data")
            XCTAssertEqual(
                Int(result["arrayLength"].numberValue ?? 0), 11, "Array should have 11 elements")
            XCTAssertEqual(
                Int(result["arrayByteLength"].numberValue ?? 0), 11, "Array should have 11 bytes")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchDataViewBody() {
        let expectation = XCTestExpectation(description: "Fetch with DataView body")
        
        let script = """
            const buffer = new ArrayBuffer(16);
            const dataView = new DataView(buffer);
            
            // Fill with some test data
            dataView.setUint32(0, 0x12345678, false); // big endian
            dataView.setUint32(4, 0x9ABCDEF0, false);
            dataView.setFloat32(8, 3.14159, false);
            dataView.setUint32(12, 0xDEADBEEF, false);
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: dataView,
                headers: { 'Content-Type': 'application/octet-stream' }
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    hasData: !!data.data,
                    dataViewByteLength: dataView.byteLength,
                    bufferByteLength: buffer.byteLength
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasData"].boolValue ?? false, "Should have received data")
            XCTAssertEqual(
                Int(result["dataViewByteLength"].numberValue ?? 0), 16,
                "DataView should have 16 bytes")
            XCTAssertEqual(
                Int(result["bufferByteLength"].numberValue ?? 0), 16, "Buffer should have 16 bytes")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - URLSearchParams Body Tests
    
    func testFetchURLSearchParamsBody() {
        let expectation = XCTestExpectation(description: "Fetch with URLSearchParams body")
        
        let script = """
            const params = new URLSearchParams();
            params.append('name', 'John Doe');
            params.append('age', '30');
            params.append('city', 'New York');
            params.append('interests', 'programming');
            params.append('interests', 'music');
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: params
                // Content-Type should be set automatically to application/x-www-form-urlencoded
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    receivedData: data.data,
                    formData: data.form,
                    paramsString: params.toString(),
                    contentType: data.headers['content-type'] || data.headers['Content-Type']
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(
                result["paramsString"].toString().contains("name=John"), "Should contain form data")
            XCTAssertTrue(
                result["paramsString"].toString().contains("age=30"), "Should contain age parameter")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - FormData Body Tests
    
    func testFetchFormDataBody() {
        let expectation = XCTestExpectation(description: "Fetch with FormData body")
        
        let script = """
            const formData = new FormData();
            formData.append('username', 'testuser');
            formData.append('email', 'test@example.com');
            formData.append('description', 'Testing FormData with fetch');
            
            // Add a blob as a file
            const blob = new Blob(['This is file content'], { type: 'text/plain' });
            formData.append('file', blob, 'test.txt');
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: formData
                // Content-Type will be set automatically with boundary
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    hasForm: !!data.form,
                    hasFiles: !!data.files,
                    formKeys: data.form ? Object.keys(data.form) : [],
                    fileKeys: data.files ? Object.keys(data.files) : [],
                    contentType: data.headers['content-type'] || data.headers['Content-Type']
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasForm"].boolValue ?? false, "Should have form data")
            let contentType = result["contentType"].toString()
            XCTAssertTrue(
                contentType.contains("multipart/form-data"), "Should use multipart content type")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - File Body Tests
    
    func testFetchFileBody() {
        let expectation = XCTestExpectation(description: "Fetch with File body")
        
        let script = """
            const fileContent = 'This is a test file content for fetch testing! 📁\\n'.repeat(10);
            const file = new File([fileContent], 'test-file.txt', { 
                type: 'text/plain',
                lastModified: Date.now()
            });
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: file
                // Content-Type should be set from file.type
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    fileName: file.name,
                    fileSize: file.size,
                    fileType: file.type,
                    hasData: !!data.data,
                    contentType: data.headers['content-type'] || data.headers['Content-Type']
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertEqual(
                result["fileName"].toString(), "test-file.txt", "File name should be preserved")
            XCTAssertEqual(
                result["fileType"].toString(), "text/plain", "File type should be preserved")
            XCTAssertGreaterThan(
                Int(result["fileSize"].numberValue ?? 0), 0, "File should have size")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - ReadableStream Body Tests
    
    func testFetchReadableStreamBody() {
        let expectation = XCTestExpectation(description: "Fetch with ReadableStream body")
        
        let script = """
            const testData = 'Streaming data chunk 1\\nStreaming data chunk 2\\nStreaming data chunk 3\\n';
            
            const stream = new ReadableStream({
                start(controller) {
                    const encoder = new TextEncoder();
                    const chunks = testData.split('\\n').filter(chunk => chunk.length > 0);
                    
                    let index = 0;
                    function enqueueNext() {
                        if (index < chunks.length) {
                            controller.enqueue(encoder.encode(chunks[index] + '\\n'));
                            index++;
                            setTimeout(enqueueNext, 10); // Simulate async streaming
                        } else {
                            controller.close();
                        }
                    }
                    enqueueNext();
                }
            });
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: stream,
                headers: { 'Content-Type': 'application/octet-stream' }
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    hasData: !!data.data,
                    originalDataLength: testData.length
                });
            })
            .catch(error => {
                testCompleted({ success: false, error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(
                result["success"].boolValue == true,
                "Network request should succeed: \(result["error"].toString())")
            XCTAssertTrue(
                result["hasData"].boolValue ?? false, "Should have received streamed data")
            XCTAssertGreaterThan(
                Int(result["originalDataLength"].numberValue ?? 0), 0,
                "Original data should have length")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Multiple Body Types Test
    
    func testMultipleBodyTypesComparison() {
        let expectation = XCTestExpectation(description: "Compare multiple body types")
        
        let script = """
            const testContent = 'Hello, Body Types!';
            const results = [];
            
            // Test different representations of the same data
            const bodyTypes = [
                { name: 'string', body: testContent },
                { name: 'uint8array', body: new TextEncoder().encode(testContent) },
                { name: 'arraybuffer', body: new TextEncoder().encode(testContent).buffer },
                { name: 'blob', body: new Blob([testContent], { type: 'text/plain' }) }
            ];
            
            let completed = 0;
            
            bodyTypes.forEach((testCase, index) => {
                fetch('https://postman-echo.com/post', {
                    method: 'POST',
                    body: testCase.body,
                    headers: { 'X-Test-Type': testCase.name }
                })
                .then(response => response.json())
                .then(data => {
                    results[index] = {
                        type: testCase.name,
                        success: true,
                        hasData: !!data.data
                    };
                    completed++;
                    if (completed === bodyTypes.length) {
                        testCompleted({ results: results, allSucceeded: results.every(r => r.success) });
                    }
                })
                .catch(error => {
                    results[index] = {
                        type: testCase.name,
                        success: false,
                        error: error.message
                    };
                    completed++;
                    if (completed === bodyTypes.length) {
                        testCompleted({ results: results, allSucceeded: results.every(r => r.success) });
                    }
                });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            let resultCount = Int(results["length"].numberValue ?? 0)
            
            XCTAssertGreaterThanOrEqual(resultCount, 4, "Should test 4 body types")
            
            // All body types must work
            var successCount = 0
            for i in 0..<resultCount {
                let testResult = results[i]
                if testResult["success"].boolValue == true {
                    successCount += 1
                }
                XCTAssertTrue(
                    testResult["success"].boolValue ?? false,
                    "\(testResult["type"].toString()) request should succeed: \(testResult["error"].toString())")
                XCTAssertTrue(
                    testResult["hasData"].boolValue ?? false,
                    "\(testResult["type"].toString()) should have data")
            }
            
            XCTAssertEqual(successCount, resultCount, "All body types should work")
            XCTAssertGreaterThan(successCount, 0, "Should have tested at least one body type")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Body Type Validation Tests
    
    func testInvalidBodyTypes() {
        let script = """
            const testCases = [];
            
            // Test that unsupported body types are handled gracefully
            try {
                const request = new Request('https://example.com', {
                    method: 'POST',
                    body: { object: 'literal' } // Plain object - should be converted to string
                });
                testCases.push({ type: 'object-literal', success: true });
            } catch (e) {
                testCases.push({ type: 'object-literal', success: false, error: e.message });
            }
            
            try {
                const request = new Request('https://example.com', {
                    method: 'POST',
                    body: 12345 // Number - should be converted to string
                });
                testCases.push({ type: 'number', success: true });
            } catch (e) {
                testCases.push({ type: 'number', success: false, error: e.message });
            }
            
            try {
                const request = new Request('https://example.com', {
                    method: 'POST',
                    body: true // Boolean - should be converted to string
                });
                testCases.push({ type: 'boolean', success: true });
            } catch (e) {
                testCases.push({ type: 'boolean', success: false, error: e.message });
            }
            
            testCases
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        let testCount = Int(result["length"].numberValue ?? 0)
        
        XCTAssertEqual(testCount, 3, "Should test 3 edge cases")
        
        for i in 0..<testCount {
            let testCase = result[i]
            // These should all succeed because Request should convert values to strings
            XCTAssertTrue(testCase["success"].boolValue ?? false, 
                        "Body type '\(testCase["type"].toString())' should be handled gracefully")
        }
    }
}
