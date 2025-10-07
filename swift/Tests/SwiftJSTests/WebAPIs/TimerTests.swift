//
//  TimerTests.swift
//  SwiftJS Timer API Tests
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

/// Tests for the Web Timer API including setTimeout, setInterval, 
/// clearTimeout, and clearInterval functions.
@MainActor
final class TimerTests: XCTestCase {
    
    // MARK: - Timer API Existence Tests
    
    func testTimerAPIExists() {
        let context = SwiftJS()
        
        XCTAssertEqual(context.evaluateScript("typeof setTimeout").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof setInterval").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof clearTimeout").toString(), "function")
        XCTAssertEqual(context.evaluateScript("typeof clearInterval").toString(), "function")
    }
    
    func testTimerFunctionality() {
        let script = """
            typeof setTimeout === 'function' &&
            typeof clearTimeout === 'function' &&
            typeof setInterval === 'function' &&
            typeof clearInterval === 'function'
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - setTimeout Tests
    
    func testSetTimeoutBasic() {
        let script = """
            // Test that setTimeout returns an ID and doesn't throw
            try {
                const timeoutId = setTimeout(() => {}, 100);
                typeof timeoutId !== 'undefined'
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testSetTimeoutExecution() {
        let expectation = XCTestExpectation(description: "setTimeout execution")
        
        let script = """
            let timeoutExecuted = false;
            setTimeout(() => {
                timeoutExecuted = true;
                testCompleted({ executed: timeoutExecuted });
            }, 50);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["executed"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSetTimeoutWithArguments() {
        let expectation = XCTestExpectation(description: "setTimeout with arguments")
        
        let script = """
            setTimeout((arg1, arg2, arg3) => {
                testCompleted({
                    arg1: arg1,
                    arg2: arg2,
                    arg3: arg3
                });
            }, 50, 'hello', 42, true);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(result["arg1"].toString(), "hello")
            XCTAssertEqual(result["arg2"].numberValue, 42)
            XCTAssertTrue(result["arg3"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSetTimeoutZeroDelay() {
        let expectation = XCTestExpectation(description: "setTimeout zero delay")
        
        let script = """
            let executionOrder = [];
            
            executionOrder.push('start');
            
            setTimeout(() => {
                executionOrder.push('timeout');
                testCompleted({ order: executionOrder });
            }, 0);
            
            executionOrder.push('end');
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let order = result["order"]
            
            // Should execute after current script
            XCTAssertEqual(order[0].toString(), "start")
            XCTAssertEqual(order[1].toString(), "end")
            XCTAssertEqual(order[2].toString(), "timeout")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - clearTimeout Tests
    
    func testClearTimeout() {
        let expectation = XCTestExpectation(description: "clearTimeout")
        
        let script = """
            let timeoutExecuted = false;
            
            const timeoutId = setTimeout(() => {
                timeoutExecuted = true;
            }, 100);
            
            clearTimeout(timeoutId);
            
            // Wait longer than the timeout to verify it was cancelled
            setTimeout(() => {
                testCompleted({ executed: timeoutExecuted });
            }, 200);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["executed"].boolValue ?? true)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testClearTimeoutInvalidId() {
        let script = """
            try {
                clearTimeout(99999);
                clearTimeout(-1);
                clearTimeout(null);
                clearTimeout(undefined);
                true // Should not throw
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - setInterval Tests
    
    func testSetIntervalBasic() {
        let script = """
            try {
                const intervalId = setInterval(() => {}, 100);
                clearInterval(intervalId); // Clean up immediately
                typeof intervalId !== 'undefined'
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testSetIntervalExecution() {
        let expectation = XCTestExpectation(description: "setInterval execution")
        
        let script = """
            let callCount = 0;
            
            const intervalId = setInterval(() => {
                callCount++;
                if (callCount >= 3) {
                    clearInterval(intervalId);
                    testCompleted({ callCount: callCount });
                }
            }, 50);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertGreaterThanOrEqual(Int(result["callCount"].numberValue ?? 0), 3)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testSetIntervalWithArguments() {
        let expectation = XCTestExpectation(description: "setInterval with arguments")
        
        let script = """
            let receivedArgs = [];
            
            const intervalId = setInterval((arg1, arg2) => {
                receivedArgs.push({ arg1, arg2 });
                if (receivedArgs.length >= 2) {
                    clearInterval(intervalId);
                    testCompleted({ 
                        firstCall: receivedArgs[0],
                        secondCall: receivedArgs[1]
                    });
                }
            }, 50, 'test', 123);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let firstCall = result["firstCall"]
            let secondCall = result["secondCall"]
            
            XCTAssertEqual(firstCall["arg1"].toString(), "test")
            XCTAssertEqual(firstCall["arg2"].numberValue, 123)
            XCTAssertEqual(secondCall["arg1"].toString(), "test")
            XCTAssertEqual(secondCall["arg2"].numberValue, 123)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - clearInterval Tests
    
    func testClearInterval() {
        let expectation = XCTestExpectation(description: "clearInterval")
        
        let script = """
            let callCount = 0;
            
            const intervalId = setInterval(() => {
                callCount++;
            }, 50);
            
            // Clear after short time
            setTimeout(() => {
                clearInterval(intervalId);
            }, 75);
            
            // Check count after longer time
            setTimeout(() => {
                testCompleted({ callCount: callCount });
            }, 200);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let callCount = Int(result["callCount"].numberValue ?? 0)
            // Should have been called 1-2 times before being cleared
            XCTAssertGreaterThan(callCount, 0)
            XCTAssertLessThan(callCount, 5)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testClearIntervalInvalidId() {
        let script = """
            try {
                clearInterval(99999);
                clearInterval(-1);
                clearInterval(null);
                clearInterval(undefined);
                true // Should not throw
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Timer ID Tests
    
    func testTimerIdUniqueness() {
        let script = """
            const timeoutId1 = setTimeout(() => {}, 1000);
            const timeoutId2 = setTimeout(() => {}, 1000);
            const intervalId1 = setInterval(() => {}, 1000);
            const intervalId2 = setInterval(() => {}, 1000);
            
            // Clean up
            clearTimeout(timeoutId1);
            clearTimeout(timeoutId2);
            clearInterval(intervalId1);
            clearInterval(intervalId2);
            
            // Check uniqueness
            const ids = [timeoutId1, timeoutId2, intervalId1, intervalId2];
            const uniqueIds = [...new Set(ids)];
            
            ({
                allDefined: ids.every(id => typeof id !== 'undefined'),
                allUnique: uniqueIds.length === ids.length,
                ids: ids
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allDefined"].boolValue ?? false)
        XCTAssertTrue(result["allUnique"].boolValue ?? false)
    }
    
    // MARK: - Timer Precision Tests
    
    func testTimerPrecision() {
        let expectation = XCTestExpectation(description: "timer precision")
        
        let script = """
            const startTime = Date.now();
            const expectedDelay = 100;
            
            setTimeout(() => {
                const endTime = Date.now();
                const actualDelay = endTime - startTime;
                const precision = Math.abs(actualDelay - expectedDelay);
                
                testCompleted({
                    expectedDelay: expectedDelay,
                    actualDelay: actualDelay,
                    precision: precision,
                    isReasonablyAccurate: precision < 50 // Within 50ms
                });
            }, expectedDelay);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertEqual(result["expectedDelay"].numberValue, 100)
            
            let actualDelay = result["actualDelay"].numberValue ?? 0
            XCTAssertGreaterThan(actualDelay, 90) // Should be at least close to expected
            
            let precision = result["precision"].numberValue ?? 1000
            XCTAssertLessThan(precision, 100) // Should be reasonably accurate
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testTimerWithInvalidCallback() {
        let script = """
            const results = [];
            
            // Test with non-function callbacks
            try {
                setTimeout(null, 100);
                results.push('null-accepted');
            } catch (e) {
                results.push('null-rejected');
            }
            
            try {
                setTimeout(undefined, 100);
                results.push('undefined-accepted');
            } catch (e) {
                results.push('undefined-rejected');
            }
            
            try {
                setTimeout('string', 100);
                results.push('string-accepted');
            } catch (e) {
                results.push('string-rejected');
            }
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(resultsLength, 3)
        
        // Should handle invalid callbacks appropriately (either accept and convert or reject)
        for i in 0..<resultsLength {
            let testResult = result[i].toString()
            XCTAssertTrue(testResult.contains("accepted") || testResult.contains("rejected"))
        }
    }
    
    func testTimerWithInvalidDelay() {
        let script = """
            const results = [];
            
            // Test with various delay values
            try {
                const id1 = setTimeout(() => {}, -100);
                clearTimeout(id1);
                results.push('negative-delay-accepted');
            } catch (e) {
                results.push('negative-delay-rejected');
            }
            
            try {
                const id2 = setTimeout(() => {}, 'not-a-number');
                clearTimeout(id2);
                results.push('string-delay-accepted');
            } catch (e) {
                results.push('string-delay-rejected');
            }
            
            try {
                const id3 = setTimeout(() => {}, null);
                clearTimeout(id3);
                results.push('null-delay-accepted');
            } catch (e) {
                results.push('null-delay-rejected');
            }
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(resultsLength, 3)
        
        // Should handle invalid delays gracefully
        for i in 0..<resultsLength {
            let testResult = result[i].toString()
            XCTAssertTrue(testResult.contains("accepted") || testResult.contains("rejected"))
        }
    }
    
    // MARK: - Performance Tests
    
    func testManyTimers() {
        let expectation = XCTestExpectation(description: "many timers")
        
        let script = """
            let completedCount = 0;
            const totalTimers = 100;
            const timeoutIds = [];
            
            for (let i = 0; i < totalTimers; i++) {
                const id = setTimeout(() => {
                    completedCount++;
                    if (completedCount === totalTimers) {
                        testCompleted({ 
                            totalTimers: totalTimers,
                            completedCount: completedCount 
                        });
                    }
                }, Math.random() * 100 + 10);
                timeoutIds.push(id);
            }
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(result["totalTimers"].numberValue, 100)
            XCTAssertEqual(result["completedCount"].numberValue, 100)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTimerCreationPerformance() {
        let context = SwiftJS()
        let script = """
            function createAndClearManyTimers() {
                const ids = [];
                for (let i = 0; i < 1000; i++) {
                    ids.push(setTimeout(() => {}, 10000));
                }
                for (const id of ids) {
                    clearTimeout(id);
                }
                return true;
            }
            createAndClearManyTimers
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("createAndClearManyTimers()")
        }
    }
    
    // MARK: - Integration Tests
    
    func testTimersWithOtherAPIs() {
        let expectation = XCTestExpectation(description: "timers with other APIs")
        
        let script = """
            let results = [];
            
            setTimeout(() => {
                // Use crypto API
                const uuid = crypto.randomUUID();
                results.push({ api: 'crypto', result: typeof uuid });
                
                // Use console
                console.log('Timer executed with crypto UUID:', uuid);
                results.push({ api: 'console', result: 'executed' });
                
                // Use TextEncoder
                const encoder = new TextEncoder();
                const encoded = encoder.encode('timer test');
                results.push({ api: 'textEncoder', result: encoded.length > 0 });
                
                testCompleted({ results: results });
            }, 50);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            
            XCTAssertEqual(Int(results["length"].numberValue ?? 0), 3)
            XCTAssertEqual(results[0]["api"].toString(), "crypto")
            XCTAssertEqual(results[0]["result"].toString(), "string")
            XCTAssertEqual(results[1]["api"].toString(), "console")
            XCTAssertEqual(results[1]["result"].toString(), "executed")
            XCTAssertEqual(results[2]["api"].toString(), "textEncoder")
            XCTAssertTrue(results[2]["result"].boolValue ?? false)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 3.0)
    }
}
