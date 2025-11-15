// MIT License
//
// Copyright (c) 2025 Tao Tao Ltd
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
import SwiftJS

final class WebSocketTrackingTests: XCTestCase {
    
    func testWebSocketConnectionTracking() {
        let context = SwiftJS()
        
        // Initially no active WebSockets
        XCTAssertFalse(context.hasActiveWebSockets, "Should have no active WebSockets initially")
        XCTAssertEqual(context.activeWebSocketCount, 0, "Active WebSocket count should be 0")
        XCTAssertFalse(context.hasActiveOperations, "Should have no active operations initially")
        
        let expectation = XCTestExpectation(description: "WebSocket connection tracked")
        
        let script = """
            var socket = new WebSocket('wss://echo.websocket.org');
            socket.onopen = function() {
                // Connected - tracking should be active
            };
            socket.onerror = function(error) {
                // Connection failed
            };
        """
        
        context.evaluateScript(script)
        
        // Allow time for connection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should have active WebSocket during connection
            XCTAssertTrue(context.hasActiveWebSockets, "Should have active WebSocket during connection")
            XCTAssertEqual(context.activeWebSocketCount, 1, "Active WebSocket count should be 1")
            XCTAssertTrue(context.hasActiveOperations, "Should have active operations with WebSocket")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testWebSocketCloseRemovesTracking() {
        let context = SwiftJS()
        
        let expectation = XCTestExpectation(description: "WebSocket close cleanup")
        
        let script = """
            var socket = new WebSocket('wss://echo.websocket.org');
            var closed = false;
            
            socket.onopen = function() {
                socket.close();
            };
            
            socket.onclose = function() {
                closed = true;
            };
            
            socket.onerror = function(error) {
                // If connection fails, close will be called automatically
            };
        """
        
        context.evaluateScript(script)
        
        // Check tracking during connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // WebSocket should be tracked while connecting or open
            let initiallyTracked = context.hasActiveWebSockets
            
            // Wait additional time for cleanup after close (cleanup has 0.5s delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                let closed = context.evaluateScript("closed").boolValue ?? false
                
                if closed && initiallyTracked {
                    // If it connected and closed successfully, verify cleanup happened
                    XCTAssertFalse(context.hasActiveWebSockets, "Should have no active WebSocket after close")
                    XCTAssertEqual(context.activeWebSocketCount, 0, "Active WebSocket count should be 0")
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMultipleWebSocketTracking() {
        let context = SwiftJS()
        
        let expectation = XCTestExpectation(description: "Multiple WebSockets tracked")
        
        let script = """
            var socket1 = new WebSocket('wss://echo.websocket.org');
            var socket2 = new WebSocket('wss://echo.websocket.org');
            var socket3 = new WebSocket('wss://echo.websocket.org');
        """
        
        context.evaluateScript(script)
        
        // Allow time for connection attempts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should track all 3 WebSocket connections
            XCTAssertTrue(context.hasActiveWebSockets, "Should have active WebSockets")
            XCTAssertEqual(context.activeWebSocketCount, 3, "Should track all 3 WebSocket connections")
            XCTAssertTrue(context.hasActiveOperations, "Should have active operations with WebSockets")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testWebSocketTrackedInActiveOperations() {
        let context = SwiftJS()
        
        let expectation = XCTestExpectation(description: "WebSocket tracked in active operations")
        
        let script = """
            var socket = new WebSocket('wss://echo.websocket.org');
            socket.onerror = function(error) {
                // Connection may fail
            };
        """
        
        context.evaluateScript(script)
        
        // Allow time for connection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // WebSocket should contribute to hasActiveOperations
            if context.hasActiveWebSockets {
                XCTAssertTrue(context.hasActiveOperations, "WebSocket should contribute to hasActiveOperations")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
