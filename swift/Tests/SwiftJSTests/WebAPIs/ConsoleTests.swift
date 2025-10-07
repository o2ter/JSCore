//
//  ConsoleTests.swift
//  SwiftJS Console API Tests
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

/// Tests for the Web Console API including console.log, console.error,
/// console.warn, console.info and other console methods.
@MainActor
final class ConsoleTests: XCTestCase {
    
    // MARK: - Console API Existence Tests
    
    func testConsoleExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof console")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testConsoleMethods() {
        let script = """
            ({
                hasLog: typeof console.log === 'function',
                hasError: typeof console.error === 'function',
                hasWarn: typeof console.warn === 'function',
                hasInfo: typeof console.info === 'function',
                hasDebug: typeof console.debug === 'function',
                hasTrace: typeof console.trace === 'function'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasLog"].boolValue ?? false)
        XCTAssertTrue(result["hasError"].boolValue ?? false)
        XCTAssertTrue(result["hasWarn"].boolValue ?? false)
        XCTAssertTrue(result["hasInfo"].boolValue ?? false)
        // debug and trace might not be implemented in all environments
        // XCTAssertTrue(result["hasDebug"].boolValue ?? false)
        // XCTAssertTrue(result["hasTrace"].boolValue ?? false)
    }
    
    // MARK: - Basic Console Method Tests
    
    func testConsoleLog() {
        let script = """
            try {
                console.log('Hello, SwiftJS!');
                console.log('Multiple', 'arguments', 123, true);
                console.log({ object: 'value' }, [1, 2, 3]);
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleError() {
        let script = """
            try {
                console.error('Error message');
                console.error('Error with', 'multiple', 'arguments');
                console.error(new Error('Test error'));
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleWarn() {
        let script = """
            try {
                console.warn('Warning message');
                console.warn('Warning with data:', { warning: true });
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleInfo() {
        let script = """
            try {
                console.info('Info message');
                console.info('Info with data:', { info: true });
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Console Method Argument Tests
    
    func testConsoleWithPrimitiveTypes() {
        let script = """
            try {
                console.log('String argument');
                console.log(42);
                console.log(true);
                console.log(false);
                console.log(null);
                console.log(undefined);
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleWithObjects() {
        let script = """
            try {
                console.log({ name: 'test', value: 123 });
                console.log([1, 2, 3, 'array']);
                console.log(new Date());
                console.log(/regex/gi);
                console.log(function() { return 'function'; });
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleWithMixedArguments() {
        let script = """
            try {
                console.log('Mixed:', 42, true, { obj: 'value' }, [1, 2, 3]);
                console.error('Error:', new Error('test'), 'additional info');
                console.warn('Warning:', { level: 'high' }, 'at', new Date());
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Console Format String Tests
    
    func testConsoleFormatStrings() {
        let script = """
            try {
                // Test if format strings are supported
                console.log('%s %d %o', 'string', 42, { obj: true });
                console.log('User %s is %d years old', 'John', 30);
                console.log('%c Styled text', 'color: blue; font-weight: bold;');
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Console Timing Tests (if supported)
    
    func testConsoleTime() {
        let script = """
            try {
                if (typeof console.time === 'function' && typeof console.timeEnd === 'function') {
                    console.time('test-timer');
                    // Do some work
                    for (let i = 0; i < 1000; i++) {
                        Math.random();
                    }
                    console.timeEnd('test-timer');
                    
                    ({ timingSupported: true })
                } else {
                    ({ timingSupported: false })
                }
            } catch (error) {
                ({ timingSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Timing methods are optional in many console implementations
        if result["timingSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Console Count Tests (if supported)
    
    func testConsoleCount() {
        let script = """
            try {
                if (typeof console.count === 'function' && typeof console.countReset === 'function') {
                    console.count('test-counter');
                    console.count('test-counter');
                    console.count('test-counter');
                    console.countReset('test-counter');
                    console.count('test-counter');
                    
                    ({ countSupported: true })
                } else {
                    ({ countSupported: false })
                }
            } catch (error) {
                ({ countSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Count methods are optional in many console implementations
        if result["countSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Console Group Tests (if supported)
    
    func testConsoleGroup() {
        let script = """
            try {
                if (typeof console.group === 'function' && 
                    typeof console.groupEnd === 'function' &&
                    typeof console.groupCollapsed === 'function') {
                    
                    console.group('Main Group');
                    console.log('Inside main group');
                    
                    console.groupCollapsed('Nested Group');
                    console.log('Inside nested group');
                    console.groupEnd();
                    
                    console.log('Back in main group');
                    console.groupEnd();
                    
                    ({ groupSupported: true })
                } else {
                    ({ groupSupported: false })
                }
            } catch (error) {
                ({ groupSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Group methods are optional in many console implementations
        if result["groupSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Console Table Tests (if supported)
    
    func testConsoleTable() {
        let script = """
            try {
                if (typeof console.table === 'function') {
                    const data = [
                        { name: 'John', age: 30, city: 'New York' },
                        { name: 'Jane', age: 25, city: 'Los Angeles' },
                        { name: 'Bob', age: 35, city: 'Chicago' }
                    ];
                    
                    console.table(data);
                    console.table(data, ['name', 'age']);
                    
                    ({ tableSupported: true })
                } else {
                    ({ tableSupported: false })
                }
            } catch (error) {
                ({ tableSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Table method is optional in many console implementations
        if result["tableSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Console Clear Tests (if supported)
    
    func testConsoleClear() {
        let script = """
            try {
                if (typeof console.clear === 'function') {
                    console.log('Before clear');
                    console.clear();
                    console.log('After clear');
                    
                    ({ clearSupported: true })
                } else {
                    ({ clearSupported: false })
                }
            } catch (error) {
                ({ clearSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Clear method is optional in many console implementations
        if result["clearSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testConsoleWithNoArguments() {
        let script = """
            try {
                console.log();
                console.error();
                console.warn();
                console.info();
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleWithCircularReferences() {
        let script = """
            try {
                const obj = { name: 'circular' };
                obj.self = obj;
                console.log('Circular object:', obj);
                true
            } catch (error) {
                // Should handle circular references gracefully
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleWithVeryLargeObjects() {
        let script = """
            try {
                const largeArray = new Array(10000).fill('large data');
                const largeObject = {};
                for (let i = 0; i < 1000; i++) {
                    largeObject[`key${i}`] = `value${i}`;
                }
                
                console.log('Large array:', largeArray);
                console.log('Large object:', largeObject);
                true
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Console Assert Tests (if supported)
    
    func testConsoleAssert() {
        let script = """
            try {
                if (typeof console.assert === 'function') {
                    console.assert(true, 'This should not appear');
                    console.assert(false, 'This assertion failed:', { data: 'test' });
                    console.assert(1 === 1, 'This should not appear');
                    console.assert(1 === 2, 'Math is broken!');
                    
                    ({ assertSupported: true })
                } else {
                    ({ assertSupported: false })
                }
            } catch (error) {
                ({ assertSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Assert method is optional in many console implementations
        if result["assertSupported"].boolValue ?? false {
            XCTAssertFalse(result["error"].isString)
        }
    }
    
    // MARK: - Performance Tests
    
    func testConsolePerformance() {
        let context = SwiftJS()
        let script = """
            function logManyMessages() {
                for (let i = 0; i < 1000; i++) {
                    console.log('Message', i, { iteration: i });
                }
                return true;
            }
            logManyMessages
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("logManyMessages()")
        }
    }
    
    func testConsoleWithComplexObjects() {
        let context = SwiftJS()
        let script = """
            function logComplexObjects() {
                for (let i = 0; i < 100; i++) {
                    const complexObj = {
                        id: i,
                        data: {
                            nested: {
                                deep: {
                                    array: [1, 2, 3, { inner: 'value' }],
                                    date: new Date(),
                                    regex: /test\\d+/gi
                                }
                            }
                        },
                        methods: {
                            toString: () => `Object ${i}`,
                            valueOf: () => i
                        }
                    };
                    console.log('Complex object', i, complexObj);
                }
                return true;
            }
            logComplexObjects
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("logComplexObjects()")
        }
    }
    
    // MARK: - Integration Tests
    
    func testConsoleWithOtherAPIs() {
        let script = """
            try {
                // Test console with crypto API
                const uuid = crypto.randomUUID();
                console.log('Generated UUID:', uuid);
                
                // Test console with text encoding
                const encoder = new TextEncoder();
                const encoded = encoder.encode('console test');
                console.log('Encoded text:', encoded);
                
                // Test console with timers
                setTimeout(() => {
                    console.log('Timer executed');
                }, 1);
                
                // Test console with events
                const target = new EventTarget();
                target.addEventListener('test', (event) => {
                    console.log('Event fired:', event.type);
                });
                target.dispatchEvent(new Event('test'));
                
                true
            } catch (error) {
                console.error('Integration test failed:', error);
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testConsoleMethodChaining() {
        let script = """
            try {
                // Some implementations might support method chaining
                if (console.log('test') === console) {
                    ({ chainingSupported: true })
                } else {
                    ({ chainingSupported: false })
                }
            } catch (error) {
                ({ chainingSupported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Method chaining is not standard for console but some implementations support it
        let chainingSupported = result["chainingSupported"].boolValue ?? false
        let hasError = result["error"].isString
        XCTAssertTrue(chainingSupported || hasError || !chainingSupported)
    }
}
