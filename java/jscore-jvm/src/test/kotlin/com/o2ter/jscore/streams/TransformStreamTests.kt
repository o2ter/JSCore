//
//  TransformStreamTests.kt
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
 * Tests for TransformStream API including transform, flush, and pipeline operations
 */
class TransformStreamTests {
    
    @Test
    fun testTransformStreamBasicTransformation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk * 2);
                    }
                });
                
                const writer = transform.writable.getWriter();
                const reader = transform.readable.getReader();
                
                writer.write(5);
                writer.close();
                
                const { value } = await reader.read();
                return value;
            })()
        """)
        
        assertEquals(10, (result as? Number)?.toInt(), "Should transform value by doubling")
    }
    
    @Test
    fun testTransformStreamReadableWritableProperties() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (() => {
                const transform = new TransformStream();
                return {
                    hasReadable: transform.readable instanceof ReadableStream,
                    hasWritable: transform.writable instanceof WritableStream
                };
            })()
        """)
        
        assertTrue(result?.toString()?.contains("true") == true, "Should have readable and writable properties")
    }
    
    @Test
    fun testTransformStreamFlush() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                let flushed = false;
                
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk);
                    },
                    flush(controller) {
                        flushed = true;
                        controller.enqueue('final');
                    }
                });
                
                const writer = transform.writable.getWriter();
                const reader = transform.readable.getReader();
                
                writer.write('data');
                writer.close();
                
                const chunks = [];
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return { flushed, chunks: chunks.length };
            })()
        """)
        
        assertTrue(result?.toString()?.contains("true") == true, "Should call flush on close")
    }
    
    @Test
    fun testTransformStreamMultipleChunks() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk.toUpperCase());
                    }
                });
                
                const writer = transform.writable.getWriter();
                const reader = transform.readable.getReader();
                
                writer.write('hello');
                writer.write('world');
                writer.close();
                
                const chunks = [];
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return chunks.join(' ');
            })()
        """)
        
        assertEquals("HELLO WORLD", result?.toString(), "Should transform multiple chunks")
    }
    
    @Test
    fun testTransformStreamFiltering() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        if (chunk > 0) {
                            controller.enqueue(chunk);
                        }
                    }
                });
                
                const writer = transform.writable.getWriter();
                const reader = transform.readable.getReader();
                
                writer.write(-1);
                writer.write(5);
                writer.write(-2);
                writer.write(10);
                writer.close();
                
                const chunks = [];
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return chunks.length;
            })()
        """)
        
        assertEquals(2, (result as? Number)?.toInt(), "Should filter out negative values")
    }
    
    @Test
    fun testTransformStreamPipeline() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const readable = new ReadableStream({
                    start(controller) {
                        controller.enqueue(1);
                        controller.enqueue(2);
                        controller.enqueue(3);
                        controller.close();
                    }
                });
                
                const transform1 = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk * 2);
                    }
                });
                
                const transform2 = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk + 10);
                    }
                });
                
                const transformed = readable
                    .pipeThrough(transform1)
                    .pipeThrough(transform2);
                
                const reader = transformed.getReader();
                const chunks = [];
                
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return chunks;
            })()
        """)
        
        assertTrue(result?.toString()?.contains("12") == true, "Should chain transforms: (1*2)+10=12")
    }
    
    @Test
    fun testTransformStreamError() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        if (chunk === 'error') {
                            throw new Error('Transform error');
                        }
                        controller.enqueue(chunk);
                    }
                });
                
                const writer = transform.writable.getWriter();
                const reader = transform.readable.getReader();
                
                try {
                    await writer.write('error');
                    return 'no-error';
                } catch (e) {
                    return e.message;
                }
            })()
        """)
        
        assertEquals("Transform error", result?.toString(), "Should propagate transform errors")
    }
}
