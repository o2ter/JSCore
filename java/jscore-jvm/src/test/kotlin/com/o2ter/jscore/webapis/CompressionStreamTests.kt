/*
 * CompressionStreamTests.kt
 * JSCore
 *
 * MIT License
 *
 * Copyright (c) 2025 o2ter
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package com.o2ter.jscore.webapis

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import com.o2ter.jscore.executeAsync
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class CompressionStreamTests {

    @Test
    fun testCompressionStreamGzip() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var testResult: Map<*, *>? = null

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var original = 'Hello World! '.repeat(100); // Repetitive data compresses well
                
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode(original));
                        controller.close();
                    }
                });
                
                var compressed = stream.pipeThrough(new CompressionStream('gzip'));
                
                var chunks = [];
                var reader = compressed.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                var compressedSize = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
                var originalSize = encoder.encode(original).length;
                
                return ({
                    originalSize: originalSize,
                    compressedSize: compressedSize,
                    compressionRatio: compressedSize / originalSize,
                    isSmaller: compressedSize < originalSize
                });
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                testResult = result as? Map<*, *>
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertNotNull("Should have result", testResult)

        val isSmaller = testResult!!["isSmaller"] as Boolean
        val compressionRatio = (testResult!!["compressionRatio"] as Number).toDouble()

        assertTrue("Compressed data should be smaller than original", isSmaller)
        assertTrue("Compression ratio should be < 0.5 for repetitive data", compressionRatio < 0.5)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testDecompressionStreamGzip() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var testResult: Map<*, *>? = null

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var decoder = new TextDecoder();
                var original = 'Hello World! '.repeat(50);
                
                // Compress
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode(original));
                        controller.close();
                    }
                });
                var compressed = stream.pipeThrough(new CompressionStream('gzip'));
                
                // Collect compressed chunks
                var compressedChunks = [];
                var reader = compressed.getReader();
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    compressedChunks.push(result.value);
                }
                
                // Decompress
                var compressedStream = new ReadableStream({
                    start(controller) {
                        for (var chunk of compressedChunks) {
                            controller.enqueue(chunk);
                        }
                        controller.close();
                    }
                });
                var decompressed = compressedStream.pipeThrough(new DecompressionStream('gzip'));
                
                // Collect decompressed chunks
                var decompressedChunks = [];
                reader = decompressed.getReader();
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    decompressedChunks.push(result.value);
                }
                
                var result = decoder.decode(decompressedChunks[0]);
                return ({
                    original: original,
                    result: result,
                    match: original === result
                });
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                testResult = result as? Map<*, *>
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertNotNull("Should have result", testResult)

        val match = testResult!!["match"] as Boolean
        assertTrue("Decompressed data should match original", match)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCompressionStreamDeflate() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var isSmaller = false

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var original = 'Test data '.repeat(100);
                
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode(original));
                        controller.close();
                    }
                });
                
                var compressed = stream.pipeThrough(new CompressionStream('deflate'));
                
                var chunks = [];
                var reader = compressed.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                var compressedSize = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
                var originalSize = encoder.encode(original).length;
                
                return compressedSize < originalSize;
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                isSmaller = result as Boolean
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertTrue("Deflate compressed data should be smaller", isSmaller)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCompressionDecompressionRoundTrip() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var testResult: Map<*, *>? = null

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var decoder = new TextDecoder();
                var original = 'The quick brown fox jumps over the lazy dog. '.repeat(20);
                
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode(original));
                        controller.close();
                    }
                });
                
                var result = stream
                    .pipeThrough(new CompressionStream('gzip'))
                    .pipeThrough(new DecompressionStream('gzip'));
                
                var chunks = [];
                var reader = result.getReader();
                
                while (true) {
                    var readResult = await reader.read();
                    if (readResult.done) break;
                    chunks.push(readResult.value);
                }
                
                var decompressed = decoder.decode(chunks[0]);
                return ({
                    original: original,
                    decompressed: decompressed,
                    match: original === decompressed,
                    length: decompressed.length
                });
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                testResult = result as? Map<*, *>
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertNotNull("Should have result", testResult)

        val match = testResult!!["match"] as Boolean
        val originalLength = (testResult!!["original"] as String).length
        val decompressedLength = (testResult!!["length"] as Number).toInt()

        assertTrue("Round trip should preserve data", match)
        assertEquals("Lengths should match", originalLength, decompressedLength)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCompressionStreamDeflateRaw() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var roundTripMatch = false

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var decoder = new TextDecoder();
                var original = 'Deflate-raw test data. '.repeat(30);
                
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode(original));
                        controller.close();
                    }
                });
                
                var compressed = stream.pipeThrough(new CompressionStream('deflate-raw'));
                var compressedChunks = [];
                var reader = compressed.getReader();
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    compressedChunks.push(result.value);
                }
                
                // Decompress
                var compressedStream = new ReadableStream({
                    start(controller) {
                        for (var chunk of compressedChunks) {
                            controller.enqueue(chunk);
                        }
                        controller.close();
                    }
                });
                var decompressed = compressedStream.pipeThrough(new DecompressionStream('deflate-raw'));
                
                var decompressedChunks = [];
                reader = decompressed.getReader();
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    decompressedChunks.push(result.value);
                }
                
                var result = decoder.decode(decompressedChunks[0]);
                return original === result;
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                roundTripMatch = result as Boolean
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertTrue("Deflate-raw round trip should preserve data", roundTripMatch)
        } finally {
            engine.close()
        }
    }
}
