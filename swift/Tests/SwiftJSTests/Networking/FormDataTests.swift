//
//  FormDataTests.swift
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

@MainActor
final class FormDataTests: XCTestCase {
    
    // Each test creates its own SwiftJS context to avoid shared state
    
    // MARK: - FormData API Existence Tests
    
    func testFormDataExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof FormData")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testFormDataInstantiation() {
        let script = """
            const formData = new FormData();
            formData instanceof FormData
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Basic Functionality Tests
    
    func testFormDataAppend() {
        let script = """
            const formData = new FormData();
            formData.append('key', 'value');
            formData.has('key')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataGet() {
        let script = """
            const formData = new FormData();
            formData.append('test', 'hello');
            formData.get('test')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "hello")
    }
    
    func testFormDataSet() {
        let script = """
            const formData = new FormData();
            formData.set('key', 'value1');
            formData.set('key', 'value2');
            formData.get('key')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "value2")
    }
    
    func testFormDataDelete() {
        let script = """
            const formData = new FormData();
            formData.append('key', 'value');
            formData.delete('key');
            formData.has('key')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertFalse(result.boolValue ?? true)
    }
    
    func testFormDataHas() {
        let script = """
            const formData = new FormData();
            const before = formData.has('nonexistent');
            formData.append('existing', 'value');
            const after = formData.has('existing');
            !before && after
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Multiple Values Tests
    
    func testFormDataMultipleValues() {
        let script = """
            const formData = new FormData();
            formData.append('key', 'value1');
            formData.append('key', 'value2');
            const values = formData.getAll('key');
            values.length === 2 && values[0] === 'value1' && values[1] === 'value2'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataGetAll() {
        let script = """
            const formData = new FormData();
            formData.append('multi', 'a');
            formData.append('multi', 'b');
            formData.append('multi', 'c');
            const all = formData.getAll('multi');
            Array.isArray(all) && all.length === 3
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataSetOverwritesMultiple() {
        let script = """
            const formData = new FormData();
            formData.append('key', 'value1');
            formData.append('key', 'value2');
            formData.set('key', 'single');
            const all = formData.getAll('key');
            all.length === 1 && all[0] === 'single'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Iteration Tests
    
    func testFormDataKeys() {
        let script = """
            const formData = new FormData();
            formData.append('a', '1');
            formData.append('b', '2');
            const keys = Array.from(formData.keys());
            keys.includes('a') && keys.includes('b')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataValues() {
        let script = """
            const formData = new FormData();
            formData.append('key1', 'value1');
            formData.append('key2', 'value2');
            const values = Array.from(formData.values());
            values.includes('value1') && values.includes('value2')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataEntries() {
        let script = """
            const formData = new FormData();
            formData.append('name', 'value');
            const entries = Array.from(formData.entries());
            entries.length === 1 && entries[0][0] === 'name' && entries[0][1] === 'value'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataForEach() {
        let script = """
            const formData = new FormData();
            formData.append('a', '1');
            formData.append('b', '2');
            let count = 0;
            formData.forEach(() => count++);
            count === 2
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData File Tests
    
    func testFormDataAppendFile() {
        let script = """
            const formData = new FormData();
            const file = new File(['content'], 'test.txt', { type: 'text/plain' });
            formData.append('file', file);
            formData.has('file')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false, "FormData should support File API")
    }
    
    // MARK: - FormData Integration with Request Tests
    
    func testFormDataWithRequest() {
        let script = """
            try {
                const formData = new FormData();
                formData.append('name', 'test');
                formData.append('value', '123');
                
                const request = new Request('https://postman-echo.com/post', {
                    method: 'POST',
                    body: formData
                });
                
                request.method === 'POST' && request.body !== null
            } catch (e) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataWithFetch() {
        let script = """
            try {
                const formData = new FormData();
                formData.append('test', 'data');
                
                // Just test that fetch accepts FormData as body without throwing
                const fetchCall = fetch('https://postman-echo.com/post', {
                    method: 'POST',
                    body: formData
                });
                
                typeof fetchCall === 'object' && typeof fetchCall.then === 'function'
            } catch (e) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Edge Cases Tests
    
    func testFormDataEmptyKey() {
        let script = """
            const formData = new FormData();
            formData.append('', 'empty-key-value');
            formData.has('') && formData.get('') === 'empty-key-value'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataEmptyValue() {
        let script = """
            const formData = new FormData();
            formData.append('empty-value', '');
            formData.has('empty-value') && formData.get('empty-value') === ''
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataNullValue() {
        let script = """
            const formData = new FormData();
            formData.append('null-value', null);
            formData.get('null-value') === 'null'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataUndefinedValue() {
        let script = """
            const formData = new FormData();
            formData.append('undefined-value', undefined);
            formData.get('undefined-value') === 'undefined'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Type Coercion Tests
    
    func testFormDataNumberValue() {
        let script = """
            const formData = new FormData();
            formData.append('number', 42);
            formData.get('number') === '42'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testFormDataBooleanValue() {
        let script = """
            const formData = new FormData();
            formData.append('bool-true', true);
            formData.append('bool-false', false);
            formData.get('bool-true') === 'true' && formData.get('bool-false') === 'false'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - FormData Performance Tests
    
    func testFormDataLargeDataset() {
        let script = """
            const formData = new FormData();
            for (let i = 0; i < 1000; i++) {
                formData.append(`key${i}`, `value${i}`);
            }
            Array.from(formData.keys()).length === 1000
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - File Streaming Tests

    func testFileStreamingWithFetch() {
        let expectation = XCTestExpectation(description: "File streaming test")

        let script = """
                async function testFileStreaming() {
                    try {
                        // Create a temporary file using SystemFS.temp
                        const tempDir = SystemFS.temp;
                        const filePath = Path.join(tempDir, 'streaming-test.txt');
                        
                        // Create test content
                        const testContent = 'Hello, Streaming World! 🚀\\n'.repeat(1000);
                        SystemFS.writeFile(filePath, testContent);
                        
                        // Create File from path
                        const file = File.fromPath(filePath);
                        
                        // Create FormData with the file
                        const formData = new FormData();
                        formData.append('file', file);
                        formData.append('description', 'Streaming test file');
                        
                        // Use a simple POST endpoint to test upload
                        const response = await fetch('https://postman-echo.com/post', {
                            method: 'POST',
                            body: formData
                        });
                        
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        
                        const responseData = await response.json();
                        
                        // Cleanup
                        SystemFS.remove(filePath);
                        
                        // Verify the file was uploaded and echoed back
                        return {
                            success: true,
                            hasFiles: responseData.files && Object.keys(responseData.files).length > 0,
                            hasFormData: responseData.form && responseData.form.description === 'Streaming test file',
                            originalSize: testContent.length,
                            responseType: typeof responseData
                        };
                    } catch (error) {
                        return { success: false, error: error.message };
                    }
                }
                
                testFileStreaming().then(result => {
                    testCompleted(result);
                }).catch(error => {
                    testCompleted({ success: false, error: error.message });
                });
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["success"].boolValue ?? false, "Streaming test should succeed")
            XCTAssertTrue(
                result["hasFiles"].boolValue ?? false, "Response should contain uploaded files")
            XCTAssertTrue(
                result["hasFormData"].boolValue ?? false, "Response should contain form data")
            XCTAssertGreaterThan(
                result["originalSize"].numberValue ?? 0, 1000,
                "File should have substantial content")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 60.0)
    }

    func testFileStreamingWithXMLHttpRequest() {
        let expectation = XCTestExpectation(description: "XHR file streaming test")

        let script = """
                function testXHRFileStreaming() {
                    // Create a temporary file using SystemFS.temp
                    const tempDir = SystemFS.temp;
                    const filePath = Path.join(tempDir, 'xhr-streaming-test.txt');
                    
                    // Create test content
                    const testContent = 'XHR Streaming Test Data! 📡\\n'.repeat(500);
                    SystemFS.writeFile(filePath, testContent);
                    
                    // Create File from path
                    const file = File.fromPath(filePath);
                    
                    // Create FormData with the file
                    const formData = new FormData();
                    formData.append('testfile', file);
                    formData.append('metadata', JSON.stringify({ 
                        test: 'xhr-streaming',
                        timestamp: Date.now() 
                    }));
                    
                    // Create XMLHttpRequest
                    const xhr = new XMLHttpRequest();
                    
                    xhr.onreadystatechange = function() {
                        if (xhr.readyState === 4) {
                            try {
                                // Cleanup
                                SystemFS.remove(filePath);
                                
                                if (xhr.status === 200) {
                                    const responseData = JSON.parse(xhr.responseText);
                                    testCompleted({
                                        success: true,
                                        hasFiles: responseData.files && Object.keys(responseData.files).length > 0,
                                        hasFormData: responseData.form && responseData.form.metadata,
                                        status: xhr.status,
                                        originalSize: testContent.length
                                    });
                                } else {
                                    testCompleted({ 
                                        success: false, 
                                        error: `HTTP ${xhr.status}: ${xhr.statusText}` 
                                    });
                                }
                            } catch (error) {
                                testCompleted({ success: false, error: error.message });
                            }
                        }
                    };
                    
                    xhr.onerror = function() {
                        // Cleanup on error
                        try {
                            SystemFS.remove(filePath);
                        } catch (e) {}
                        testCompleted({ success: false, error: 'Network error' });
                    };
                    
                    xhr.open('POST', 'https://postman-echo.com/post');
                    xhr.send(formData);
                }
                
                testXHRFileStreaming();
            """

        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["success"].boolValue ?? false, "XHR streaming test should succeed")
            XCTAssertTrue(
                result["hasFiles"].boolValue ?? false, "Response should contain uploaded files")
            XCTAssertTrue(
                result["hasFormData"].boolValue ?? false, "Response should contain form data")
            XCTAssertEqual(
                result["status"].numberValue ?? 0, 200, "Should get HTTP 200 response")
            XCTAssertGreaterThan(
                result["originalSize"].numberValue ?? 0, 500, "File should have substantial content"
            )
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }

        context.evaluateScript(script)
        wait(for: [expectation], timeout: 60.0)
    }
}
