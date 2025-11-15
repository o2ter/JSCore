//
//  WebSocketTests.kt
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

package com.o2ter.jscore.network

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import com.o2ter.jscore.executeAsync
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class WebSocketTests {
    
    @Test
    fun testWebSocketExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof WebSocket")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketConstants() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    connecting: WebSocket.CONNECTING,
                    open: WebSocket.OPEN,
                    closing: WebSocket.CLOSING,
                    closed: WebSocket.CLOSED
                })
            """.trimIndent()) as? Map<*, *>
            
            assertNotNull(result)
            val connecting = (result!!["connecting"] as Number).toDouble()
            val open = (result["open"] as Number).toDouble()
            val closing = (result["closing"] as Number).toDouble()
            val closed = (result["closed"] as Number).toDouble()
            
            assertEquals(0.0, connecting)
            assertEquals(1.0, open)
            assertEquals(2.0, closing)
            assertEquals(3.0, closed)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        try {
                            const ws = new WebSocket('wss://echo.websocket.org');
                            const result = {
                                hasUrl: typeof ws.url === 'string',
                                hasReadyState: typeof ws.readyState === 'number',
                                hasBufferedAmount: typeof ws.bufferedAmount === 'number',
                                hasSend: typeof ws.send === 'function',
                                hasClose: typeof ws.close === 'function',
                                initialState: ws.readyState
                            };
                            ws.close();
                            resolve(result);
                        } catch (error) {
                            reject(error);
                        }
                    });
                })()
            """.trimIndent(), timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result!!["hasUrl"])
            assertEquals(true, result["hasReadyState"])
            assertEquals(true, result["hasBufferedAmount"])
            assertEquals(true, result["hasSend"])
            assertEquals(true, result["hasClose"])
            assertEquals(0.0, (result["initialState"] as Number).toDouble())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketConnection() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const ws = new WebSocket('wss://echo.websocket.org');
                        let openFired = false;
                        
                        ws.onopen = function() {
                            openFired = true;
                            resolve({
                                opened: true,
                                readyState: ws.readyState
                            });
                            ws.close();
                        };
                        
                        ws.onerror = function(event) {
                            reject(new Error('Connection error'));
                        };
                        
                        setTimeout(() => {
                            if (!openFired) {
                                ws.close();
                                reject(new Error('Connection timeout'));
                            }
                        }, 10000);
                    });
                })()
            """.trimIndent(), timeoutMs = 15000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result!!["opened"])
            assertEquals(1.0, (result["readyState"] as Number).toDouble())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketSendReceiveText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const ws = new WebSocket('wss://echo.websocket.org');
                        const testMessage = 'Hello WebSocket!';
                        let messageReceived = false;
                        
                        ws.onopen = function() {
                            ws.send(testMessage);
                        };
                        
                        ws.onmessage = function(event) {
                            messageReceived = true;
                            resolve({
                                success: true,
                                messageReceived: typeof event.data === 'string'
                            });
                            ws.close();
                        };
                        
                        ws.onerror = function() {
                            reject(new Error('Connection error'));
                        };
                        
                        setTimeout(() => {
                            if (!messageReceived) {
                                ws.close();
                                reject(new Error('Message timeout'));
                            }
                        }, 10000);
                    });
                })()
            """.trimIndent(), timeoutMs = 15000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result!!["success"])
            assertEquals(true, result["messageReceived"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketClose() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const ws = new WebSocket('wss://echo.websocket.org');
                        let closeFired = false;
                        
                        ws.onopen = function() {
                            ws.close(1000, 'Normal closure');
                        };
                        
                        ws.onclose = function(event) {
                            closeFired = true;
                            resolve({
                                closed: true,
                                code: event.code,
                                reason: event.reason,
                                wasClean: event.wasClean,
                                readyState: ws.readyState
                            });
                        };
                        
                        ws.onerror = function() {
                            reject(new Error('Connection error'));
                        };
                        
                        setTimeout(() => {
                            if (!closeFired) {
                                reject(new Error('Close timeout'));
                            }
                        }, 10000);
                    });
                })()
            """.trimIndent(), timeoutMs = 15000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result!!["closed"])
            assertEquals(1000.0, (result["code"] as Number).toDouble())
            assertEquals(true, result["wasClean"])
            assertEquals(3.0, (result["readyState"] as Number).toDouble())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketBinaryType() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const ws = new WebSocket('wss://echo.websocket.org');
                const initialType = ws.binaryType;
                ws.binaryType = 'arraybuffer';
                const newType = ws.binaryType;
                ws.close();
                
                ({
                    initialType: initialType,
                    newType: newType
                })
            """.trimIndent()) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("blob", result!!["initialType"])
            assertEquals("arraybuffer", result["newType"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketInvalidURL() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            // Invalid protocol should be rejected by polyfill validation
            val script = """
                let errorCaught = false;
                try {
                    new WebSocket('http://invalid-protocol.com');
                } catch (e) {
                    errorCaught = e.message.includes('invalid');
                }
                errorCaught;
            """.trimIndent()
            val result = engine.execute(script)
            assertEquals(true, result, "Should catch error for invalid protocol")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWebSocketEventListeners() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const ws = new WebSocket('wss://echo.websocket.org');
                        let openCount = 0;
                        
                        ws.addEventListener('open', function() {
                            openCount++;
                            if (openCount === 1) {
                                resolve({
                                    eventListenerWorks: true,
                                    openCount: openCount
                                });
                                ws.close();
                            }
                        });
                        
                        ws.onerror = function() {
                            reject(new Error('Connection error'));
                        };
                        
                        setTimeout(() => {
                            if (openCount === 0) {
                                ws.close();
                                reject(new Error('Open timeout'));
                            }
                        }, 10000);
                    });
                })()
            """.trimIndent(), timeoutMs = 15000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result!!["eventListenerWorks"])
            assertEquals(1.0, (result["openCount"] as Number).toDouble())
        } finally {
            engine.close()
        }
    }
}
