//
//  URLSearchParamsTests.swift
//  SwiftJS URLSearchParams API Tests
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

/// Tests for URLSearchParams API functionality
@MainActor
final class URLSearchParamsTests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testURLSearchParamsExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof URLSearchParams")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testURLSearchParamsInstantiation() {
        let script = """
            const params = new URLSearchParams();
            params instanceof URLSearchParams
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Constructor Tests
    
    func testURLSearchParamsFromString() {
        let script = """
            const params = new URLSearchParams('name=John&age=30&city=New+York');
            ({
                name: params.get('name'),
                age: params.get('age'),
                city: params.get('city')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["name"].toString(), "John")
        XCTAssertEqual(result["age"].toString(), "30")
        XCTAssertEqual(result["city"].toString(), "New York")
    }
    
    func testURLSearchParamsFromObject() {
        let script = """
            const params = new URLSearchParams({
                username: 'testuser',
                email: 'test@example.com',
                active: 'true'
            });
            ({
                username: params.get('username'),
                email: params.get('email'),
                active: params.get('active')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["username"].toString(), "testuser")
        XCTAssertEqual(result["email"].toString(), "test@example.com")
        XCTAssertEqual(result["active"].toString(), "true")
    }
    
    func testURLSearchParamsFromArray() {
        let script = """
            const params = new URLSearchParams([
                ['key1', 'value1'],
                ['key2', 'value2'],
                ['key1', 'value3'] // Multiple values for same key
            ]);
            ({
                key1First: params.get('key1'),
                key1All: params.getAll('key1'),
                key2: params.get('key2')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["key1First"].toString(), "value1")
        XCTAssertEqual(result["key2"].toString(), "value2")
        
        let key1All = result["key1All"]
        XCTAssertEqual(Int(key1All["length"].numberValue ?? 0), 2)
        XCTAssertEqual(key1All[0].toString(), "value1")
        XCTAssertEqual(key1All[1].toString(), "value3")
    }
    
    func testURLSearchParamsFromAnother() {
        let script = """
            const original = new URLSearchParams('a=1&b=2');
            const copy = new URLSearchParams(original);
            ({
                originalA: original.get('a'),
                copyA: copy.get('a'),
                originalB: original.get('b'),
                copyB: copy.get('b'),
                areDifferentObjects: original !== copy
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["originalA"].toString(), "1")
        XCTAssertEqual(result["copyA"].toString(), "1")
        XCTAssertEqual(result["originalB"].toString(), "2")
        XCTAssertEqual(result["copyB"].toString(), "2")
        XCTAssertTrue(result["areDifferentObjects"].boolValue ?? false)
    }
    
    // MARK: - Basic Operations Tests
    
    func testAppendAndGet() {
        let script = """
            const params = new URLSearchParams();
            params.append('name', 'Alice');
            params.append('hobby', 'reading');
            params.append('hobby', 'coding');
            
            ({
                name: params.get('name'),
                firstHobby: params.get('hobby'),
                allHobbies: params.getAll('hobby'),
                hasName: params.has('name'),
                hasAge: params.has('age')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["name"].toString(), "Alice")
        XCTAssertEqual(result["firstHobby"].toString(), "reading")
        XCTAssertTrue(result["hasName"].boolValue ?? false)
        XCTAssertFalse(result["hasAge"].boolValue ?? true)
        
        let allHobbies = result["allHobbies"]
        XCTAssertEqual(Int(allHobbies["length"].numberValue ?? 0), 2)
        XCTAssertEqual(allHobbies[0].toString(), "reading")
        XCTAssertEqual(allHobbies[1].toString(), "coding")
    }
    
    func testSetAndDelete() {
        let script = """
            const params = new URLSearchParams();
            params.append('key', 'value1');
            params.append('key', 'value2');
            
            const beforeSet = params.getAll('key');
            
            params.set('key', 'single');
            const afterSet = params.getAll('key');
            
            params.delete('key');
            const afterDelete = params.has('key');
            
            ({
                beforeSetLength: beforeSet.length,
                afterSetLength: afterSet.length,
                afterSetValue: afterSet[0],
                afterDelete: afterDelete
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["beforeSetLength"].numberValue ?? 0), 2)
        XCTAssertEqual(Int(result["afterSetLength"].numberValue ?? 0), 1)
        XCTAssertEqual(result["afterSetValue"].toString(), "single")
        XCTAssertFalse(result["afterDelete"].boolValue ?? true)
    }
    
    // MARK: - Iteration Tests
    
    func testKeys() {
        let script = """
            const params = new URLSearchParams('a=1&b=2&a=3');
            const keys = Array.from(params.keys());
            keys
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let keyCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(keyCount, 3) // Should include duplicate keys
        XCTAssertEqual(result[0].toString(), "a")
        XCTAssertEqual(result[1].toString(), "b")
        XCTAssertEqual(result[2].toString(), "a")
    }
    
    func testValues() {
        let script = """
            const params = new URLSearchParams('name=John&age=30&name=Jane');
            const values = Array.from(params.values());
            values
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let valueCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(valueCount, 3)
        XCTAssertEqual(result[0].toString(), "John")
        XCTAssertEqual(result[1].toString(), "30")
        XCTAssertEqual(result[2].toString(), "Jane")
    }
    
    func testEntries() {
        let script = """
            const params = new URLSearchParams('x=1&y=2');
            const entries = Array.from(params.entries());
            entries
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let entryCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(entryCount, 2)
        
        let firstEntry = result[0]
        XCTAssertEqual(firstEntry[0].toString(), "x")
        XCTAssertEqual(firstEntry[1].toString(), "1")
        
        let secondEntry = result[1]
        XCTAssertEqual(secondEntry[0].toString(), "y")
        XCTAssertEqual(secondEntry[1].toString(), "2")
    }
    
    func testForEach() {
        let script = """
            const params = new URLSearchParams('a=1&b=2');
            const collected = [];
            
            params.forEach((value, key, params) => {
                collected.push({ key: key, value: value });
            });
            
            collected
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let collectedCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(collectedCount, 2)
        
        XCTAssertEqual(result[0]["key"].toString(), "a")
        XCTAssertEqual(result[0]["value"].toString(), "1")
        XCTAssertEqual(result[1]["key"].toString(), "b")
        XCTAssertEqual(result[1]["value"].toString(), "2")
    }
    
    func testIteratorSymbol() {
        let script = """
            const params = new URLSearchParams('foo=bar&baz=qux');
            const entries = [];
            
            for (const entry of params) {
                entries.push(entry);
            }
            
            entries
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let entryCount = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(entryCount, 2)
        
        XCTAssertEqual(result[0][0].toString(), "foo")
        XCTAssertEqual(result[0][1].toString(), "bar")
        XCTAssertEqual(result[1][0].toString(), "baz")
        XCTAssertEqual(result[1][1].toString(), "qux")
    }
    
    // MARK: - String Conversion Tests
    
    func testToString() {
        let script = """
            const params = new URLSearchParams();
            params.append('name', 'John Doe');
            params.append('age', '25');
            params.append('hobbies', 'reading');
            params.append('hobbies', 'gaming');
            
            params.toString()
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let stringResult = result.toString()
        XCTAssertTrue(stringResult.contains("name=John+Doe"))
        XCTAssertTrue(stringResult.contains("age=25"))
        XCTAssertTrue(stringResult.contains("hobbies=reading"))
        XCTAssertTrue(stringResult.contains("hobbies=gaming"))
    }
    
    func testURLEncoding() {
        let script = """
            const params = new URLSearchParams();
            params.append('message', 'Hello World!');
            params.append('symbols', '!@#$%^&*()');
            params.append('unicode', '🚀🌟💫');
            params.append('spaces', 'multiple   spaces');
            
            const string = params.toString();
            const decoded = new URLSearchParams(string);
            
            ({
                original: {
                    message: params.get('message'),
                    symbols: params.get('symbols'),
                    unicode: params.get('unicode'),
                    spaces: params.get('spaces')
                },
                decoded: {
                    message: decoded.get('message'),
                    symbols: decoded.get('symbols'),
                    unicode: decoded.get('unicode'),
                    spaces: decoded.get('spaces')
                },
                encodedString: string
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Original and decoded should match
        XCTAssertEqual(result["original"]["message"].toString(), result["decoded"]["message"].toString())
        XCTAssertEqual(result["original"]["symbols"].toString(), result["decoded"]["symbols"].toString())
        XCTAssertEqual(result["original"]["unicode"].toString(), result["decoded"]["unicode"].toString())
        XCTAssertEqual(result["original"]["spaces"].toString(), result["decoded"]["spaces"].toString())
        
        // Encoded string should use + for spaces and % encoding for special characters
        let encodedString = result["encodedString"].toString()
        XCTAssertTrue(encodedString.contains("Hello+World"))
        XCTAssertTrue(encodedString.contains("%"))
    }
    
    // MARK: - Sort Test
    
    func testSort() {
        let script = """
            const params = new URLSearchParams('z=1&a=2&m=3&b=4');
            const beforeSort = params.toString();
            
            params.sort();
            const afterSort = params.toString();
            
            ({
                beforeSort: beforeSort,
                afterSort: afterSort,
                isSorted: afterSort === 'a=2&b=4&m=3&z=1'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertNotEqual(result["beforeSort"].toString(), result["afterSort"].toString())
        XCTAssertTrue(result["isSorted"].boolValue ?? false, "Parameters should be sorted alphabetically")
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyValues() {
        let script = """
            const params = new URLSearchParams('empty=&novalue&hasvalue=test');
            ({
                empty: params.get('empty'),
                novalue: params.get('novalue'),
                hasvalue: params.get('hasvalue'),
                hasEmpty: params.has('empty'),
                hasNovalue: params.has('novalue')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["empty"].toString(), "")
        XCTAssertEqual(result["novalue"].toString(), "")
        XCTAssertEqual(result["hasvalue"].toString(), "test")
        XCTAssertTrue(result["hasEmpty"].boolValue ?? false)
        XCTAssertTrue(result["hasNovalue"].boolValue ?? false)
    }
    
    func testSpecialCharacters() {
        let script = """
            const params = new URLSearchParams();
            params.append('=key', '=value');
            params.append('&key', '&value');
            params.append('?key', '?value');
            params.append('#key', '#value');
            
            const string = params.toString();
            const parsed = new URLSearchParams(string);
            
            ({
                roundTripEquals: parsed.get('=key') === '=value',
                roundTripAmpersand: parsed.get('&key') === '&value',
                roundTripQuestion: parsed.get('?key') === '?value',
                roundTripHash: parsed.get('#key') === '#value'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["roundTripEquals"].boolValue ?? false)
        XCTAssertTrue(result["roundTripAmpersand"].boolValue ?? false)
        XCTAssertTrue(result["roundTripQuestion"].boolValue ?? false)
        XCTAssertTrue(result["roundTripHash"].boolValue ?? false)
    }
    
    // MARK: - Integration with Fetch Tests
    
    func testURLSearchParamsWithFetch() {
        let expectation = XCTestExpectation(description: "URLSearchParams with fetch")
        
        let script = """
            const params = new URLSearchParams();
            params.append('method', 'test');
            params.append('framework', 'SwiftJS');
            params.append('timestamp', Date.now().toString());
            
            fetch('https://postman-echo.com/post', {
                method: 'POST',
                body: params
            })
            .then(response => response.json())
            .then(data => {
                testCompleted({
                    success: true,
                    receivedForm: data.form,
                    contentType: data.headers['content-type'] || data.headers['Content-Type'],
                    hasMethod: !!(data.form && data.form.method),
                    methodValue: data.form ? data.form.method : null
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
                result["success"].boolValue ?? false,
                "Request should succeed: \(result["error"].toString())")
            XCTAssertTrue(result["hasMethod"].boolValue ?? false, "Should receive form data")
            XCTAssertEqual(
                result["methodValue"].toString(), "test", "Form data should be preserved")
            let contentType = result["contentType"].toString()
            XCTAssertTrue(
                contentType.contains("application/x-www-form-urlencoded"),
                "Should use correct content type")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Tests
    
    func testLargeParameterSet() {
        let script = """
            const params = new URLSearchParams();
            
            // Add many parameters
            for (let i = 0; i < 1000; i++) {
                params.append(`key${i}`, `value${i}`);
            }
            
            // Test operations on large set
            const startTime = Date.now();
            
            const hasKey500 = params.has('key500');
            const getValue500 = params.get('key500');
            const allKeys = Array.from(params.keys());
            const stringForm = params.toString();
            
            const endTime = Date.now();
            
            ({
                paramCount: allKeys.length,
                hasKey500: hasKey500,
                getValue500: getValue500,
                stringLength: stringForm.length,
                duration: endTime - startTime,
                performanceOk: (endTime - startTime) < 1000 // Should complete within 1 second
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["paramCount"].numberValue ?? 0), 1000)
        XCTAssertTrue(result["hasKey500"].boolValue ?? false)
        XCTAssertEqual(result["getValue500"].toString(), "value500")
        XCTAssertGreaterThan(Int(result["stringLength"].numberValue ?? 0), 0)
        XCTAssertTrue(result["performanceOk"].boolValue ?? false, "Large parameter set operations should be fast")
    }
}
