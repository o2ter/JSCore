//
//  TestHelpers.kt
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

package com.o2ter.jscore

/**
 * Helper function to execute async JavaScript and wait for the result.
 * This is needed because engine.execute() returns a Promise object immediately,
 * not the resolved value. This helper polls for completion with a timeout.
 *
 * @param engine The JavaScriptEngine instance
 * @param script The async JavaScript code to execute (should be an async IIFE or Promise)
 * @param timeoutMs Maximum time to wait for completion in milliseconds
 * @return The resolved value from the async operation
 * @throws RuntimeException if the operation times out or encounters an error
 */
fun executeAsync(engine: JavaScriptEngine, script: String, timeoutMs: Long = 5000): Any? {
    // Setup global variables to track async completion
    engine.execute("""
        globalThis._testResult = undefined;
        globalThis._testError = undefined;
        globalThis._testCompleted = false;
    """)
    
    // Execute the async script and capture result/error
    engine.execute("""
        (async () => {
            try {
                globalThis._testResult = await ($script);
            } catch (e) {
                globalThis._testError = e;
            } finally {
                globalThis._testCompleted = true;
            }
        })();
    """)
    
    // Poll for completion with timeout
    val startTime = System.currentTimeMillis()
    while (System.currentTimeMillis() - startTime < timeoutMs) {
        // Give V8 a chance to process microtasks (promises) by executing a dummy script
        // This pumps the microtask queue, allowing promise callbacks to execute
        engine.execute("void 0")
        
        val completed = engine.execute("globalThis._testCompleted")
        if (completed == true) {
            val error = engine.execute("globalThis._testError")
            if (error != null) {
                throw RuntimeException("Async test failed: $error")
            }
            val result = engine.execute("globalThis._testResult")
            if (result == null) {
                val resultType = engine.execute("typeof globalThis._testResult")
                val resultString = engine.execute("String(globalThis._testResult)")
                throw RuntimeException("Async test completed but result is null. Type: $resultType, String: $resultString")
            }
            return result
        }
        Thread.sleep(10) // Reduced from 50ms to pump microtasks more frequently
    }
    throw RuntimeException("Async test timed out after ${timeoutMs}ms")
}
