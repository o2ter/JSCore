//
//  Timer.kt
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

package com.o2ter.jscore.lib

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.primitive.V8ValueInteger
import com.caoccao.javet.values.primitive.V8ValueLong
import com.caoccao.javet.values.reference.V8ValueFunction
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.invokeFunction
import com.o2ter.jscore.PlatformContext
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Timer API implementation for JavaScript
 * Provides setTimeout, setInterval, and related timer functions
 */
class JSTimer(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    private val timer = Timer("JSCoreTimer", true)
    private val activeTimers = ConcurrentHashMap<Int, TimerTask>()
    private val nextTimerId = AtomicInteger(0)
    private lateinit var timerNamespace: V8ValueObject
    
    /**
     * Check if there are any active timers
     */
    val hasActiveTimers: Boolean
        get() = activeTimers.isNotEmpty()
    
    /**
     * Get the count of active timers
     */
    val activeTimerCount: Int
        get() = activeTimers.size
    
    /**
     * Setup timer bridge in the native bridge object
     * @param nativeBridge The native bridge object to register timer APIs
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        // Create timer namespace object directly without globalThis pollution
        val timerNamespaceCode = """
            (function() {
                // Private timer namespace - never exposed to globalThis
                const timerNamespace = {
                    callbacks: new Map(),
                    executeCallback: function(id) {
                        const callback = this.callbacks.get(id);
                        if (callback) {
                            this.callbacks.delete(id);
                            callback();
                        }
                    },
                    executeIntervalCallback: function(id) {
                        const callback = this.callbacks.get(id);
                        if (callback) {
                            callback();
                        }
                    },
                    clearCallback: function(id) {
                        this.callbacks.delete(id);
                    },
                    setCallback: function(id, callback) {
                        this.callbacks.set(id, callback);
                    }
                };
                return timerNamespace;
            })();
        """
        
        // Get the timer namespace object directly and store it for cleanup
        timerNamespace = v8Runtime.getExecutor(timerNamespaceCode).execute<V8ValueObject>()
        
        // Timer bridges - setTimeout
        val setTimeoutCallback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val id = nextTimerId.incrementAndGet()
            
            // Store callback using the timer namespace directly
            if (v8Values.isNotEmpty() && v8Values[0] is V8ValueFunction) {
                timerNamespace.invoke<V8Value>("setCallback", id, v8Values[0]).close()
            }
            
            val delay = if (v8Values.size > 1) {
                when (val delayValue = v8Values[1]) {
                    is V8ValueInteger -> delayValue.value.toLong()
                    is V8ValueLong -> delayValue.value
                    else -> 0L
                }
            } else 0L
            
            val task = object : TimerTask() {
                override fun run() {
                    try {
                        // Execute callback using the timer namespace directly
                        timerNamespace.invoke<V8Value>("executeCallback", id).close()
                    } catch (e: Exception) {
                        platformContext.logger.error("JSCore", "Timer execution failed: ${e.message}")
                    } finally {
                        activeTimers.remove(id)
                    }
                }
            }
            activeTimers[id] = task
            timer.schedule(task, delay)
            
            v8Runtime.createV8ValueInteger(id)
        }
        nativeBridge.bindFunction(JavetCallbackContext("setTimeout", JavetCallbackType.DirectCallNoThisAndResult, setTimeoutCallback))
        
        // clearTimeout
        val clearTimeoutCallback = IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
            val id = if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                (v8Values[0] as V8ValueInteger).value
            } else 0
            activeTimers.remove(id)?.cancel()
            timerNamespace.invoke<V8Value>("clearCallback", id).close()
        }
        nativeBridge.bindFunction(JavetCallbackContext("clearTimeout", JavetCallbackType.DirectCallNoThisAndNoResult, clearTimeoutCallback))
        
        // setInterval
        val setIntervalCallback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val id = nextTimerId.incrementAndGet()
            
            // Store callback using the timer namespace directly
            if (v8Values.isNotEmpty() && v8Values[0] is V8ValueFunction) {
                timerNamespace.invoke<V8Value>("setCallback", id, v8Values[0]).close()
            }
            
            val delay = if (v8Values.size > 1) {
                when (val delayValue = v8Values[1]) {
                    is V8ValueInteger -> delayValue.value.toLong()
                    is V8ValueLong -> delayValue.value
                    else -> 0L
                }
            } else 0L
            
            val task = object : TimerTask() {
                override fun run() {
                    try {
                        // For intervals, callback stays in the registry
                        timerNamespace.invoke<V8Value>("executeIntervalCallback", id).close()
                    } catch (e: Exception) {
                        platformContext.logger.error("JSCore", "Interval execution failed: ${e.message}")
                    }
                }
            }
            activeTimers[id] = task
            timer.schedule(task, delay, delay)
            
            v8Runtime.createV8ValueInteger(id)
        }
        nativeBridge.bindFunction(JavetCallbackContext("setInterval", JavetCallbackType.DirectCallNoThisAndResult, setIntervalCallback))
        
        // clearInterval
        val clearIntervalCallback = IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
            val id = if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                (v8Values[0] as V8ValueInteger).value
            } else 0
            activeTimers.remove(id)?.cancel()
            timerNamespace.invoke<V8Value>("clearCallback", id).close()
        }
        nativeBridge.bindFunction(JavetCallbackContext("clearInterval", JavetCallbackType.DirectCallNoThisAndNoResult, clearIntervalCallback))
        
        // Bridge timer functions to JavaScript
        v8Runtime.invokeFunction("""
            (function(nativeBridge) {
                if (!nativeBridge) return;
                
                globalThis.setTimeout = function(callback, delay, ...args) {
                    const wrappedCallback = args.length > 0 
                        ? function() { callback(...args); }
                        : callback;
                    return nativeBridge.setTimeout(wrappedCallback, delay || 0);
                };
                globalThis.clearTimeout = function(id) {
                    nativeBridge.clearTimeout(id);
                };
                globalThis.setInterval = function(callback, delay, ...args) {
                    const wrappedCallback = args.length > 0 
                        ? function() { callback(...args); }
                        : callback;
                    return nativeBridge.setInterval(wrappedCallback, delay || 0);
                };
                globalThis.clearInterval = function(id) {
                    nativeBridge.clearInterval(id);
                };
            })
        """.trimIndent(), nativeBridge).close()
    }
    
    /**
     * Cleanup all timers and release resources
     */
    fun close() {
        // Cancel all timers
        timer.cancel()
        activeTimers.values.forEach { it.cancel() }
        activeTimers.clear()
        
        // Clear all timer callbacks from the namespace to prevent memory leaks
        if (::timerNamespace.isInitialized && !timerNamespace.isClosed) {
            try {
                timerNamespace.get<V8ValueObject>("callbacks")?.use { callbacks ->
                    callbacks.invoke<V8Value>("clear", *emptyArray<Any>()).close()
                }
            } catch (e: Exception) {
                // Ignore cleanup errors
            }
            timerNamespace.close()
        }
    }
}
