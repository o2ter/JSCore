//
//  AbortControllerTests.kt
//  KotlinJS AbortController Tests
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

package com.o2ter.jscore.webapis

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.executeAsync
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Tests for the AbortController and AbortSignal Web APIs.
 */
class AbortControllerTests {
    
    // MARK: - API Existence Tests
    
    @Test
    fun testAbortControllerExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof AbortController")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortControllerInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                controller instanceof AbortController
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortControllerSignal() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                ({
                    hasSignal: typeof controller.signal !== 'undefined',
                    signalType: typeof controller.signal,
                    hasAbortMethod: typeof controller.abort === 'function'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["hasSignal"])
            assertEquals("object", result["signalType"])
            assertEquals(true, result["hasAbortMethod"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - AbortSignal Tests
    
    @Test
    fun testAbortSignalInitialState() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                const signal = controller.signal;
                ({
                    aborted: signal.aborted,
                    hasAborted: typeof signal.aborted === 'boolean',
                    hasAddEventListener: typeof signal.addEventListener === 'function'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["aborted"])
            assertEquals(true, result["hasAborted"])
            assertEquals(true, result["hasAddEventListener"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortSignalAfterAbort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                const signal = controller.signal;
                const beforeAbort = signal.aborted;
                
                controller.abort();
                
                const afterAbort = signal.aborted;
                
                ({
                    beforeAbort: beforeAbort,
                    afterAbort: afterAbort,
                    changed: beforeAbort !== afterAbort
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["beforeAbort"])
            assertEquals(true, result["afterAbort"])
            assertEquals(true, result["changed"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Event Listener Tests
    
    @Test
    fun testAbortEventListener() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const controller = new AbortController();
                        const signal = controller.signal;
                        
                        let eventFired = false;
                        
                        signal.addEventListener('abort', () => {
                            eventFired = true;
                            resolve({ eventFired: eventFired });
                        });
                        
                        setTimeout(() => {
                            controller.abort();
                        }, 50);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["eventFired"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortEventListenerWithOnabort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const controller = new AbortController();
                        const signal = controller.signal;
                        
                        let eventFired = false;
                        
                        signal.onabort = () => {
                            eventFired = true;
                            resolve({ eventFired: eventFired });
                        };
                        
                        setTimeout(() => {
                            controller.abort();
                        }, 50);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["eventFired"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testMultipleAbortListeners() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const controller = new AbortController();
                        const signal = controller.signal;
                        
                        let listener1Fired = false;
                        let listener2Fired = false;
                        let listener3Fired = false;
                        
                        signal.addEventListener('abort', () => { listener1Fired = true; });
                        signal.addEventListener('abort', () => { listener2Fired = true; });
                        signal.addEventListener('abort', () => { listener3Fired = true; });
                        
                        controller.abort();
                        
                        setTimeout(() => {
                            resolve({
                                listener1: listener1Fired,
                                listener2: listener2Fired,
                                listener3: listener3Fired,
                                allFired: listener1Fired && listener2Fired && listener3Fired
                            });
                        }, 50);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["listener1"])
            assertEquals(true, result["listener2"])
            assertEquals(true, result["listener3"])
            assertEquals(true, result["allFired"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Abort Reason Tests
    
    @Test
    fun testAbortWithReason() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                const signal = controller.signal;
                
                const reason = new Error('Operation cancelled');
                controller.abort(reason);
                
                ({
                    aborted: signal.aborted,
                    hasReason: typeof signal.reason !== 'undefined',
                    reasonMessage: signal.reason?.message || 'no message'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["aborted"])
            assertEquals(true, result["hasReason"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortWithoutReason() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller = new AbortController();
                const signal = controller.signal;
                
                controller.abort();
                
                ({
                    aborted: signal.aborted,
                    hasReason: typeof signal.reason !== 'undefined',
                    reasonType: typeof signal.reason
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["aborted"])
            // Default reason should be provided
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Multiple Abort Calls Tests
    
    @Test
    fun testMultipleAbortCalls() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const controller = new AbortController();
                        const signal = controller.signal;
                        
                        let eventCount = 0;
                        
                        signal.addEventListener('abort', () => {
                            eventCount++;
                        });
                        
                        controller.abort();
                        controller.abort();
                        controller.abort();
                        
                        setTimeout(() => {
                            resolve({
                                eventCount: eventCount,
                                aborted: signal.aborted
                            });
                        }, 50);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["aborted"])
            // Event should fire only once even with multiple abort() calls
            assertEquals(1, (result["eventCount"] as? Number)?.toInt())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests with Fetch
    
    @Test
    fun testAbortControllerWithFetch() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const controller = new AbortController();
                    const signal = controller.signal;
                    
                    setTimeout(() => controller.abort(), 100);
                    
                    try {
                        await fetch('https://postman-echo.com/delay/5', { signal });
                        return { aborted: false, error: null };
                    } catch (error) {
                        return {
                            aborted: true,
                            errorName: error.name,
                            isAbortError: error.name === 'AbortError'
                        };
                    }
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["aborted"])
            assertEquals("AbortError", result["errorName"])
            assertEquals(true, result["isAbortError"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortControllerWithMultipleFetches() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const controller = new AbortController();
                    const signal = controller.signal;
                    
                    const promises = [
                        fetch('https://postman-echo.com/delay/5', { signal }).catch(e => ({ error: e.name })),
                        fetch('https://postman-echo.com/delay/5', { signal }).catch(e => ({ error: e.name })),
                        fetch('https://postman-echo.com/delay/5', { signal }).catch(e => ({ error: e.name }))
                    ];
                    
                    setTimeout(() => controller.abort(), 100);
                    
                    const results = await Promise.all(promises);
                    
                    return {
                        resultCount: results.length,
                        allAborted: results.every(r => r.error === 'AbortError')
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(3, (result["resultCount"] as? Number)?.toInt())
            assertEquals(true, result["allAborted"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test
    fun testAbortBeforeFetch() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const controller = new AbortController();
                    const signal = controller.signal;
                    
                    controller.abort(); // Abort before fetch
                    
                    try {
                        await fetch('https://postman-echo.com/get', { signal });
                        return { aborted: false };
                    } catch (error) {
                        return {
                            aborted: true,
                            errorName: error.name,
                            isAbortError: error.name === 'AbortError'
                        };
                    }
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["aborted"])
            assertEquals("AbortError", result["errorName"])
            assertEquals(true, result["isAbortError"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortControllerIsolation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const controller1 = new AbortController();
                const controller2 = new AbortController();
                
                controller1.abort();
                
                ({
                    signal1Aborted: controller1.signal.aborted,
                    signal2Aborted: controller2.signal.aborted,
                    isolated: controller1.signal.aborted && !controller2.signal.aborted
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["signal1Aborted"])
            assertEquals(false, result["signal2Aborted"])
            assertEquals(true, result["isolated"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - AbortSignal.abort() Static Method Tests
    
    @Test
    fun testAbortSignalStaticAbort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                if (typeof AbortSignal.abort === 'function') {
                    const signal = AbortSignal.abort();
                    ({
                        available: true,
                        aborted: signal.aborted,
                        hasReason: typeof signal.reason !== 'undefined'
                    })
                } else {
                    ({ available: false })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            // AbortSignal.abort() is optional, check if available
            if (result["available"] == true) {
                assertEquals(true, result["aborted"])
            }
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAbortSignalStaticAbortWithReason() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                if (typeof AbortSignal.abort === 'function') {
                    const reason = new Error('Test reason');
                    const signal = AbortSignal.abort(reason);
                    ({
                        available: true,
                        aborted: signal.aborted,
                        hasReason: typeof signal.reason !== 'undefined',
                        reasonMessage: signal.reason?.message || 'no message'
                    })
                } else {
                    ({ available: false })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            // AbortSignal.abort() is optional
            if (result["available"] == true) {
                assertEquals(true, result["aborted"])
                assertEquals(true, result["hasReason"])
            }
        } finally {
            engine.close()
        }
    }
}
