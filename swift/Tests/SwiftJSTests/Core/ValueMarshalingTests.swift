//
//  ValueMarshalingTests.swift
//  SwiftJS Value Marshaling Tests
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

/// Tests for the SwiftJS value marshaling system that converts values between
/// Swift and JavaScript contexts, including primitive types, collections, and objects.
@MainActor
final class ValueMarshalingTests: XCTestCase {
    
    // MARK: - Primitive Type Marshaling Tests
    
    func testStringMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("'Hello, SwiftJS!'")
        XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
    }
    
    func testNumberMarshaling() {
        let context = SwiftJS()
        
        // Integer
        let intResult = context.evaluateScript("42")
        XCTAssertEqual(intResult.numberValue, 42.0)
        
        // Float
        let floatResult = context.evaluateScript("42.5")
        XCTAssertEqual(floatResult.numberValue, 42.5)
        
        // Negative number
        let negativeResult = context.evaluateScript("-123.456")
        XCTAssertEqual(negativeResult.numberValue, -123.456)
        
        // Zero
        let zeroResult = context.evaluateScript("0")
        XCTAssertEqual(zeroResult.numberValue, 0.0)
    }
    
    func testBooleanMarshaling() {
        let context = SwiftJS()
        let trueResult = context.evaluateScript("true")
        let falseResult = context.evaluateScript("false")
        XCTAssertTrue(trueResult.boolValue ?? false)
        XCTAssertFalse(falseResult.boolValue ?? true)
    }
    
    func testNullAndUndefinedMarshaling() {
        let context = SwiftJS()
        
        let nullResult = context.evaluateScript("null")
        XCTAssertTrue(nullResult.isNull)
        
        let undefinedResult = context.evaluateScript("undefined")
        XCTAssertTrue(undefinedResult.isUndefined)
        
        let voidResult = context.evaluateScript("void 0")
        XCTAssertTrue(voidResult.isUndefined)
    }
    
    // MARK: - Collection Marshaling Tests
    
    func testArrayMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("[1, 2, 3, 'test', true]")
        
        XCTAssertEqual(result[0].numberValue, 1)
        XCTAssertEqual(result[1].numberValue, 2)
        XCTAssertEqual(result[2].numberValue, 3)
        XCTAssertEqual(result[3].toString(), "test")
        XCTAssertTrue(result[4].boolValue ?? false)
    }
    
    func testNestedArrayMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("[[1, 2], [3, 4], ['a', 'b']]")
        
        XCTAssertEqual(result[0][0].numberValue, 1)
        XCTAssertEqual(result[0][1].numberValue, 2)
        XCTAssertEqual(result[1][0].numberValue, 3)
        XCTAssertEqual(result[1][1].numberValue, 4)
        XCTAssertEqual(result[2][0].toString(), "a")
        XCTAssertEqual(result[2][1].toString(), "b")
    }
    
    func testObjectMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("({ name: 'SwiftJS', version: 1.0, active: true })")
        
        XCTAssertEqual(result["name"].toString(), "SwiftJS")
        XCTAssertEqual(result["version"].numberValue, 1.0)
        XCTAssertTrue(result["active"].boolValue ?? false)
    }
    
    func testNestedObjectMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            ({
                project: {
                    name: 'SwiftJS',
                    details: {
                        version: '1.0',
                        platform: 'iOS/macOS'
                    }
                },
                config: {
                    debug: true,
                    ports: [8080, 3000]
                }
            })
        """)
        
        XCTAssertEqual(result["project"]["name"].toString(), "SwiftJS")
        XCTAssertEqual(result["project"]["details"]["version"].toString(), "1.0")
        XCTAssertEqual(result["project"]["details"]["platform"].toString(), "iOS/macOS")
        XCTAssertTrue(result["config"]["debug"].boolValue ?? false)
        XCTAssertEqual(result["config"]["ports"][0].numberValue, 8080)
        XCTAssertEqual(result["config"]["ports"][1].numberValue, 3000)
    }
    
    // MARK: - Special JavaScript Types
    
    func testFunctionMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("function test() { return 'function'; } test")
        
        XCTAssertTrue(result.isFunction)
        
        let callResult = result.call(withArguments: [])
        XCTAssertEqual(callResult.toString(), "function")
    }
    
    func testDateMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("new Date('2023-01-01T00:00:00.000Z')")
        
        XCTAssertTrue(result.isObject)
        // Use invokeMethod instead of call to preserve 'this' context
        XCTAssertEqual(result.invokeMethod("getFullYear", withArguments: []).numberValue, 2023)
    }
    
    func testRegExpMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("/test\\d+/gi")
        
        XCTAssertTrue(result.isObject)
        XCTAssertEqual(result["source"].toString(), "test\\d+")
        XCTAssertTrue(result["global"].boolValue ?? false)
        XCTAssertTrue(result["ignoreCase"].boolValue ?? false)
    }
    
    // MARK: - Type Conversion Tests
    
    func testTypeofOperator() {
        let context = SwiftJS()
        
        XCTAssertEqual(context.evaluateScript("typeof 'string'").toString(), "string")
        XCTAssertEqual(context.evaluateScript("typeof 42").toString(), "number")
        XCTAssertEqual(context.evaluateScript("typeof true").toString(), "boolean")
        XCTAssertEqual(context.evaluateScript("typeof undefined").toString(), "undefined")
        XCTAssertEqual(context.evaluateScript("typeof null").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof []").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof {}").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof function() {}").toString(), "function")
    }
    
    func testTruthyFalsyValues() {
        let context = SwiftJS()
        let script = """
            ({
                truthyValues: [
                    !!true,
                    !!'non-empty string',
                    !!1,
                    !!-1,
                    !![],
                    !!{},
                    !!function() {}
                ],
                falsyValues: [
                    !!false,
                    !!'',
                    !!0,
                    !!null,
                    !!undefined,
                    !!NaN
                ]
            })
        """
        let result = context.evaluateScript(script)
        
        // All truthy values should be true
        for i in 0..<7 {
            XCTAssertTrue(result["truthyValues"][i].boolValue ?? false, "Truthy value at index \(i) should be true")
        }
        
        // All falsy values should be false
        for i in 0..<6 {
            XCTAssertFalse(result["falsyValues"][i].boolValue ?? true, "Falsy value at index \(i) should be false")
        }
    }
    
    func testTypeCoercion() {
        let context = SwiftJS()
        let script = """
            ({
                stringNumber: '42' + 0,
                numberString: 42 + '',
                booleanNumber: true + 1,
                arrayString: [1, 2, 3] + '',
                objectString: ({}) + '',
                comparison: '10' > '9',
                numericComparison: '10' > 9
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["stringNumber"].toString(), "420")
        XCTAssertEqual(result["numberString"].toString(), "42")
        XCTAssertEqual(result["booleanNumber"].numberValue, 2)
        XCTAssertEqual(result["arrayString"].toString(), "1,2,3")
        XCTAssertEqual(result["objectString"].toString(), "[object Object]")
        XCTAssertFalse(result["comparison"].boolValue ?? true) // String comparison
        XCTAssertTrue(result["numericComparison"].boolValue ?? false) // Numeric comparison
    }
    
    // MARK: - Error Value Marshaling
    
    func testErrorMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            try {
                throw new Error('Test error message');
            } catch (e) {
                e;
            }
        """)
        
        XCTAssertTrue(result.isObject)
        XCTAssertEqual(result["message"].toString(), "Test error message")
        XCTAssertEqual(result["name"].toString(), "Error")
        XCTAssertTrue(result["stack"].isString)
    }
    
    func testCustomErrorMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            try {
                const error = new TypeError('Custom type error');
                error.customProperty = 'custom value';
                throw error;
            } catch (e) {
                e;
            }
        """)
        
        XCTAssertEqual(result["message"].toString(), "Custom type error")
        XCTAssertEqual(result["name"].toString(), "TypeError")
        XCTAssertEqual(result["customProperty"].toString(), "custom value")
    }
    
    // MARK: - Performance Tests
    
    func testLargeArrayMarshaling() {
        let context = SwiftJS()
        let script = """
            var largeArray = new Array(10000);
            for (let i = 0; i < largeArray.length; i++) {
                largeArray[i] = i;
            }
            largeArray
        """
        
        measure {
            let result = context.evaluateScript(script)
            XCTAssertEqual(result[0].numberValue, 0)
            XCTAssertEqual(result[9999].numberValue, 9999)
        }
    }
    
    func testLargeObjectMarshaling() {
        let context = SwiftJS()
        let script = """
            var largeObject = {};
            for (let i = 0; i < 1000; i++) {
                largeObject[`key${i}`] = `value${i}`;
            }
            largeObject
        """
        
        measure {
            let result = context.evaluateScript(script)
            XCTAssertEqual(result["key0"].toString(), "value0")
            XCTAssertEqual(result["key999"].toString(), "value999")
        }
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testNaNMarshaling() {
        let context = SwiftJS()
        let result = context.evaluateScript("NaN")
        
        // NaN should be a number but not equal to itself
        XCTAssertTrue(result.isNumber)
        XCTAssertNotEqual(result.numberValue, result.numberValue) // NaN != NaN
    }
    
    func testInfinityMarshaling() {
        let context = SwiftJS()
        
        let positiveInfinity = context.evaluateScript("Infinity")
        let negativeInfinity = context.evaluateScript("-Infinity")
        
        XCTAssertTrue(positiveInfinity.isNumber)
        XCTAssertTrue(negativeInfinity.isNumber)
        XCTAssertTrue(positiveInfinity.numberValue?.isInfinite ?? false)
        XCTAssertTrue(negativeInfinity.numberValue?.isInfinite ?? false)
    }
    
    func testVeryLargeNumbers() {
        let context = SwiftJS()
        
        let maxSafeInteger = context.evaluateScript("Number.MAX_SAFE_INTEGER")
        let largeNumber = context.evaluateScript("Number.MAX_VALUE")
        
        XCTAssertEqual(maxSafeInteger.numberValue, 9007199254740991) // 2^53 - 1
        XCTAssertTrue((largeNumber.numberValue ?? 0) > 1e308)
    }
    
    func testEmptyValues() {
        let context = SwiftJS()
        let script = """
            ({
                emptyString: '',
                emptyArray: [],
                emptyObject: {},
                zeroNumber: 0,
                falseBoolean: false
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["emptyString"].toString(), "")
        XCTAssertTrue(result["emptyArray"].isArray)
        XCTAssertTrue(result["emptyObject"].isObject)
        XCTAssertEqual(result["zeroNumber"].numberValue, 0)
        XCTAssertFalse(result["falseBoolean"].boolValue ?? true)
    }
    
    func testCircularReferenceHandling() {
        let context = SwiftJS()
        let script = """
            const obj = { name: 'test' };
            obj.self = obj;
            obj.name
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "test")
    }
    
    // MARK: - Swift to JavaScript Value Creation
    
    func testSwiftToJavaScriptValueCreation() {
        let context = SwiftJS()
        
        // Create JavaScript values from Swift by evaluating scripts
        context.evaluateScript("globalThis.swiftString = 'Hello from Swift'")
        context.evaluateScript("globalThis.swiftNumber = 42.5")
        context.evaluateScript("globalThis.swiftBoolean = true")
        
        // Test access from JavaScript
        XCTAssertEqual(context.evaluateScript("swiftString").toString(), "Hello from Swift")
        XCTAssertEqual(context.evaluateScript("swiftNumber").numberValue, 42.5)
        XCTAssertTrue(context.evaluateScript("swiftBoolean").boolValue ?? false)
    }
}
