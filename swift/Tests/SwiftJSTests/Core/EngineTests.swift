//
//  EngineTests.swift
//  SwiftJS Core Engine Tests
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

/// Tests for the core SwiftJS engine functionality including context creation,
/// JavaScript execution, polyfill system, and error handling.
@MainActor
final class EngineTests: XCTestCase {
    
    // MARK: - Engine Creation Tests
    
    func testSwiftJSCreation() {
        let context = SwiftJS()
        XCTAssertNotNil(context)
        XCTAssertNotNil(context.globalObject)
    }
    
    func testMultipleContextsIsolation() {
        let context1 = SwiftJS()
        let context2 = SwiftJS()

        context1.evaluateScript("globalThis.testValue = 'context1'")
        context2.evaluateScript("globalThis.testValue = 'context2'")

        let result1 = context1.evaluateScript("globalThis.testValue")
        let result2 = context2.evaluateScript("globalThis.testValue")

        XCTAssertEqual(result1.toString(), "context1")
        XCTAssertEqual(result2.toString(), "context2")
    }
    
    // MARK: - JavaScript Execution Tests
    
    func testBasicJavaScriptExecution() {
        let context = SwiftJS()
        let result = context.evaluateScript("2 + 3")
        XCTAssertEqual(result.numberValue, 5.0)
    }
    
    func testComplexJavaScriptExecution() {
        let script = """
            function fibonacci(n) {
                if (n <= 1) return n;
                return fibonacci(n - 1) + fibonacci(n - 2);
            }
            fibonacci(10)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 55.0)
    }
    
    func testJavaScriptVariableScope() {
        let context = SwiftJS()
        context.evaluateScript("""
            var globalVar = 'global';
            function testFunction() {
                var localVar = 'local';
                return globalVar + '-' + localVar;
            }
        """)
        let result = context.evaluateScript("testFunction()")
        XCTAssertEqual(result.toString(), "global-local")
    }
    
    // MARK: - JavaScript Language Features Tests
    
    func testPromiseSupport() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Promise")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testPromiseCreation() {
        let script = """
            const promise = new Promise((resolve, reject) => {
                resolve('test');
            });
            promise instanceof Promise
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testAsyncAwaitSupport() {
        let script = """
            async function testAsync() {
                return 'async-result';
            }
            typeof testAsync === 'function'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testModernJavaScriptFeatures() {
        let script = """
            // Test arrow functions
            const arrow = () => 'arrow';
            
            // Test template literals
            const template = `Template: ${arrow()}`;
            
            // Test destructuring
            const [a, b] = [1, 2];
            const {x, y} = {x: 10, y: 20};
            
            // Test spread operator
            const arr = [1, 2, 3];
            const spread = [...arr, 4, 5];
            
            template === 'Template: arrow' && 
            a === 1 && b === 2 && 
            x === 10 && y === 20 && 
            spread.length === 5
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testJavaScriptExceptionHandling() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            try {
                throw new Error("Test error");
            } catch (e) {
                e.message;
            }
        """)
        XCTAssertEqual(result.toString(), "Test error")
    }
    
    func testSyntaxErrorHandling() {
        let context = SwiftJS()
        let result = context.evaluateScript("invalid syntax {}")
        // Should not crash, but return undefined or handle gracefully
        XCTAssertTrue(result.isUndefined || result.isNull)
    }
    
    func testUndefinedVariableAccess() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof undefinedVariable")
        XCTAssertEqual(result.toString(), "undefined")
    }
    
    func testErrorObjectProperties() {
        let script = """
            try {
                throw new Error("Custom error");
            } catch (e) {
                ({
                    hasMessage: typeof e.message === 'string',
                    hasName: typeof e.name === 'string',
                    hasStack: typeof e.stack === 'string',
                    message: e.message,
                    name: e.name
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasMessage"].boolValue ?? false)
        XCTAssertTrue(result["hasName"].boolValue ?? false)
        XCTAssertTrue(result["hasStack"].boolValue ?? false)
        XCTAssertEqual(result["message"].toString(), "Custom error")
        XCTAssertEqual(result["name"].toString(), "Error")
    }
    
    // MARK: - Polyfill System Tests
    
    func testPolyfillAutomatic() {
        // SwiftJS() constructor automatically applies polyfills
        let context = SwiftJS()
        
        // Verify that polyfilled APIs are available
        XCTAssertEqual(context.evaluateScript("typeof console").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof setTimeout").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof fetch").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof crypto").toString(), "object")
        XCTAssertEqual(context.evaluateScript("typeof process").toString(), "object")
    }
    
    func testPolyfillConsistency() {
        // Test that polyfills behave consistently across multiple contexts
        let context1 = SwiftJS()
        let context2 = SwiftJS()

        let uuid1 = context1.evaluateScript("crypto.randomUUID()")
        let uuid2 = context2.evaluateScript("crypto.randomUUID()")

        // Both should be valid UUIDs but different
        XCTAssertNotEqual(uuid1.toString(), uuid2.toString())
        XCTAssertTrue(uuid1.toString().count > 30)  // UUID should be long
        XCTAssertTrue(uuid2.toString().count > 30)
    }
    
    func testPolyfillIntegration() {
        let context = SwiftJS()
        let script = """
            // Test that polyfilled APIs work together
            const encoder = new TextEncoder();
            const data = encoder.encode('test');
            const uuid = crypto.randomUUID();
            const pid = process.pid;
            
            data instanceof Uint8Array && 
            typeof uuid === 'string' && 
            typeof pid === 'number'
        """
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Runtime Performance Tests
    
    func testEnginePerformanceBaseline() {
        let context = SwiftJS()
        let script = """
            function performanceTest() {
                let sum = 0;
                for (let i = 0; i < 10000; i++) {
                    sum += i;
                }
                return sum;
            }
            performanceTest()
        """
        
        measure {
            _ = context.evaluateScript(script)
        }
    }
    
    func testContextCreationPerformance() {
        measure {
            for _ in 0..<10 {
                _ = SwiftJS()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsageWithLargeData() {
        let context = SwiftJS()
        // Test that the engine can handle large data without crashing
        let script = """
            const largeArray = new Array(10000).fill('test data');
            largeArray.length
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 10000)
    }
    
    func testLargeDataHandling() {
        let context = SwiftJS()
        let script = """
            // Create and process large data structure
            const largeObject = {};
            for (let i = 0; i < 1000; i++) {
                largeObject[`key${i}`] = `value${i}`;
            }
            Object.keys(largeObject).length
        """
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 1000)
    }
    
    // MARK: - Engine Configuration Tests
    
    func testGlobalObjectAccess() {
        let context = SwiftJS()
        let globalObject = context.globalObject
        
        XCTAssertNotNil(globalObject)
        XCTAssertEqual(globalObject["undefined"].toString(), "undefined")
        XCTAssertTrue(globalObject["JSON"].isObject)
        XCTAssertEqual(globalObject["parseInt"]["name"].toString(), "parseInt")
    }
    
    func testContextStateIsolation() {
        let context1 = SwiftJS()
        let context2 = SwiftJS()
        
        // Set different global state in each context
        context1.evaluateScript("globalThis.contextId = 'first'")
        context2.evaluateScript("globalThis.contextId = 'second'")
        
        // Verify isolation
        XCTAssertEqual(context1.evaluateScript("globalThis.contextId").toString(), "first")
        XCTAssertEqual(context2.evaluateScript("globalThis.contextId").toString(), "second")
        
        // Verify undefined in opposite context
        XCTAssertTrue(context1.evaluateScript("typeof globalThis.secondContextVar").toString() == "undefined")
        XCTAssertTrue(context2.evaluateScript("typeof globalThis.firstContextVar").toString() == "undefined")
    }
}
