//
//  ReadableStreamTests.kt
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
 * Tests for ReadableStream API including tee, pipeTo, and pipeThrough operations
 */
class ReadableStreamTests {
    
    @Test
    fun testReadableStreamBasicReading() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('chunk1');
                        controller.enqueue('chunk2');
                        controller.close();
                    }
                });
                
                const reader = stream.getReader();
                const chunks = [];
                
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return chunks.length;
            })()
        """)
        
        assertEquals(2, (result as? Number)?.toInt(), "Should read all chunks")
    }
    
    @Test
    fun testReadableStreamTee() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('data');
                        controller.close();
                    }
                });
                
                const [stream1, stream2] = stream.tee();
                
                const reader1 = stream1.getReader();
                const reader2 = stream2.getReader();
                
                const result1 = await reader1.read();
                const result2 = await reader2.read();
                
                return result1.value === result2.value;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should tee stream into two identical streams")
    }
    
    @Test
    fun testReadableStreamPipeTo() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const chunks = [];
                
                const readable = new ReadableStream({
                    start(controller) {
                        controller.enqueue('chunk1');
                        controller.enqueue('chunk2');
                        controller.close();
                    }
                });
                
                const writable = new WritableStream({
                    write(chunk) {
                        chunks.push(chunk);
                    }
                });
                
                await readable.pipeTo(writable);
                return chunks.length;
            })()
        """)
        
        assertEquals(2, (result as? Number)?.toInt(), "Should pipe all chunks to writable")
    }
    
    @Test
    fun testReadableStreamPipeThrough() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const readable = new ReadableStream({
                    start(controller) {
                        controller.enqueue('hello');
                        controller.close();
                    }
                });
                
                const transform = new TransformStream({
                    transform(chunk, controller) {
                        controller.enqueue(chunk.toUpperCase());
                    }
                });
                
                const transformed = readable.pipeThrough(transform);
                const reader = transformed.getReader();
                const { value } = await reader.read();
                
                return value;
            })()
        """)
        
        assertEquals("HELLO", result?.toString(), "Should transform chunks through pipeline")
    }
    
    @Test
    fun testReadableStreamCancel() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                let cancelled = false;
                
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('data');
                    },
                    cancel() {
                        cancelled = true;
                    }
                });
                
                const reader = stream.getReader();
                await reader.cancel();
                
                return cancelled;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should call cancel callback")
    }
    
    @Test
    fun testReadableStreamBackpressure() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('chunk1');
                        controller.enqueue('chunk2');
                        controller.enqueue('chunk3');
                        controller.close();
                    }
                }, { highWaterMark: 1 });
                
                const reader = stream.getReader();
                const chunks = [];
                
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    chunks.push(value);
                }
                
                return chunks.length;
            })()
        """)
        
        assertEquals(3, (result as? Number)?.toInt(), "Should handle backpressure with small buffer")
    }
    
    @Test
    fun testReadableStreamFromBlob() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const blob = new Blob(['test data']);
                const stream = blob.stream();
                const reader = stream.getReader();
                
                const { value, done } = await reader.read();
                return value instanceof Uint8Array;
            })()
        """)
        
        assertTrue((result as? Boolean) == true, "Should create stream from blob")
    }
}
