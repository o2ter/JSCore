//
//  WritableStreamTests.kt
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

package com.o2ter.jscore.streams

import com.o2ter.jscore.executeAsync

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Tests for WritableStream API including writer operations and backpressure
 */
class WritableStreamTests {
    
    @Test
    fun testWritableStreamBasicWriting() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const chunks = [];
                const stream = new WritableStream({
                    write(chunk) {
                        chunks.push(chunk);
                    }
                });
                
                const writer = stream.getWriter();
                await writer.write('chunk1');
                await writer.write('chunk2');
                await writer.close();
                
                return chunks.length;
            })()
        """)
        
        assertEquals(2, (result as? Number)?.toInt(), "Should write all chunks")
    }
    
    @Test
    fun testWritableStreamGetWriter() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new WritableStream();
                const writer = stream.getWriter();
                const hasWrite = typeof writer.write === 'function';
                const hasClose = typeof writer.close === 'function';
                
                return hasWrite && hasClose;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should return writer with methods")
    }
    
    @Test
    fun testWritableStreamClose() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                let closed = false;
                const stream = new WritableStream({
                    close() {
                        closed = true;
                    }
                });
                
                const writer = stream.getWriter();
                await writer.close();
                
                return closed;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should call close callback")
    }
    
    @Test
    fun testWritableStreamAbort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                let abortReason = null;
                const stream = new WritableStream({
                    abort(reason) {
                        abortReason = reason;
                    }
                });
                
                const writer = stream.getWriter();
                await writer.abort('test-reason');
                
                return abortReason;
            })()
        """)
        
        assertEquals("test-reason", result?.toString(), "Should call abort with reason")
    }
    
    @Test
    fun testWritableStreamBackpressure() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new WritableStream({
                    write(chunk) {
                        // Simulate slow sink
                        return new Promise(resolve => setTimeout(resolve, 10));
                    }
                }, { highWaterMark: 1 });
                
                const writer = stream.getWriter();
                
                // Check desiredSize before writing
                const beforeSize = writer.desiredSize;
                
                await writer.write('chunk1');
                await writer.write('chunk2');
                await writer.close();
                
                return typeof beforeSize === 'number';
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should report desiredSize for backpressure")
    }
    
    @Test
    fun testWritableStreamReady() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new WritableStream();
                const writer = stream.getWriter();
                
                // ready should be a promise
                const isPromise = writer.ready instanceof Promise;
                await writer.ready;
                
                await writer.close();
                return isPromise;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should provide ready promise")
    }
    
    @Test
    fun testWritableStreamClosed() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new WritableStream();
                const writer = stream.getWriter();
                
                // closed should be a promise
                const isPromise = writer.closed instanceof Promise;
                await writer.close();
                await writer.closed;
                
                return isPromise;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should provide closed promise")
    }
    
    @Test
    fun testWritableStreamError() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new WritableStream({
                    write(chunk) {
                        if (chunk === 'error') {
                            throw new Error('Write error');
                        }
                    }
                });
                
                const writer = stream.getWriter();
                
                try {
                    await writer.write('error');
                    return 'no-error';
                } catch (e) {
                    return e.message;
                }
            })()
        """)
        
        assertEquals("Write error", result?.toString(), "Should propagate write errors")
    }
}
