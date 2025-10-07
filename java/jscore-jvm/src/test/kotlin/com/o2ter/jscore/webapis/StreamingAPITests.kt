//
//  StreamingAPITests.kt
//  KotlinJS Streaming API Comprehensive Tests
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
 * Comprehensive tests for Web Streams API including ReadableStream, WritableStream,
 * TransformStream, pipeTo, pipeThrough with advanced edge cases for error handling,
 * backpressure, memory pressure, abort integration, and concurrent operations.
 */
class StreamingAPITests {
    
    // MARK: - ReadableStream Basic Tests
    
    @Test
    fun testReadableStreamExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof ReadableStream")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testReadableStreamBasicRead() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const stream = new ReadableStream({
                        start(controller) {
                            controller.enqueue('chunk1');
                            controller.enqueue('chunk2');
                            controller.enqueue('chunk3');
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
                    
                    return {
                        chunks: chunks,
                        count: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(3, chunks.size)
            assertEquals("chunk1", chunks[0])
            assertEquals("chunk2", chunks[1])
            assertEquals("chunk3", chunks[2])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testReadableStreamTee() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const stream = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.enqueue('data2');
                            controller.close();
                        }
                    });
                    
                    const [branch1, branch2] = stream.tee();
                    
                    const reader1 = branch1.getReader();
                    const reader2 = branch2.getReader();
                    
                    const chunks1 = [];
                    const chunks2 = [];
                    
                    // Read from both branches
                    while (true) {
                        const { done, value } = await reader1.read();
                        if (done) break;
                        chunks1.push(value);
                    }
                    
                    while (true) {
                        const { done, value } = await reader2.read();
                        if (done) break;
                        chunks2.push(value);
                    }
                    
                    return {
                        branch1: chunks1,
                        branch2: chunks2,
                        sameData: JSON.stringify(chunks1) === JSON.stringify(chunks2)
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["sameData"])
            
            val branch1 = result["branch1"] as? List<*>
            val branch2 = result["branch2"] as? List<*>
            assertNotNull(branch1)
            assertNotNull(branch2)
            assertEquals(2, branch1.size)
            assertEquals(2, branch2.size)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testReadableStreamCancel() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let cancelCalled = false;
                    let cancelReason = null;
                    
                    const stream = new ReadableStream({
                        start(controller) {
                            controller.enqueue('chunk1');
                            controller.enqueue('chunk2');
                            controller.enqueue('chunk3');
                        },
                        cancel(reason) {
                            cancelCalled = true;
                            cancelReason = reason;
                        }
                    });
                    
                    const reader = stream.getReader();
                    await reader.read(); // Read one chunk
                    await reader.cancel('User cancelled');
                    
                    return {
                        cancelCalled: cancelCalled,
                        cancelReason: cancelReason
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["cancelCalled"])
            assertEquals("User cancelled", result["cancelReason"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - WritableStream Tests
    
    @Test
    fun testWritableStreamExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof WritableStream")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testWritableStreamBasicWrite() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const chunks = [];
                    
                    const stream = new WritableStream({
                        write(chunk) {
                            chunks.push(chunk);
                        }
                    });
                    
                    const writer = stream.getWriter();
                    await writer.write('data1');
                    await writer.write('data2');
                    await writer.write('data3');
                    await writer.close();
                    
                    return {
                        chunks: chunks,
                        count: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(3, chunks.size)
            assertEquals("data1", chunks[0])
            assertEquals("data2", chunks[1])
            assertEquals("data3", chunks[2])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - TransformStream Tests
    
    @Test
    fun testTransformStreamExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof TransformStream")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTransformStreamBasicTransform() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const transform = new TransformStream({
                        transform(chunk, controller) {
                            controller.enqueue(chunk.toUpperCase());
                        }
                    });
                    
                    const writer = transform.writable.getWriter();
                    const reader = transform.readable.getReader();
                    
                    // Write data
                    writer.write('hello');
                    writer.write('world');
                    writer.close();
                    
                    // Read transformed data
                    const chunks = [];
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    return {
                        chunks: chunks,
                        count: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(2, chunks.size)
            assertEquals("HELLO", chunks[0])
            assertEquals("WORLD", chunks[1])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - pipeTo Tests
    
    @Test
    fun testPipeToBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const chunks = [];
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.enqueue('data2');
                            controller.enqueue('data3');
                            controller.close();
                        }
                    });
                    
                    const writable = new WritableStream({
                        write(chunk) {
                            chunks.push(chunk);
                        }
                    });
                    
                    await readable.pipeTo(writable);
                    
                    return {
                        chunks: chunks,
                        count: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(3, chunks.size)
            assertEquals("data1", chunks[0])
            assertEquals("data2", chunks[1])
            assertEquals("data3", chunks[2])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeToErrorPropagation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let errorCaught = false;
                    let errorMessage = null;
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.error(new Error('Read error'));
                        }
                    });
                    
                    const chunks = [];
                    const writable = new WritableStream({
                        write(chunk) {
                            chunks.push(chunk);
                        }
                    });
                    
                    try {
                        await readable.pipeTo(writable);
                    } catch (error) {
                        errorCaught = true;
                        errorMessage = error.message;
                    }
                    
                    return {
                        errorCaught: errorCaught,
                        errorMessage: errorMessage,
                        chunksReceived: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["errorCaught"])
            assertTrue(result["errorMessage"].toString().contains("Read error"))
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeToWithAbortController() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let errorCaught = false;
                    let errorName = null;
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.enqueue('data2');
                            controller.enqueue('data3');
                        }
                    });
                    
                    const chunks = [];
                    const writable = new WritableStream({
                        write(chunk) {
                            chunks.push(chunk);
                        }
                    });
                    
                    const controller = new AbortController();
                    
                    // Start piping
                    const pipePromise = readable.pipeTo(writable, { signal: controller.signal });
                    
                    // Abort immediately
                    controller.abort();
                    
                    try {
                        await pipePromise;
                    } catch (error) {
                        errorCaught = true;
                        errorName = error.name;
                    }
                    
                    return {
                        errorCaught: errorCaught,
                        errorName: errorName,
                        chunksReceivedBeforeAbort: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["errorCaught"])
            assertEquals("AbortError", result["errorName"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeToWithPreventCloseOption() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let writableClosed = false;
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.enqueue('data2');
                            controller.close();
                        }
                    });
                    
                    const chunks = [];
                    const writable = new WritableStream({
                        write(chunk) {
                            chunks.push(chunk);
                        },
                        close() {
                            writableClosed = true;
                        }
                    });
                    
                    // Pipe with preventClose option
                    await readable.pipeTo(writable, { preventClose: true });
                    
                    // Writable should still be open
                    const writer = writable.getWriter();
                    await writer.write('data3');
                    await writer.close();
                    
                    return {
                        chunks: chunks,
                        writableClosedByPipe: writableClosed
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(3, chunks.size) // Should have all 3 chunks
            assertEquals("data3", chunks[2]) // Last chunk written after pipe
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeToTypeValidation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const readable = new ReadableStream();
                    readable.pipeTo(null); // Invalid writable
                    ({ success: true })
                } catch (error) {
                    ({
                        success: false,
                        error: error.message,
                        errorType: error.constructor.name
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["success"])
            val errorMsg = result["error"].toString()
            assertTrue(errorMsg.contains("writable", ignoreCase = true) || 
                      errorMsg.contains("type", ignoreCase = true) ||
                      errorMsg.contains("stream", ignoreCase = true))
        } finally {
            engine.close()
        }
    }
    
    // MARK: - pipeThrough Tests
    
    @Test
    fun testPipeThroughBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('hello');
                            controller.enqueue('world');
                            controller.close();
                        }
                    });
                    
                    const transform = new TransformStream({
                        transform(chunk, controller) {
                            controller.enqueue(chunk.toUpperCase());
                        }
                    });
                    
                    const reader = readable.pipeThrough(transform).getReader();
                    
                    const chunks = [];
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    return {
                        chunks: chunks,
                        count: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(2, chunks.size)
            assertEquals("HELLO", chunks[0])
            assertEquals("WORLD", chunks[1])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeThroughChaining() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('hello');
                            controller.enqueue('world');
                            controller.close();
                        }
                    });
                    
                    // First transform: uppercase
                    const upperTransform = new TransformStream({
                        transform(chunk, controller) {
                            controller.enqueue(chunk.toUpperCase());
                        }
                    });
                    
                    // Second transform: add prefix
                    const prefixTransform = new TransformStream({
                        transform(chunk, controller) {
                            controller.enqueue('PREFIX_' + chunk);
                        }
                    });
                    
                    const reader = readable
                        .pipeThrough(upperTransform)
                        .pipeThrough(prefixTransform)
                        .getReader();
                    
                    const chunks = [];
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    return {
                        chunks: chunks
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            val chunks = result["chunks"] as? List<*>
            assertNotNull(chunks)
            assertEquals(2, chunks.size)
            assertEquals("PREFIX_HELLO", chunks[0])
            assertEquals("PREFIX_WORLD", chunks[1])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testPipeThroughTypeValidation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const readable = new ReadableStream();
                    readable.pipeThrough(null); // Invalid transform
                    ({ success: true })
                } catch (error) {
                    ({
                        success: false,
                        error: error.message,
                        errorType: error.constructor.name
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["success"])
            val errorMsg = result["error"].toString()
            assertTrue(errorMsg.contains("transform", ignoreCase = true) || 
                      errorMsg.contains("type", ignoreCase = true) ||
                      errorMsg.contains("stream", ignoreCase = true))
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Backpressure Tests
    
    @Test
    fun testBackpressureHandling() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let enqueueCount = 0;
                    let writeCount = 0;
                    
                    const readable = new ReadableStream({
                        async start(controller) {
                            for (let i = 0; i < 100; i++) {
                                controller.enqueue('data' + i);
                                enqueueCount++;
                            }
                            controller.close();
                        }
                    });
                    
                    const writable = new WritableStream({
                        async write(chunk) {
                            writeCount++;
                            // Simulate slow consumer
                            await new Promise(resolve => setTimeout(resolve, 1));
                        }
                    });
                    
                    await readable.pipeTo(writable);
                    
                    return {
                        enqueueCount: enqueueCount,
                        writeCount: writeCount,
                        allChunksProcessed: enqueueCount === writeCount
                    };
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(100, (result["enqueueCount"] as? Number)?.toInt())
            assertEquals(100, (result["writeCount"] as? Number)?.toInt())
            assertEquals(true, result["allChunksProcessed"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Memory Pressure Tests
    
    @Test
    fun testMemoryPressureStreaming() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const chunkSize = 1024 * 1024; // 1MB chunks
                    const chunkCount = 10; // 10MB total
                    
                    let totalBytesRead = 0;
                    let chunks = 0;
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            for (let i = 0; i < chunkCount; i++) {
                                const data = new Uint8Array(chunkSize);
                                data.fill(i % 256);
                                controller.enqueue(data);
                            }
                            controller.close();
                        }
                    });
                    
                    const writable = new WritableStream({
                        write(chunk) {
                            chunks++;
                            totalBytesRead += chunk.byteLength;
                        }
                    });
                    
                    await readable.pipeTo(writable);
                    
                    return {
                        totalBytesRead: totalBytesRead,
                        chunks: chunks,
                        expectedBytes: chunkSize * chunkCount,
                        correct: totalBytesRead === (chunkSize * chunkCount)
                    };
                })()
            """, timeoutMs = 30000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(10, (result["chunks"] as? Number)?.toInt())
            assertEquals(true, result["correct"])
            val totalBytes = (result["totalBytesRead"] as? Number)?.toLong() ?: 0
            assertTrue(totalBytes > 10_000_000) // Should be ~10MB
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test
    fun testConcurrentStreamErrors() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const streamCount = 5;
                    const promises = [];
                    let errorsCount = 0;
                    
                    for (let i = 0; i < streamCount; i++) {
                        const promise = (async () => {
                            const readable = new ReadableStream({
                                start(controller) {
                                    controller.enqueue('data');
                                    controller.error(new Error('Stream error ' + i));
                                }
                            });
                            
                            const writable = new WritableStream({
                                write(chunk) {
                                    // Process chunk
                                }
                            });
                            
                            try {
                                await readable.pipeTo(writable);
                            } catch (error) {
                                errorsCount++;
                                return { error: error.message };
                            }
                        })();
                        
                        promises.push(promise);
                    }
                    
                    const results = await Promise.all(promises);
                    
                    return {
                        streamCount: streamCount,
                        errorsCount: errorsCount,
                        allErrored: errorsCount === streamCount,
                        results: results.map(r => r ? r.error : null)
                    };
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(5, (result["streamCount"] as? Number)?.toInt())
            assertEquals(5, (result["errorsCount"] as? Number)?.toInt())
            assertEquals(true, result["allErrored"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Resource Cleanup Tests
    
    @Test
    fun testStreamResourceCleanup() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let cleanupCalled = false;
                    
                    const readable = new ReadableStream({
                        start(controller) {
                            controller.enqueue('data1');
                            controller.enqueue('data2');
                            controller.close();
                        },
                        cancel() {
                            cleanupCalled = true;
                        }
                    });
                    
                    const reader = readable.getReader();
                    await reader.read(); // Read one chunk
                    await reader.cancel('Manual cancel');
                    
                    // Try to get another reader (should work since stream is cancelled)
                    let canGetNewReader = false;
                    try {
                        reader.releaseLock();
                        const newReader = readable.getReader();
                        canGetNewReader = true;
                        newReader.releaseLock();
                    } catch (e) {
                        canGetNewReader = false;
                    }
                    
                    return {
                        cleanupCalled: cleanupCalled,
                        canGetNewReader: !canGetNewReader // Should be false because stream is cancelled
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["cleanupCalled"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Blob Stream Integration Tests
    
    @Test
    fun testBlobStreamIntegration() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const blobContent = 'Hello, Blob Stream!';
                    const blob = new Blob([blobContent]);
                    const stream = blob.stream();
                    
                    const reader = stream.getReader();
                    const chunks = [];
                    
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                    }
                    
                    // Combine chunks
                    let totalLength = 0;
                    for (const chunk of chunks) {
                        totalLength += chunk.byteLength;
                    }
                    
                    const combined = new Uint8Array(totalLength);
                    let offset = 0;
                    for (const chunk of chunks) {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    }
                    
                    const text = new TextDecoder().decode(combined);
                    
                    return {
                        originalContent: blobContent,
                        reconstructedContent: text,
                        match: text === blobContent,
                        chunkCount: chunks.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("Hello, Blob Stream!", result["originalContent"])
            assertEquals("Hello, Blob Stream!", result["reconstructedContent"])
            assertEquals(true, result["match"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testStreamFromLargeBlob() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    // Create a 5MB blob
                    const chunkSize = 1024 * 1024; // 1MB
                    const parts = [];
                    for (let i = 0; i < 5; i++) {
                        const data = new Uint8Array(chunkSize);
                        data.fill(i);
                        parts.push(data);
                    }
                    
                    const blob = new Blob(parts);
                    const stream = blob.stream();
                    
                    const reader = stream.getReader();
                    let totalBytes = 0;
                    let chunkCount = 0;
                    
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        totalBytes += value.byteLength;
                        chunkCount++;
                    }
                    
                    return {
                        expectedSize: chunkSize * 5,
                        actualSize: totalBytes,
                        chunkCount: chunkCount,
                        correct: totalBytes === (chunkSize * 5)
                    };
                })()
            """, timeoutMs = 30000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["correct"])
            val actualSize = (result["actualSize"] as? Number)?.toLong() ?: 0
            assertTrue(actualSize > 5_000_000) // Should be ~5MB
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Edge Cases
    
    @Test
    fun testTransformStreamErrorHandling() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    let errorCaught = false;
                    let errorMessage = null;
                    
                    const transform = new TransformStream({
                        transform(chunk, controller) {
                            if (chunk === 'error') {
                                throw new Error('Transform error');
                            }
                            controller.enqueue(chunk.toUpperCase());
                        }
                    });
                    
                    const writer = transform.writable.getWriter();
                    const reader = transform.readable.getReader();
                    
                    // Write some data including error trigger
                    writer.write('hello');
                    writer.write('error');
                    writer.write('world').catch(() => {}); // Might fail after error
                    
                    try {
                        while (true) {
                            const { done, value } = await reader.read();
                            if (done) break;
                        }
                    } catch (error) {
                        errorCaught = true;
                        errorMessage = error.message;
                    }
                    
                    return {
                        errorCaught: errorCaught,
                        errorMessage: errorMessage
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["errorCaught"])
            assertTrue(result["errorMessage"].toString().contains("Transform error"))
        } finally {
            engine.close()
        }
    }
}
