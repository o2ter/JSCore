//
//  CompressionTests.kt
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

import com.o2ter.jscore.executeAsync
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Tests for Compression Streams API
 */
class CompressionTests {
    
    // MARK: - API Existence Tests
    
    @Test
    fun testCompressionStreamExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof CompressionStream")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testDecompressionStreamExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof DecompressionStream")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Basic Compression/Decompression Tests
    
    @Test
    fun testGzipCompressionDecompression() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const input = 'Hello, World! This is a test of gzip compression.';
                    const inputBytes = new TextEncoder().encode(input);
                    
                    // Compress
                    const compressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(inputBytes);
                            controller.close();
                        }
                    }).pipeThrough(new CompressionStream('gzip'));
                    
                    const compressedReader = compressedStream.getReader();
                    const compressedChunks = [];
                    while (true) {
                        const { done, value } = await compressedReader.read();
                        if (done) break;
                        compressedChunks.push(value);
                    }
                    
                    // Combine compressed chunks
                    const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const compressed = new Uint8Array(totalLength);
                    let offset = 0;
                    for (const chunk of compressedChunks) {
                        compressed.set(chunk, offset);
                        offset += chunk.length;
                    }
                    
                    // Decompress
                    const decompressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(compressed);
                            controller.close();
                        }
                    }).pipeThrough(new DecompressionStream('gzip'));
                    
                    const decompressedReader = decompressedStream.getReader();
                    const decompressedChunks = [];
                    while (true) {
                        const { done, value } = await decompressedReader.read();
                        if (done) break;
                        decompressedChunks.push(value);
                    }
                    
                    // Combine decompressed chunks
                    const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const decompressed = new Uint8Array(decompressedTotalLength);
                    let decompressedOffset = 0;
                    for (const chunk of decompressedChunks) {
                        decompressed.set(chunk, decompressedOffset);
                        decompressedOffset += chunk.length;
                    }
                    
                    const output = new TextDecoder().decode(decompressed);
                    
                    return {
                        input: input,
                        output: output,
                        match: input === output,
                        compressedSize: compressed.length,
                        originalSize: inputBytes.length
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["match"])
            assertEquals(result["input"], result["output"])
            
            val originalSize = result["originalSize"] as? Number
            val compressedSize = result["compressedSize"] as? Number
            assertNotNull(originalSize)
            assertNotNull(compressedSize)
            assertTrue(compressedSize.toLong() < originalSize.toLong(), "Compressed size should be smaller")
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testDeflateCompressionDecompression() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const input = 'Testing deflate compression with a moderately long string to ensure compression works.';
                    const inputBytes = new TextEncoder().encode(input);
                    
                    // Compress
                    const compressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(inputBytes);
                            controller.close();
                        }
                    }).pipeThrough(new CompressionStream('deflate'));
                    
                    const compressedReader = compressedStream.getReader();
                    const compressedChunks = [];
                    while (true) {
                        const { done, value } = await compressedReader.read();
                        if (done) break;
                        compressedChunks.push(value);
                    }
                    
                    const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const compressed = new Uint8Array(totalLength);
                    let offset = 0;
                    for (const chunk of compressedChunks) {
                        compressed.set(chunk, offset);
                        offset += chunk.length;
                    }
                    
                    // Decompress
                    const decompressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(compressed);
                            controller.close();
                        }
                    }).pipeThrough(new DecompressionStream('deflate'));
                    
                    const decompressedReader = decompressedStream.getReader();
                    const decompressedChunks = [];
                    while (true) {
                        const { done, value } = await decompressedReader.read();
                        if (done) break;
                        decompressedChunks.push(value);
                    }
                    
                    const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const decompressed = new Uint8Array(decompressedTotalLength);
                    let decompressedOffset = 0;
                    for (const chunk of decompressedChunks) {
                        decompressed.set(chunk, decompressedOffset);
                        decompressedOffset += chunk.length;
                    }
                    
                    const output = new TextDecoder().decode(decompressed);
                    
                    return {
                        input: input,
                        output: output,
                        match: input === output
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["match"])
            assertEquals(result["input"], result["output"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testDeflateRawCompressionDecompression() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const input = 'Raw deflate test string with sufficient content for compression benefits.';
                    const inputBytes = new TextEncoder().encode(input);
                    
                    // Compress
                    const compressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(inputBytes);
                            controller.close();
                        }
                    }).pipeThrough(new CompressionStream('deflate-raw'));
                    
                    const compressedReader = compressedStream.getReader();
                    const compressedChunks = [];
                    while (true) {
                        const { done, value } = await compressedReader.read();
                        if (done) break;
                        compressedChunks.push(value);
                    }
                    
                    const totalLength = compressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const compressed = new Uint8Array(totalLength);
                    let offset = 0;
                    for (const chunk of compressedChunks) {
                        compressed.set(chunk, offset);
                        offset += chunk.length;
                    }
                    
                    // Decompress
                    const decompressedStream = new ReadableStream({
                        start(controller) {
                            controller.enqueue(compressed);
                            controller.close();
                        }
                    }).pipeThrough(new DecompressionStream('deflate-raw'));
                    
                    const decompressedReader = decompressedStream.getReader();
                    const decompressedChunks = [];
                    while (true) {
                        const { done, value } = await decompressedReader.read();
                        if (done) break;
                        decompressedChunks.push(value);
                    }
                    
                    const decompressedTotalLength = decompressedChunks.reduce((sum, chunk) => sum + chunk.length, 0);
                    const decompressed = new Uint8Array(decompressedTotalLength);
                    let decompressedOffset = 0;
                    for (const chunk of decompressedChunks) {
                        decompressed.set(chunk, decompressedOffset);
                        decompressedOffset += chunk.length;
                    }
                    
                    const output = new TextDecoder().decode(decompressed);
                    
                    return {
                        input: input,
                        output: output,
                        match: input === output
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["match"])
            assertEquals(result["input"], result["output"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testInvalidCompressionFormat() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    new CompressionStream('invalid-format');
                    'no-error';
                } catch (e) {
                    e.message;
                }
            """)
            
            assertTrue(result.toString().contains("Unsupported compression format"))
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testInvalidDecompressionFormat() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    new DecompressionStream('invalid-format');
                    'no-error';
                } catch (e) {
                    e.message;
                }
            """)
            
            assertTrue(result.toString().contains("Unsupported compression format"))
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test
    fun testCompressionStreamReadableWritable() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const stream = new CompressionStream('gzip');
                const hasReadable = stream.readable instanceof ReadableStream;
                const hasWritable = stream.writable instanceof WritableStream;
                ({ hasReadable, hasWritable });
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["hasReadable"])
            assertEquals(true, result["hasWritable"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testDecompressionStreamReadableWritable() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const stream = new DecompressionStream('deflate');
                const hasReadable = stream.readable instanceof ReadableStream;
                const hasWritable = stream.writable instanceof WritableStream;
                ({ hasReadable, hasWritable });
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["hasReadable"])
            assertEquals(true, result["hasWritable"])
        } finally {
            engine.close()
        }
    }
}
