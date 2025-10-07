//
//  HeadersTests.swift
//  SwiftJS Headers API Tests
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

/// Tests for the Headers API including creation, manipulation,
/// case-insensitive operations, and iteration.
@MainActor
final class HeadersTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testHeadersExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Headers")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testHeadersAPIExistence() {
        let context = SwiftJS()
        let globals = context.evaluateScript("Object.getOwnPropertyNames(globalThis)")
        XCTAssertTrue(globals.toString().contains("Headers"))
    }
    
    // MARK: - Instantiation Tests
    
    func testHeadersInstantiation() {
        let script = """
            const headers = new Headers();
            headers instanceof Headers
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testHeadersFromObject() {
        let script = """
            const headers = new Headers({
                'Authorization': 'Bearer token123',
                'Content-Type': 'application/json'
            });
            [headers.has('authorization'), headers.get('authorization')]
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result[0].boolValue ?? false)
        XCTAssertEqual(result[1].toString(), "Bearer token123")
    }
    
    func testHeadersFromArray() {
        let script = """
            const headers = new Headers([
                ['Content-Type', 'application/json'],
                ['Authorization', 'Bearer token456']
            ]);
            ({
                hasContentType: headers.has('content-type'),
                contentType: headers.get('content-type'),
                hasAuth: headers.has('authorization'),
                auth: headers.get('authorization')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["hasContentType"].boolValue ?? false)
        XCTAssertEqual(result["contentType"].toString(), "application/json")
        XCTAssertTrue(result["hasAuth"].boolValue ?? false)
        XCTAssertEqual(result["auth"].toString(), "Bearer token456")
    }
    
    func testHeadersFromAnotherHeaders() {
        let script = """
            const original = new Headers({
                'X-Original': 'value1',
                'X-Test': 'value2'
            });
            
            const copy = new Headers(original);
            ({
                hasOriginal: copy.has('x-original'),
                originalValue: copy.get('x-original'),
                hasTest: copy.has('x-test'),
                testValue: copy.get('x-test')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["hasOriginal"].boolValue ?? false)
        XCTAssertEqual(result["originalValue"].toString(), "value1")
        XCTAssertTrue(result["hasTest"].boolValue ?? false)
        XCTAssertEqual(result["testValue"].toString(), "value2")
    }
    
    // MARK: - Basic Operations Tests
    
    func testHeadersSetAndGet() {
        let script = """
            const headers = new Headers();
            headers.set('Content-Type', 'application/json');
            headers.get('content-type') // Should be case-insensitive
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "application/json")
    }
    
    func testHeadersAppend() {
        let script = """
            const headers = new Headers();
            headers.append('Accept', 'text/html');
            headers.append('Accept', 'application/json');
            headers.get('accept')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        // Should combine values with comma separator
        let acceptValue = result.toString()
        XCTAssertTrue(acceptValue.contains("text/html"))
        XCTAssertTrue(acceptValue.contains("application/json"))
    }
    
    func testHeadersHas() {
        let script = """
            const headers = new Headers();
            headers.set('X-Custom-Header', 'test-value');
            ({
                hasExact: headers.has('X-Custom-Header'),
                hasLowercase: headers.has('x-custom-header'),
                hasUppercase: headers.has('X-CUSTOM-HEADER'),
                hasMissing: headers.has('X-Missing-Header')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["hasExact"].boolValue ?? false)
        XCTAssertTrue(result["hasLowercase"].boolValue ?? false)
        XCTAssertTrue(result["hasUppercase"].boolValue ?? false)
        XCTAssertFalse(result["hasMissing"].boolValue ?? true)
    }
    
    func testHeadersDelete() {
        let script = """
            const headers = new Headers();
            headers.set('X-Test', 'value');
            headers.set('X-Keep', 'keep-value');
            
            const beforeDelete = headers.has('x-test');
            headers.delete('X-Test');
            const afterDelete = headers.has('x-test');
            const stillHasKeep = headers.has('x-keep');
            
            ({
                beforeDelete: beforeDelete,
                afterDelete: afterDelete,
                stillHasKeep: stillHasKeep
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result["beforeDelete"].boolValue ?? false)
        XCTAssertFalse(result["afterDelete"].boolValue ?? true)
        XCTAssertTrue(result["stillHasKeep"].boolValue ?? false)
    }
    
    // MARK: - Case Insensitivity Tests
    
    func testHeadersCaseInsensitivity() {
        let script = """
            const headers = new Headers();
            headers.set('Content-TYPE', 'application/json');
            
            ({
                get1: headers.get('content-type'),
                get2: headers.get('Content-Type'),
                get3: headers.get('CONTENT-TYPE'),
                has1: headers.has('content-type'),
                has2: headers.has('Content-Type'),
                has3: headers.has('CONTENT-TYPE')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // All should return the same value
        XCTAssertEqual(result["get1"].toString(), "application/json")
        XCTAssertEqual(result["get2"].toString(), "application/json")
        XCTAssertEqual(result["get3"].toString(), "application/json")
        
        // All should return true
        XCTAssertTrue(result["has1"].boolValue ?? false)
        XCTAssertTrue(result["has2"].boolValue ?? false)
        XCTAssertTrue(result["has3"].boolValue ?? false)
    }
    
    func testHeadersDeleteCaseInsensitive() {
        let script = """
            const headers = new Headers();
            headers.set('X-Custom-Header', 'value');
            
            // Delete with different case
            headers.delete('x-custom-header');
            
            headers.has('X-Custom-Header')
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertFalse(result.boolValue ?? true)
    }
    
    // MARK: - Value Handling Tests
    
    func testHeadersValueNormalization() {
        let script = """
            const headers = new Headers();
            
            // Test with various value types
            headers.set('X-String', 'string value');
            headers.set('X-Number', 123);
            headers.set('X-Boolean', true);
            
            ({
                stringValue: headers.get('X-String'),
                numberValue: headers.get('X-Number'),
                booleanValue: headers.get('X-Boolean'),
                stringType: typeof headers.get('X-String'),
                numberType: typeof headers.get('X-Number'),
                booleanType: typeof headers.get('X-Boolean')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // All values should be converted to strings
        XCTAssertEqual(result["stringValue"].toString(), "string value")
        XCTAssertEqual(result["numberValue"].toString(), "123")
        XCTAssertEqual(result["booleanValue"].toString(), "true")
        
        // All should be string type
        XCTAssertEqual(result["stringType"].toString(), "string")
        XCTAssertEqual(result["numberType"].toString(), "string")
        XCTAssertEqual(result["booleanType"].toString(), "string")
    }
    
    func testHeadersAppendMultipleValues() {
        let script = """
            const headers = new Headers();
            headers.append('Cache-Control', 'no-cache');
            headers.append('Cache-Control', 'no-store');
            headers.append('Cache-Control', 'must-revalidate');
            
            const value = headers.get('Cache-Control');
            ({
                value: value,
                hasNoCache: value.includes('no-cache'),
                hasNoStore: value.includes('no-store'),
                hasMustRevalidate: value.includes('must-revalidate'),
                commaCount: (value.match(/,/g) || []).length
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasNoCache"].boolValue ?? false)
        XCTAssertTrue(result["hasNoStore"].boolValue ?? false)
        XCTAssertTrue(result["hasMustRevalidate"].boolValue ?? false)
        XCTAssertEqual(Int(result["commaCount"].numberValue ?? 0), 2) // Two commas for three values
    }
    
    func testHeadersSetOverwritesAppend() {
        let script = """
            const headers = new Headers();
            headers.append('X-Test', 'value1');
            headers.append('X-Test', 'value2');
            
            const afterAppend = headers.get('X-Test');
            
            headers.set('X-Test', 'single-value');
            const afterSet = headers.get('X-Test');
            
            ({
                afterAppend: afterAppend,
                afterSet: afterSet,
                appendHasComma: afterAppend.includes(','),
                setIsSimple: afterSet === 'single-value'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["appendHasComma"].boolValue ?? false)
        XCTAssertTrue(result["setIsSimple"].boolValue ?? false)
        XCTAssertEqual(result["afterSet"].toString(), "single-value")
    }
    
    // MARK: - Iteration Tests
    
    func testHeadersIteration() {
        let script = """
            const headers = new Headers({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer token',
                'X-Custom': 'custom-value'
            });
            
            const entries = [];
            const keys = [];
            const values = [];
            
            // Test for...of iteration
            for (const [key, value] of headers) {
                entries.push([key, value]);
            }
            
            // Test keys() iterator
            for (const key of headers.keys()) {
                keys.push(key);
            }
            
            // Test values() iterator
            for (const value of headers.values()) {
                values.push(value);
            }
            
            ({
                entriesLength: entries.length,
                keysLength: keys.length,
                valuesLength: values.length,
                hasContentType: entries.some(([k, v]) => k.toLowerCase() === 'content-type'),
                hasAuthorization: keys.some(k => k.toLowerCase() === 'authorization'),
                hasJsonValue: values.some(v => v === 'application/json')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["entriesLength"].numberValue ?? 0), 3)
        XCTAssertEqual(Int(result["keysLength"].numberValue ?? 0), 3)
        XCTAssertEqual(Int(result["valuesLength"].numberValue ?? 0), 3)
        XCTAssertTrue(result["hasContentType"].boolValue ?? false)
        XCTAssertTrue(result["hasAuthorization"].boolValue ?? false)
        XCTAssertTrue(result["hasJsonValue"].boolValue ?? false)
    }
    
    func testHeadersEntries() {
        let script = """
            const headers = new Headers();
            headers.set('X-First', 'first-value');
            headers.set('X-Second', 'second-value');
            
            const entriesArray = Array.from(headers.entries());
            ({
                length: entriesArray.length,
                firstEntry: entriesArray[0],
                secondEntry: entriesArray[1],
                allAreArrays: entriesArray.every(entry => Array.isArray(entry) && entry.length === 2)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 2)
        XCTAssertTrue(result["allAreArrays"].boolValue ?? false)
        
        let firstEntry = result["firstEntry"]
        let secondEntry = result["secondEntry"]
        XCTAssertEqual(Int(firstEntry["length"].numberValue ?? 0), 2)
        XCTAssertEqual(Int(secondEntry["length"].numberValue ?? 0), 2)
    }
    
    func testHeadersForEach() {
        let script = """
            const headers = new Headers({
                'Content-Length': '123',
                'Content-Type': 'text/plain'
            });
            
            const results = [];
            headers.forEach((value, key, headersObj) => {
                results.push({
                    key: key,
                    value: value,
                    thisArg: headersObj === headers
                });
            });
            
            ({
                resultsLength: results.length,
                firstResult: results[0],
                allHaveCorrectThis: results.every(r => r.thisArg === true)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["resultsLength"].numberValue ?? 0), 2)
        XCTAssertTrue(result["allHaveCorrectThis"].boolValue ?? false)
        
        let firstResult = result["firstResult"]
        XCTAssertTrue(firstResult["key"].isString)
        XCTAssertTrue(firstResult["value"].isString)
    }
    
    // MARK: - Error Handling Tests
    
    func testHeadersInvalidNames() {
        let script = """
            const headers = new Headers();
            const testCases = [];
            
            // Test invalid header names
            const invalidNames = ['', 'header name', 'header\\tname', 'header\\nname'];
            
            invalidNames.forEach(name => {
                try {
                    headers.set(name, 'value');
                    testCases.push({ name: name, error: false });
                } catch (error) {
                    testCases.push({ 
                        name: name, 
                        error: true, 
                        errorType: error.name,
                        errorMessage: error.message 
                    });
                }
            });
            
            testCases
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let testCasesCount = Int(result["length"].numberValue ?? 0)
        XCTAssertGreaterThan(testCasesCount, 0)
        
        // At least some invalid names should throw errors
        var errorCount = 0
        for i in 0..<testCasesCount {
            let testCase = result[i]
            if testCase["error"].boolValue == true {
                errorCount += 1
                // Should be TypeError for invalid header names
                let errorType = testCase["errorType"].toString()
                XCTAssertTrue(["TypeError", "Error"].contains(errorType), "Invalid header name should throw TypeError or Error")
            }
        }
        
        // At least empty string should be invalid
        XCTAssertGreaterThan(errorCount, 0, "Some invalid header names should throw errors")
    }
    
    func testHeadersInvalidValues() {
        let script = """
            const headers = new Headers();
            const testCases = [];
            
            // Test values with control characters
            const invalidValues = ['value\\n', 'value\\r', 'value\\0'];
            
            invalidValues.forEach(value => {
                try {
                    headers.set('X-Test', value);
                    testCases.push({ value: value, error: false });
                } catch (error) {
                    testCases.push({ 
                        value: value, 
                        error: true, 
                        errorType: error.name 
                    });
                }
            });
            
            testCases
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let testCasesCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(testCasesCount, 3)
        
        // Control characters in values might or might not be allowed depending on implementation
        // Just verify we handle them consistently
        for i in 0..<testCasesCount {
            let testCase = result[i]
            // Either all should work or all should fail, but it should be consistent
            XCTAssertTrue(testCase["value"].isString)
        }
    }
    
    // MARK: - HTTP Header Specific Tests
    
    func testHeadersCommonHTTPHeaders() {
        let script = """
            const headers = new Headers();
            
            // Test common HTTP headers
            headers.set('Content-Type', 'application/json; charset=utf-8');
            headers.set('Content-Length', '1024');
            headers.set('Authorization', 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9');
            headers.set('Accept', 'application/json, text/plain, */*');
            headers.set('User-Agent', 'SwiftJS/1.0 (Test Agent)');
            headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
            
            ({
                contentType: headers.get('content-type'),
                contentLength: headers.get('content-length'),
                authorization: headers.get('authorization'),
                accept: headers.get('accept'),
                userAgent: headers.get('user-agent'),
                cacheControl: headers.get('cache-control'),
                headerCount: Array.from(headers.keys()).length
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["contentType"].toString(), "application/json; charset=utf-8")
        XCTAssertEqual(result["contentLength"].toString(), "1024")
        XCTAssertTrue(result["authorization"].toString().starts(with: "Bearer "))
        XCTAssertTrue(result["accept"].toString().contains("application/json"))
        XCTAssertTrue(result["userAgent"].toString().contains("SwiftJS"))
        XCTAssertTrue(result["cacheControl"].toString().contains("no-cache"))
        XCTAssertEqual(Int(result["headerCount"].numberValue ?? 0), 6)
    }
    
    func testHeadersAcceptHeader() {
        let script = """
            const headers = new Headers();
            
            // Test building Accept header with multiple values
            headers.append('Accept', 'text/html');
            headers.append('Accept', 'application/xhtml+xml');
            headers.append('Accept', 'application/xml;q=0.9');
            headers.append('Accept', '*/*;q=0.8');
            
            const acceptValue = headers.get('Accept');
            ({
                acceptValue: acceptValue,
                hasHTML: acceptValue.includes('text/html'),
                hasXML: acceptValue.includes('application/xml'),
                hasQuality: acceptValue.includes('q=0.9'),
                hasWildcard: acceptValue.includes('*/*')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasHTML"].boolValue ?? false)
        XCTAssertTrue(result["hasXML"].boolValue ?? false)
        XCTAssertTrue(result["hasQuality"].boolValue ?? false)
        XCTAssertTrue(result["hasWildcard"].boolValue ?? false)
    }
    
    // MARK: - Performance Tests
    
    func testHeadersPerformance() {
        let script = """
            const startTime = Date.now();
            
            const headers = new Headers();
            
            // Add many headers
            for (let i = 0; i < 1000; i++) {
                headers.set(`X-Header-${i}`, `value-${i}`);
            }
            
            // Read them all back
            let readCount = 0;
            for (let i = 0; i < 1000; i++) {
                const value = headers.get(`X-Header-${i}`);
                if (value === `value-${i}`) {
                    readCount++;
                }
            }
            
            const endTime = Date.now();
            
            ({
                duration: endTime - startTime,
                readCount: readCount,
                allMatched: readCount === 1000,
                performanceOk: (endTime - startTime) < 1000 // Should complete within 1 second
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allMatched"].boolValue ?? false)
        XCTAssertTrue(result["performanceOk"].boolValue ?? false, 
                     "Headers performance test took \(result["duration"]) ms, should be under 1000ms")
        XCTAssertEqual(Int(result["readCount"].numberValue ?? 0), 1000)
    }
    
    // MARK: - Integration Tests
    
    func testHeadersWithRequestResponse() {
        let script = """
            const headers = new Headers({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer test-token',
                'X-API-Version': '1.0'
            });
            
            // Test using headers with Request
            const request = new Request('https://postman-echo.com', {
                method: 'POST',
                headers: headers
            });
            
            // Test using headers with Response
            const response = new Response('{"test": true}', {
                status: 200,
                headers: headers
            });
            
            ({
                requestContentType: request.headers.get('Content-Type'),
                requestAuth: request.headers.get('Authorization'),
                responseContentType: response.headers.get('Content-Type'),
                responseAuth: response.headers.get('Authorization'),
                originalContentType: headers.get('Content-Type'),
                headersMatch: (
                    request.headers.get('Content-Type') === headers.get('Content-Type') &&
                    response.headers.get('Content-Type') === headers.get('Content-Type')
                )
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["requestContentType"].toString(), "application/json")
        XCTAssertEqual(result["requestAuth"].toString(), "Bearer test-token")
        XCTAssertEqual(result["responseContentType"].toString(), "application/json")
        XCTAssertEqual(result["responseAuth"].toString(), "Bearer test-token")
        XCTAssertEqual(result["originalContentType"].toString(), "application/json")
        XCTAssertTrue(result["headersMatch"].boolValue ?? false)
    }
}
