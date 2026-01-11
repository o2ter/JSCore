//
//  Console.kt
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
import com.caoccao.javet.values.reference.V8ValueObject
import com.o2ter.jscore.PlatformContext
import com.o2ter.jscore.invokeFunction

/**
 * Console API implementation for JavaScript
 * Bridges JavaScript console methods to platform logging
 */
class Console(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    
    /**
     * Setup console bridge in the native bridge object
     * @param nativeBridge The native bridge object to register console APIs
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        // Console API bridges
        nativeBridge.bindFunction(JavetCallbackContext("consoleLog", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.info("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleError", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                if (v8Values.size == 1) {
                    val value = v8Values[0]
                    if (value is V8ValueObject) {
                        val message = value.getString("message") ?: "Unknown Error"
                        val stack = value.getString("stack") ?: "No Stack Trace"
                        platformContext.logger.error("JSConsole", "$message\n$stack")
                        return@NoThisAndNoResult
                    }
                }
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.error("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleWarn", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.warning("JSConsole", message)
            }))
        nativeBridge.bindFunction(JavetCallbackContext("consoleDebug", JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                val message = v8Values.joinToString(" ") { it.toString() }
                platformContext.logger.debug("JSConsole", message)
            }))
        
        // Setup console forwarding
        v8Runtime.invokeFunction("""
            (function(nativeBridge) {
                if (!nativeBridge) return;
                
                globalThis.console = {
                    log: function(...args) { nativeBridge.consoleLog.apply(null, args); },
                    error: function(...args) { nativeBridge.consoleError.apply(null, args); },
                    warn: function(...args) { nativeBridge.consoleWarn.apply(null, args); },
                    debug: function(...args) { nativeBridge.consoleDebug.apply(null, args); },
                    info: function(...args) { nativeBridge.consoleLog.apply(null, args); }
                };
            })
        """.trimIndent(), nativeBridge).close()
    }
}
