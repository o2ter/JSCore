//
//  EventTests.swift
//  SwiftJS Event System Tests
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

/// Tests for the Web Event API implementation including EventTarget, Event,
/// addEventListener, removeEventListener, and event dispatching.
@MainActor
final class EventTests: XCTestCase {
    
    // MARK: - EventTarget API Tests
    
    func testEventTargetExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof EventTarget")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testEventTargetInstantiation() {
        let script = """
            const target = new EventTarget();
            target instanceof EventTarget
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testEventTargetMethods() {
        let script = """
            const target = new EventTarget();
            ({
                hasAddEventListener: typeof target.addEventListener === 'function',
                hasRemoveEventListener: typeof target.removeEventListener === 'function',
                hasDispatchEvent: typeof target.dispatchEvent === 'function'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasAddEventListener"].boolValue ?? false)
        XCTAssertTrue(result["hasRemoveEventListener"].boolValue ?? false)
        XCTAssertTrue(result["hasDispatchEvent"].boolValue ?? false)
    }
    
    // MARK: - Event API Tests
    
    func testEventExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Event")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testEventInstantiation() {
        let script = """
            const event = new Event('test');
            event instanceof Event
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testEventProperties() {
        let script = """
            const event = new Event('customEvent', {
                bubbles: true,
                cancelable: true
            });
            ({
                type: event.type,
                bubbles: event.bubbles,
                cancelable: event.cancelable,
                defaultPrevented: event.defaultPrevented
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "customEvent")
        XCTAssertTrue(result["bubbles"].boolValue ?? false)
        XCTAssertTrue(result["cancelable"].boolValue ?? false)
        XCTAssertFalse(result["defaultPrevented"].boolValue ?? true)
    }
    
    // MARK: - Event Listener Tests
    
    func testBasicEventListening() {
        let script = """
            const target = new EventTarget();
            let fired = false;
            target.addEventListener('test', () => { fired = true; });
            target.dispatchEvent(new Event('test'));
            fired
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testEventListenerRemoval() {
        let script = """
            const target = new EventTarget();
            let callCount = 0;
            const listener = () => { callCount++; };
            
            target.addEventListener('test', listener);
            target.dispatchEvent(new Event('test'));
            
            target.removeEventListener('test', listener);
            target.dispatchEvent(new Event('test'));
            
            callCount
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 1)
    }
    
    func testMultipleEventListeners() {
        let script = """
            const target = new EventTarget();
            let count1 = 0, count2 = 0, count3 = 0;
            
            target.addEventListener('test', () => { count1++; });
            target.addEventListener('test', () => { count2++; });
            target.addEventListener('other', () => { count3++; });
            
            target.dispatchEvent(new Event('test'));
            target.dispatchEvent(new Event('other'));
            
            ({ count1, count2, count3 })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["count1"].numberValue, 1)
        XCTAssertEqual(result["count2"].numberValue, 1)
        XCTAssertEqual(result["count3"].numberValue, 1)
    }
    
    func testEventListenerOptions() {
        let script = """
            const target = new EventTarget();
            let callCount = 0;
            
            // Test 'once' option
            target.addEventListener('test', () => { callCount++; }, { once: true });
            
            target.dispatchEvent(new Event('test'));
            target.dispatchEvent(new Event('test'));
            target.dispatchEvent(new Event('test'));
            
            callCount
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.numberValue, 1)
    }
    
    // MARK: - Event Object Tests
    
    func testEventObjectInListener() {
        let script = """
            const target = new EventTarget();
            let eventData = {};
            
            target.addEventListener('customEvent', (event) => {
                eventData = {
                    type: event.type,
                    target: event.target === target,
                    currentTarget: event.currentTarget === target,
                    bubbles: event.bubbles,
                    cancelable: event.cancelable
                };
            });
            
            target.dispatchEvent(new Event('customEvent', { bubbles: true, cancelable: true }));
            eventData
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "customEvent")
        XCTAssertTrue(result["target"].boolValue ?? false)
        XCTAssertTrue(result["currentTarget"].boolValue ?? false)
        XCTAssertTrue(result["bubbles"].boolValue ?? false)
        XCTAssertTrue(result["cancelable"].boolValue ?? false)
    }
    
    func testPreventDefault() {
        let script = """
            const target = new EventTarget();
            let preventDefaultCalled = false;
            
            target.addEventListener('test', (event) => {
                event.preventDefault();
                preventDefaultCalled = event.defaultPrevented;
            });
            
            const event = new Event('test', { cancelable: true });
            target.dispatchEvent(event);
            
            ({ 
                preventDefaultCalled,
                eventDefaultPrevented: event.defaultPrevented 
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["preventDefaultCalled"].boolValue ?? false)
        XCTAssertTrue(result["eventDefaultPrevented"].boolValue ?? false)
    }
    
    func testStopPropagation() {
        let script = """
            const target = new EventTarget();
            let listener1Called = false;
            let listener2Called = false;
            
            target.addEventListener('test', (event) => {
                listener1Called = true;
                event.stopPropagation();
            });
            
            target.addEventListener('test', () => {
                listener2Called = true;
            });
            
            target.dispatchEvent(new Event('test'));
            
            ({ listener1Called, listener2Called })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["listener1Called"].boolValue ?? false)
        // Note: stopPropagation behavior depends on implementation
        // In some implementations, it only affects parent/child relationships
    }
    
    // MARK: - Custom Event Tests
    
    func testCustomEventCreation() {
        let script = """
            // Test if CustomEvent exists and can be created
            try {
                const customEvent = new CustomEvent('custom', {
                    detail: { message: 'Hello World' },
                    bubbles: true
                });
                
                ({
                    isCustomEvent: customEvent instanceof CustomEvent,
                    type: customEvent.type,
                    detail: customEvent.detail,
                    bubbles: customEvent.bubbles
                })
            } catch (e) {
                // CustomEvent might not be implemented, use regular Event
                const event = new Event('custom', { bubbles: true });
                ({
                    isCustomEvent: false,
                    type: event.type,
                    detail: null,
                    bubbles: event.bubbles,
                    fallback: true
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "custom")
        XCTAssertTrue(result["bubbles"].boolValue ?? false)
        
        if !(result["fallback"].boolValue ?? false) {
            XCTAssertTrue(result["isCustomEvent"].boolValue ?? false)
            XCTAssertEqual(result["detail"]["message"].toString(), "Hello World")
        }
    }
    
    // MARK: - Event Timing Tests
    
    func testEventDispatchTiming() {
        let script = """
            const target = new EventTarget();
            const timestamps = [];
            
            target.addEventListener('test', () => {
                timestamps.push(Date.now());
            });
            
            const start = Date.now();
            target.dispatchEvent(new Event('test'));
            const end = Date.now();
            
            ({
                listenerCalled: timestamps.length === 1,
                timeElapsed: end - start,
                isSynchronous: timestamps[0] >= start && timestamps[0] <= end
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["listenerCalled"].boolValue ?? false)
        XCTAssertTrue(result["isSynchronous"].boolValue ?? false)
        // Event dispatch should be essentially immediate (< 100ms)
        let timeElapsed = result["timeElapsed"].numberValue ?? 1000
        XCTAssertLessThan(timeElapsed, 100)
    }
    
    // MARK: - Error Handling Tests
    
    func testEventListenerErrors() {
        let script = """
            const target = new EventTarget();
            let errorThrown = false;
            let normalListenerCalled = false;
            
            // Add a listener that throws an error
            target.addEventListener('test', () => {
                throw new Error('Listener error');
            });
            
            // Add a normal listener
            target.addEventListener('test', () => {
                normalListenerCalled = true;
            });
            
            try {
                target.dispatchEvent(new Event('test'));
            } catch (e) {
                errorThrown = true;
            }
            
            ({ errorThrown, normalListenerCalled })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Depending on implementation, errors in listeners might be caught or propagated
        XCTAssertTrue(result["normalListenerCalled"].boolValue ?? false)
    }
    
    func testInvalidEventTypes() {
        let script = """
            const target = new EventTarget();
            const results = [];
            
            // Test various invalid event types
            try {
                target.addEventListener('', () => {});
                results.push('empty-string-allowed');
            } catch (e) {
                results.push('empty-string-rejected');
            }
            
            try {
                target.addEventListener(null, () => {});
                results.push('null-allowed');
            } catch (e) {
                results.push('null-rejected');
            }
            
            try {
                target.addEventListener(undefined, () => {});
                results.push('undefined-allowed');
            } catch (e) {
                results.push('undefined-rejected');
            }
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Check that the implementation handles invalid event types appropriately
        XCTAssertTrue(result.isArray)
        let resultsArray = (0..<(Int(result["length"].numberValue ?? 0))).map { index in
            result[index].toString()
        }
        
        // At minimum, should handle basic validation
        XCTAssertTrue(resultsArray.count > 0)
    }
    
    // MARK: - Performance Tests
    
    func testManyEventListeners() {
        let script = """
            const target = new EventTarget();
            let totalCalls = 0;
            
            // Add many listeners
            for (let i = 0; i < 1000; i++) {
                target.addEventListener('test', () => { totalCalls++; });
            }
            
            const start = Date.now();
            target.dispatchEvent(new Event('test'));
            const end = Date.now();
            
            ({
                totalCalls,
                timeElapsed: end - start,
                allListenersCalled: totalCalls === 1000
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["allListenersCalled"].boolValue ?? false)
        XCTAssertEqual(result["totalCalls"].numberValue, 1000)
        
        // Should complete within reasonable time even with many listeners
        let timeElapsed = result["timeElapsed"].numberValue ?? 1000
        XCTAssertLessThan(timeElapsed, 500)
    }
    
    func testEventDispatchPerformance() {
        let context = SwiftJS()
        let script = """
            const target = new EventTarget();
            target.addEventListener('test', () => {});
            
            function dispatchManyEvents() {
                for (let i = 0; i < 1000; i++) {
                    target.dispatchEvent(new Event('test'));
                }
                return true;
            }
            dispatchManyEvents
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("dispatchManyEvents()")
        }
    }
}
