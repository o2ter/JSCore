//
//  TimerTests.kt
//  KotlinJS Timer API Tests
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
 * Tests for the Web Timer API including setTimeout, setInterval, 
 * clearTimeout, and clearInterval functions.
 */
class TimerTests {
    
    // MARK: - Timer API Existence Tests
    
    @Test
    fun testTimerAPIExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            assertEquals("function", engine.execute("typeof setTimeout").toString())
            assertEquals("function", engine.execute("typeof setInterval").toString())
            assertEquals("function", engine.execute("typeof clearTimeout").toString())
            assertEquals("function", engine.execute("typeof clearInterval").toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTimerFunctionality() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                typeof setTimeout === 'function' &&
                typeof clearTimeout === 'function' &&
                typeof setInterval === 'function' &&
                typeof clearInterval === 'function'
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - setTimeout Tests
    
    @Test
    fun testSetTimeoutBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const timeoutId = setTimeout(() => {}, 100);
                    typeof timeoutId !== 'undefined'
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testSetTimeoutExecution() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        let timeoutExecuted = false;
                        setTimeout(() => {
                            timeoutExecuted = true;
                            resolve({ executed: timeoutExecuted });
                        }, 50);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["executed"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testSetTimeoutWithArguments() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        setTimeout((arg1, arg2, arg3) => {
                            resolve({
                                arg1: arg1,
                                arg2: arg2,
                                arg3: arg3
                            });
                        }, 50, 'hello', 42, true);
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("hello", result["arg1"].toString())
            assertEquals(42, (result["arg2"] as? Number)?.toInt())
            assertEquals(true, result["arg3"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testSetTimeoutZeroDelay() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        let executionOrder = [];
                        
                        executionOrder.push('start');
                        
                        setTimeout(() => {
                            executionOrder.push('timeout');
                            resolve({ order: executionOrder });
                        }, 0);
                        
                        executionOrder.push('end');
                    });
                })()
            """, timeoutMs = 2000) as? Map<*, *>
            
            assertNotNull(result)
            val order = result["order"] as? List<*>
            assertNotNull(order)
            assertEquals("start", order[0])
            assertEquals("end", order[1])
            assertEquals("timeout", order[2])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - clearTimeout Tests
    
    @Test
    fun testClearTimeout() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        let timeoutExecuted = false;
                        
                        const timeoutId = setTimeout(() => {
                            timeoutExecuted = true;
                        }, 100);
                        
                        clearTimeout(timeoutId);
                        
                        // Wait longer than the timeout to verify it was cancelled
                        setTimeout(() => {
                            resolve({ executed: timeoutExecuted });
                        }, 200);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["executed"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testClearTimeoutInvalidId() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    clearTimeout(99999);
                    clearTimeout(-1);
                    clearTimeout(null);
                    clearTimeout(undefined);
                    true // Should not throw
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - setInterval Tests
    
    @Test
    fun testSetIntervalBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const intervalId = setInterval(() => {}, 100);
                    clearInterval(intervalId); // Clean up immediately
                    typeof intervalId !== 'undefined'
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testSetIntervalExecution() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        let callCount = 0;
                        
                        const intervalId = setInterval(() => {
                            callCount++;
                            if (callCount >= 3) {
                                clearInterval(intervalId);
                                resolve({ callCount: callCount });
                            }
                        }, 50);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            assertTrue((result["callCount"] as? Number)?.toInt() ?: 0 >= 3)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testSetIntervalWithArguments() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        let receivedArgs = [];
                        
                        const intervalId = setInterval((arg1, arg2) => {
                            receivedArgs.push({ arg1, arg2 });
                            if (receivedArgs.length >= 2) {
                                clearInterval(intervalId);
                                resolve({ 
                                    firstCall: receivedArgs[0],
                                    secondCall: receivedArgs[1]
                                });
                            }
                        }, 50, 'test', 123);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            val firstCall = result["firstCall"] as? Map<*, *>
            val secondCall = result["secondCall"] as? Map<*, *>
            assertNotNull(firstCall)
            assertNotNull(secondCall)
            assertEquals("test", firstCall["arg1"])
            assertEquals(123, (firstCall["arg2"] as? Number)?.toInt())
            assertEquals("test", secondCall["arg1"])
            assertEquals(123, (secondCall["arg2"] as? Number)?.toInt())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - clearInterval Tests
    
    @Test
    fun testClearInterval() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
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
                            resolve({ callCount: callCount });
                        }, 200);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            val callCount = (result["callCount"] as? Number)?.toInt() ?: 0
            // Should have been called 1-2 times before being cleared
            assertTrue(callCount > 0)
            assertTrue(callCount < 5)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testClearIntervalInvalidId() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    clearInterval(99999);
                    clearInterval(-1);
                    clearInterval(null);
                    clearInterval(undefined);
                    true // Should not throw
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Timer ID Tests
    
    @Test
    fun testTimerIdUniqueness() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
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
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["allDefined"])
            assertEquals(true, result["allUnique"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Timer Precision Tests
    
    @Test
    fun testTimerPrecision() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const startTime = Date.now();
                        const expectedDelay = 100;
                        
                        setTimeout(() => {
                            const endTime = Date.now();
                            const actualDelay = endTime - startTime;
                            const precision = Math.abs(actualDelay - expectedDelay);
                            
                            resolve({
                                expectedDelay: expectedDelay,
                                actualDelay: actualDelay,
                                precision: precision,
                                isReasonablyAccurate: precision < 50 // Within 50ms
                            });
                        }, expectedDelay);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(100, (result["expectedDelay"] as? Number)?.toInt())
            
            val actualDelay = (result["actualDelay"] as? Number)?.toDouble() ?: 0.0
            assertTrue(actualDelay > 90) // Should be at least close to expected
            
            val precision = (result["precision"] as? Number)?.toDouble() ?: 1000.0
            assertTrue(precision < 100) // Should be reasonably accurate
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testTimerWithInvalidCallback() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
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
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(3, result.size)
            
            // Should handle invalid callbacks appropriately (either accept and convert or reject)
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("accepted") || resultStr.contains("rejected"))
            }
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTimerWithInvalidDelay() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
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
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(3, result.size)
            
            // Should handle invalid delays gracefully
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("accepted") || resultStr.contains("rejected"))
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test
    fun testTimersWithOtherAPIs() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
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
                            
                            resolve({ results: results });
                        }, 50);
                    });
                })()
            """, timeoutMs = 3000) as? Map<*, *>
            
            assertNotNull(result)
            val results = result["results"] as? List<*>
            assertNotNull(results)
            assertEquals(3, results.size)
            
            val result0 = results[0] as? Map<*, *>
            assertNotNull(result0)
            assertEquals("crypto", result0["api"])
            assertEquals("string", result0["result"])
            
            val result1 = results[1] as? Map<*, *>
            assertNotNull(result1)
            assertEquals("console", result1["api"])
            assertEquals("executed", result1["result"])
            
            val result2 = results[2] as? Map<*, *>
            assertNotNull(result2)
            assertEquals("textEncoder", result2["api"])
            assertEquals(true, result2["result"])
        } finally {
            engine.close()
        }
    }
}
