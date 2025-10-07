//
//  AbortControllerTests.swift
//  SwiftJS Tests
//
//  Created by GitHub Copilot on 2025/9/6.
//  Copyright © 2025 o2ter. All rights reserved.
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

/// Tests for the AbortController and AbortSignal APIs used for cancelling asynchronous operations.
@MainActor
final class AbortControllerTests: XCTestCase {
    
    // MARK: - AbortController API Existence Tests
    
    func testAbortControllerExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof AbortController")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testAbortSignalExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof AbortSignal")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testAbortControllerInstantiation() {
        let script = """
            const controller = new AbortController();
            ({
                isAbortController: controller instanceof AbortController,
                hasSignal: 'signal' in controller,
                hasAbort: typeof controller.abort === 'function',
                signalIsAbortSignal: controller.signal instanceof AbortSignal
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isAbortController"].boolValue ?? false)
        XCTAssertTrue(result["hasSignal"].boolValue ?? false)
        XCTAssertTrue(result["hasAbort"].boolValue ?? false)
        XCTAssertTrue(result["signalIsAbortSignal"].boolValue ?? false)
    }
    
    // MARK: - AbortSignal Properties Tests
    
    func testAbortSignalInitialState() {
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            ({
                aborted: signal.aborted,
                hasOnabort: 'onabort' in signal,
                hasAddEventListener: typeof signal.addEventListener === 'function',
                hasRemoveEventListener: typeof signal.removeEventListener === 'function',
                hasDispatchEvent: typeof signal.dispatchEvent === 'function',
                onabortInitial: signal.onabort
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertFalse(result["aborted"].boolValue ?? true)
        XCTAssertTrue(result["hasOnabort"].boolValue ?? false)
        XCTAssertTrue(result["hasAddEventListener"].boolValue ?? false)
        XCTAssertTrue(result["hasRemoveEventListener"].boolValue ?? false)
        XCTAssertTrue(result["hasDispatchEvent"].boolValue ?? false)
        XCTAssertTrue(result["onabortInitial"].isNull)
    }
    
    // MARK: - Abort Functionality Tests
    
    func testAbortControllerAbort() {
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            const beforeAbort = signal.aborted;
            controller.abort();
            const afterAbort = signal.aborted;
            
            ({
                beforeAbort: beforeAbort,
                afterAbort: afterAbort,
                transitioned: !beforeAbort && afterAbort
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertFalse(result["beforeAbort"].boolValue ?? true)
        XCTAssertTrue(result["afterAbort"].boolValue ?? false)
        XCTAssertTrue(result["transitioned"].boolValue ?? false)
    }
    
    func testAbortEventListener() {
        let expectation = XCTestExpectation(description: "Abort event listener")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let eventFired = false;
            let eventType = null;
            let eventTarget = null;
            
            signal.addEventListener('abort', function(event) {
                eventFired = true;
                eventType = event.type;
                eventTarget = event.target === signal;
                
                testCompleted({
                    eventFired: eventFired,
                    eventType: eventType,
                    eventTarget: eventTarget,
                    signalAborted: signal.aborted
                });
            });
            
            // Abort after a small delay to ensure listener is set up
            setTimeout(() => {
                controller.abort();
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["eventFired"].boolValue ?? false)
            XCTAssertEqual(result["eventType"].toString(), "abort")
            XCTAssertTrue(result["eventTarget"].boolValue ?? false)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAbortOnabortHandler() {
        let expectation = XCTestExpectation(description: "Abort onabort handler")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            signal.onabort = function(event) {
                testCompleted({
                    handlerCalled: true,
                    eventType: event.type,
                    eventTarget: event.target === signal,
                    signalAborted: signal.aborted
                });
            };
            
            setTimeout(() => {
                controller.abort();
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["handlerCalled"].boolValue ?? false)
            XCTAssertEqual(result["eventType"].toString(), "abort")
            XCTAssertTrue(result["eventTarget"].boolValue ?? false)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAbortMultipleListeners() {
        let expectation = XCTestExpectation(description: "Multiple abort listeners")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let listener1Called = false;
            let listener2Called = false;
            let onabortCalled = false;
            
            signal.addEventListener('abort', () => {
                listener1Called = true;
                checkCompletion();
            });
            
            signal.addEventListener('abort', () => {
                listener2Called = true;
                checkCompletion();
            });
            
            signal.onabort = () => {
                onabortCalled = true;
                checkCompletion();
            };
            
            function checkCompletion() {
                if (listener1Called && listener2Called && onabortCalled) {
                    testCompleted({
                        listener1Called: listener1Called,
                        listener2Called: listener2Called,
                        onabortCalled: onabortCalled,
                        allCalled: true
                    });
                }
            }
            
            setTimeout(() => {
                controller.abort();
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["listener1Called"].boolValue ?? false)
            XCTAssertTrue(result["listener2Called"].boolValue ?? false)
            XCTAssertTrue(result["onabortCalled"].boolValue ?? false)
            XCTAssertTrue(result["allCalled"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Event Listener Management Tests
    
    func testAbortEventListenerRemoval() {
        let expectation = XCTestExpectation(description: "Abort event listener removal")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let listenerCalled = false;
            
            function abortHandler() {
                listenerCalled = true;
            }
            
            signal.addEventListener('abort', abortHandler);
            signal.removeEventListener('abort', abortHandler);
            
            setTimeout(() => {
                controller.abort();
                
                // Give some time for the event to potentially fire
                setTimeout(() => {
                    testCompleted({
                        listenerCalled: listenerCalled,
                        signalAborted: signal.aborted
                    });
                }, 50);
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["listenerCalled"].boolValue ?? true)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAbortOnceEventListener() {
        let expectation = XCTestExpectation(description: "Abort once event listener")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let callCount = 0;
            
            signal.addEventListener('abort', () => {
                callCount++;
            }, { once: true });
            
            setTimeout(() => {
                controller.abort();
                
                // Try to trigger again (should not work since already aborted)
                try {
                    signal.dispatchEvent(new Event('abort'));
                } catch (e) {
                    // Might throw, that's ok
                }
                
                setTimeout(() => {
                    testCompleted({
                        callCount: callCount,
                        signalAborted: signal.aborted
                    });
                }, 50);
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(result["callCount"].numberValue, 1)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Multiple Abort Tests
    
    func testMultipleAbortCalls() {
        let expectation = XCTestExpectation(description: "Multiple abort calls")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let eventCount = 0;
            
            signal.addEventListener('abort', () => {
                eventCount++;
            });
            
            setTimeout(() => {
                controller.abort();
                controller.abort(); // Second call should be ignored
                controller.abort(); // Third call should be ignored
                
                setTimeout(() => {
                    testCompleted({
                        eventCount: eventCount,
                        signalAborted: signal.aborted
                    });
                }, 50);
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertEqual(result["eventCount"].numberValue, 1)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - AbortSignal with Other APIs Tests
    
    func testAbortSignalWithSetTimeout() {
        let expectation = XCTestExpectation(description: "AbortSignal with setTimeout")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let timeoutFired = false;
            let abortFired = false;
            
            const timeoutId = setTimeout(() => {
                timeoutFired = true;
                checkCompletion();
            }, 100);
            
            signal.addEventListener('abort', () => {
                abortFired = true;
                clearTimeout(timeoutId);
                checkCompletion();
            });
            
            function checkCompletion() {
                if (abortFired) {
                    testCompleted({
                        timeoutFired: timeoutFired,
                        abortFired: abortFired,
                        signalAborted: signal.aborted
                    });
                }
            }
            
            // Abort before timeout
            setTimeout(() => {
                controller.abort();
            }, 50);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["timeoutFired"].boolValue ?? true)
            XCTAssertTrue(result["abortFired"].boolValue ?? false)
            XCTAssertTrue(result["signalAborted"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testAbortListenerErrors() {
        let expectation = XCTestExpectation(description: "Abort listener error handling")
        
        let script = """
            const controller = new AbortController();
            const signal = controller.signal;
            
            let listener1Called = false;
            let listener2Called = false;
            
            signal.addEventListener('abort', () => {
                listener1Called = true;
                throw new Error('Listener 1 error');
            });
            
            signal.addEventListener('abort', () => {
                listener2Called = true;
            });
            
            setTimeout(() => {
                controller.abort();
                
                setTimeout(() => {
                    testCompleted({
                        listener1Called: listener1Called,
                        listener2Called: listener2Called,
                        bothCalled: listener1Called && listener2Called
                    });
                }, 50);
            }, 10);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertTrue(result["listener1Called"].boolValue ?? false)
            XCTAssertTrue(result["listener2Called"].boolValue ?? false)
            XCTAssertTrue(result["bothCalled"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testAbortSignalReuse() {
        let script = """
            const controller = new AbortController();
            const signal1 = controller.signal;
            const signal2 = controller.signal;
            
            ({
                sameSignal: signal1 === signal2,
                bothAbortedAfterAbort: () => {
                    controller.abort();
                    return signal1.aborted && signal2.aborted;
                }
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["sameSignal"].boolValue ?? false)
        
        let bothAbortedResult = result["bothAbortedAfterAbort"].invokeMethod("call", withArguments: [SwiftJS.Value.undefined])
        XCTAssertTrue(bothAbortedResult.boolValue ?? false)
    }
    
    func testAbortControllerProperties() {
        let script = """
            const controller = new AbortController();
            
            ({
                hasSignalProperty: 'signal' in controller,
                hasAbortMethod: 'abort' in controller,
                signalReadonly: (() => {
                    const originalSignal = controller.signal;
                    try {
                        controller.signal = new AbortSignal();
                        return controller.signal === originalSignal;
                    } catch (e) {
                        return true; // Throwing is also acceptable for readonly
                    }
                })(),
                abortMethodType: typeof controller.abort
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasSignalProperty"].boolValue ?? false)
        XCTAssertTrue(result["hasAbortMethod"].boolValue ?? false)
        XCTAssertTrue(result["signalReadonly"].boolValue ?? false)
        XCTAssertEqual(result["abortMethodType"].toString(), "function")
    }
    
    // MARK: - Performance Tests
    
    func testAbortControllerPerformance() {
        measure {
            let script = """
                var controllers = [];
                
                // Create many controllers
                for (var i = 0; i < 1000; i++) {
                    controllers.push(new AbortController());
                }
                
                // Add listeners to all
                for (var i = 0; i < controllers.length; i++) {
                    controllers[i].signal.addEventListener('abort', function() {
                        // Empty listener
                    });
                }
                
                // Abort all
                for (var i = 0; i < controllers.length; i++) {
                    controllers[i].abort();
                }
                
                // Verify all are aborted
                var allAborted = true;
                for (var i = 0; i < controllers.length; i++) {
                    if (!controllers[i].signal.aborted) {
                        allAborted = false;
                        break;
                    }
                }
                
                allAborted
            """
            let context = SwiftJS()
            let result = context.evaluateScript(script)
            XCTAssertTrue(result.boolValue ?? false)
        }
    }
}
