//
//  ThreadingTests.swift
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

final class ThreadingTests: XCTestCase {

    func testTimerFromPromiseCallback() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "Timer from Promise callback")
        
        let script = """
            Promise.resolve('test').then(value => {
                console.log('Promise resolved:', value);
                setTimeout(() => {
                    console.log('Timer fired from Promise callback');
                    globalThis.testCompleted = true;
                }, 100);
            });
        """
        
        _ = context.evaluateScript(script)
        
        // Check for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let completed = context.globalObject["testCompleted"]
            if completed.isBool && completed.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentTimerOperations() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "Concurrent timer operations")
        
        let script = """
            let completedTimers = 0;
            const totalTimers = 5;
            
            for (let i = 0; i < totalTimers; i++) {
                setTimeout(() => {
                    completedTimers++;
                    console.log(`Timer ${i} completed (${completedTimers}/${totalTimers})`);
                    
                    if (completedTimers === totalTimers) {
                        globalThis.allTimersCompleted = true;
                    }
                }, 50 + (i * 25));
            }
        """
        
        _ = context.evaluateScript(script)
        
        // Check for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let completed = context.globalObject["allTimersCompleted"]
            if completed.isBool && completed.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testClearTimeoutThreadSafety() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "clearTimeout thread safety")
        
        let script = """
            let timerFiredAfterClear = false;
            
            const timerId = setTimeout(() => {
                timerFiredAfterClear = true;
                console.log('ERROR: Timer fired after being cleared');
            }, 200);
            
            clearTimeout(timerId);
            console.log('Timer cleared immediately');
            
            setTimeout(() => {
                globalThis.clearTimeoutWorked = !timerFiredAfterClear;
                console.log('clearTimeout test result:', !timerFiredAfterClear);
            }, 300);
        """
        
        _ = context.evaluateScript(script)
        
        // Check for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let worked = context.globalObject["clearTimeoutWorked"]
            if worked.isBool && worked.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testSetIntervalOperations() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "setInterval operations")
        
        let script = """
            let intervalCount = 0;
            let intervalStopped = false;
            
            const intervalId = setInterval(() => {
                intervalCount++;
                console.log(`Interval tick ${intervalCount}`);
                
                if (intervalCount >= 3) {
                    clearInterval(intervalId);
                    console.log('Interval cleared');
                    intervalStopped = true;
                    
                    // Verify it stopped
                    setTimeout(() => {
                        globalThis.intervalWorked = (intervalCount === 3);
                        console.log('setInterval test result:', intervalCount === 3);
                    }, 200);
                }
            }, 50);
        """
        
        _ = context.evaluateScript(script)
        
        // Check for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let worked = context.globalObject["intervalWorked"]
            if worked.isBool && worked.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testTimerIDGeneration() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "Timer ID generation")
        
        let script = """
            const timerIds = [];
            
            // Create multiple timers rapidly to test ID generation
            for (let i = 0; i < 10; i++) {
                const id = setTimeout(() => {
                    console.log(`Timer ${i} with ID ${id} fired`);
                }, 50 + (i * 10));
                timerIds.push(id);
            }
            
            // Check for unique IDs
            const uniqueIds = new Set(timerIds);
            globalThis.idsUnique = (uniqueIds.size === timerIds.length);
            globalThis.timerIds = timerIds;
            
            console.log('Generated timer IDs:', timerIds);
            console.log('All IDs unique:', uniqueIds.size === timerIds.length);
        """
        
        _ = context.evaluateScript(script)
        
        // Check immediately since ID generation is synchronous
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let idsUnique = context.globalObject["idsUnique"]
            if idsUnique.isBool && idsUnique.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testNestedTimerOperations() throws {
        let context = SwiftJS()
        let expectation = expectation(description: "Nested timer operations")
        
        let script = """
            let nestedResults = [];
            
            setTimeout(() => {
                nestedResults.push('outer');
                console.log('Outer timer fired');
                
                setTimeout(() => {
                    nestedResults.push('inner');
                    console.log('Inner timer fired');
                    
                    globalThis.nestedComplete = (nestedResults.length === 2 && 
                                               nestedResults[0] === 'outer' && 
                                               nestedResults[1] === 'inner');
                }, 50);
            }, 100);
        """
        
        _ = context.evaluateScript(script)
        
        // Check for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let completed = context.globalObject["nestedComplete"]
            if completed.isBool && completed.boolValue == true {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
