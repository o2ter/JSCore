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

package com.o2ter.jscore.webapis

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class WebSocketTrackingTests {
    
    @Test
    fun testWebSocketConnectionTracking() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Initially no active WebSockets
        assertFalse(engine.hasActiveWebSockets, "Should have no active WebSockets initially")
        assertEquals(0, engine.activeWebSocketCount, "Active WebSocket count should be 0")
        assertFalse(engine.hasActiveOperations, "Should have no active operations initially")
        
        engine.execute("""
            var socket = new WebSocket('wss://echo.websocket.org');
            socket.onerror = function(error) {
                // Connection may fail
            };
        """)
        
        // Allow time for connection attempt
        Thread.sleep(500)
        
        // Should have active WebSocket during connection
        assertTrue(engine.hasActiveWebSockets, "Should have active WebSocket during connection")
        assertEquals(1, engine.activeWebSocketCount, "Active WebSocket count should be 1")
        assertTrue(engine.hasActiveOperations, "Should have active operations with WebSocket")
        
        engine.close()
    }
    
    @Test
    fun testWebSocketCloseRemovesTracking() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        engine.execute("""
            var socket = new WebSocket('wss://echo.websocket.org');
            var socketClosed = false;
            
            socket.onopen = function() {
                socket.close();
            };
            
            socket.onclose = function() {
                socketClosed = true;
            };
            
            socket.onerror = function(error) {
                // Connection may fail
            };
        """)
        
        // Check tracking during connection
        Thread.sleep(500)
        assertTrue(engine.hasActiveWebSockets, "Should have active WebSocket during connection")
        
        // Wait for close and cleanup
        Thread.sleep(3000)
        
        val isClosed = engine.execute("socketClosed")?.toString()?.toBoolean() ?: false
        if (isClosed) {
            assertFalse(engine.hasActiveWebSockets, "Should have no active WebSocket after close")
            assertEquals(0, engine.activeWebSocketCount, "Active WebSocket count should be 0 after close")
        }
        
        engine.close()
    }
    
    @Test
    fun testMultipleWebSocketTracking() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        engine.execute("""
            var socket1 = new WebSocket('wss://echo.websocket.org');
            var socket2 = new WebSocket('wss://echo.websocket.org');
            var socket3 = new WebSocket('wss://echo.websocket.org');
        """)
        
        // Allow time for connection attempts
        Thread.sleep(500)
        
        // Should track all 3 WebSocket connections
        assertTrue(engine.hasActiveWebSockets, "Should have active WebSockets")
        assertEquals(3, engine.activeWebSocketCount, "Should track all 3 WebSocket connections")
        assertTrue(engine.hasActiveOperations, "Should have active operations with WebSockets")
        
        engine.close()
    }
    
    @Test
    fun testWebSocketTrackedInActiveOperations() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        engine.execute("""
            var socket = new WebSocket('wss://echo.websocket.org');
            socket.onerror = function(error) {
                // Connection may fail
            };
        """)
        
        // Allow time for connection attempt
        Thread.sleep(500)
        
        // WebSocket should contribute to hasActiveOperations
        if (engine.hasActiveWebSockets) {
            assertTrue(engine.hasActiveOperations, "WebSocket should contribute to hasActiveOperations")
        }
        
        engine.close()
    }
}
