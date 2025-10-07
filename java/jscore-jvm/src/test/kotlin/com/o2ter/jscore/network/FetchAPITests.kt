//
//  FetchAPITests.kt
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

import com.o2ter.jscore.executeAsync
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Tests for fetch() API including streaming, redirects, and abort support
 */
class FetchAPITests {
    
    @Test
    fun testFetchBasicGET() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    console.log("Starting fetch...");
                    try {
                        const response = await fetch('https://postman-echo.com/get');
                        console.log("Got response:", response.status);
                        return {
                            status: response.status,
                            ok: response.ok
                        };
                    } catch (error) {
                        console.error("Fetch failed:", error);
                        throw error;
                    }
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result, "Result should not be null")
            assertEquals(200, (result?.get("status") as? Number)?.toInt(), "Status should be 200")
            assertEquals(true, result?.get("ok"), "OK should be true")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchPOSTWithBody() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/post', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ test: 'data' })
                    });
                    return response.status;
                })()
            """, timeoutMs = 10000)
            
            assertEquals(200, (result as? Number)?.toInt(), "Should POST data successfully - got status code: $result")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchResponseJSON() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/get?test=value');
                    const data = await response.json();
                    return data.args.test;
                })()
            """)
            
            assertEquals("value", result?.toString(), "Should parse JSON response")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchResponseText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/get');
                    const text = await response.text();
                    return typeof text === 'string';
                })()
            """)
            
            assertTrue((result as? Boolean) == true, "Should return text response")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchResponseArrayBuffer() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/get');
                    const buffer = await response.arrayBuffer();
                    return buffer.byteLength > 0;
                })()
            """)
            
            assertTrue((result as? Boolean) == true, "Should return ArrayBuffer")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchStreaming() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/stream/3');
                    const reader = response.body.getReader();
                    let chunks = 0;
                    
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks++;
                    }
                    
                    return chunks;
                })()
            """, 10000)
            
            assertTrue((result as? Number)?.toInt() ?: 0 > 0, "Should stream response in chunks")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchHeaders() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const response = await fetch('https://postman-echo.com/get', {
                        headers: { 'X-Custom-Header': 'test-value' }
                    });
                    return response.status;
                })()
            """)
            
            assertEquals(200, (result as? Number)?.toInt(), "Should send custom headers")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchAbortController() {
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
                        return 'not-aborted';
                    } catch (error) {
                        return error.name === 'AbortError' ? 'aborted' : 'other-error';
                    }
                })()
            """, 3000)
            
            assertEquals("aborted", result?.toString(), "Should abort fetch request")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFetchRedirect() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const response = await fetch('https://postman-echo.com/redirect-to?url=https://postman-echo.com/get');
                return {
                    status: response.status,
                    redirected: response.redirected
                };
            })()
        """)
        
        assertTrue(result?.toString()?.contains("200") == true, "Should follow redirects")
    }
}
