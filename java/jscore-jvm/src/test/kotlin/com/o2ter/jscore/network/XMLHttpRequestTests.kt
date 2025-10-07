//
//  XMLHttpRequestTests.kt
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
import kotlin.test.assertTrue

/**
 * Tests for XMLHttpRequest API
 */
class XMLHttpRequestTests {
    
    @Test
    fun testXHRBasicGET() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/get');
                        xhr.onload = () => resolve(xhr.status);
                        xhr.onerror = () => reject(new Error('Network error'));
                        xhr.send();
                    });
                })()
            """, timeoutMs = 15000) // Increased timeout to 15 seconds
            
            assertEquals(200, (result as? Number)?.toInt(), "Should complete GET request")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRReadyStates() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const states = [];
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.onreadystatechange = () => states.push(xhr.readyState);
                        xhr.open('GET', 'https://postman-echo.com/get');
                        xhr.onload = () => resolve(states);
                        xhr.send();
                    });
                })()
            """)
            
            assertTrue(result?.toString()?.contains("4") == true, "Should reach DONE state (4)")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRPOSTWithData() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve, reject) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('POST', 'https://postman-echo.com/post');
                        xhr.setRequestHeader('Content-Type', 'application/json');
                        xhr.onload = () => resolve(xhr.status);
                        xhr.onerror = () => reject(new Error('Network error'));
                        xhr.send(JSON.stringify({ test: 'data' }));
                    });
                })()
            """)
            
            assertEquals(200, (result as? Number)?.toInt(), "Should POST data successfully")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRResponseText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/get');
                        xhr.onload = () => resolve(typeof xhr.responseText);
                        xhr.send();
                    });
                })()
            """)
            
            assertEquals("string", result?.toString(), "Should return responseText as string")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRResponseJSON() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/get?test=value');
                        xhr.responseType = 'json';
                        xhr.onload = () => resolve(xhr.response.args.test);
                        xhr.send();
                    });
                })()
            """)
            
            assertEquals("value", result?.toString(), "Should parse JSON response")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRResponseArrayBuffer() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/get');
                        xhr.responseType = 'arraybuffer';
                        xhr.onload = () => resolve(xhr.response.byteLength > 0);
                        xhr.send();
                    });
                })()
            """)
            
            assertTrue((result as? Boolean) == true, "Should return ArrayBuffer")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRProgressEvents() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const events = [];
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/get');
                        xhr.onloadstart = () => events.push('loadstart');
                        xhr.onprogress = () => events.push('progress');
                        xhr.onload = () => {
                            events.push('load');
                            resolve(events);
                        };
                        xhr.send();
                    });
                })()
            """)
            
            assertTrue(result?.toString()?.contains("loadstart") == true, "Should fire loadstart event")
            assertTrue(result?.toString()?.contains("load") == true, "Should fire load event")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRAbort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://postman-echo.com/delay/5');
                        xhr.onabort = () => resolve('aborted');
                        xhr.onerror = () => resolve('error');
                        xhr.send();
                        setTimeout(() => xhr.abort(), 100);
                    });
                })()
            """, 2000)
            
            assertEquals("aborted", result?.toString(), "Should abort request")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testXHRStatusAndStatusText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    return new Promise((resolve) => {
                        const xhr = new XMLHttpRequest();
                        xhr.open('GET', 'https://httpstat.us/404');
                        xhr.onload = () => resolve({
                            status: xhr.status,
                            statusText: xhr.statusText
                        });
                        xhr.send();
                    });
                })()
            """)
            
            assertTrue(result?.toString()?.contains("404") == true, "Should return correct status")
        } finally {
            engine.close()
        }
    }
}
