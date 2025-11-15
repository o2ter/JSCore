/*
 * StreamingEncodingTests.kt
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

class StreamingEncodingTests {

    @Test
    fun testTextEncoderStream() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
            val testResult = executeAsync(engine, """
            (async () => {
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('Hello');
                        controller.enqueue(' ');
                        controller.enqueue('World');
                        controller.close();
                    }
                });
                
                var encoderStream = new TextEncoderStream();
                var encoded = stream.pipeThrough(encoderStream);
                
                var chunks = [];
                var reader = encoded.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                return ({
                    chunkCount: chunks.length,
                    totalBytes: chunks.reduce((sum, chunk) => sum + chunk.length, 0),
                    firstChunk: Array.from(chunks[0]),
                    isUint8Array: chunks[0] instanceof Uint8Array
                });
            })()
        """) as? Map<*, *>

            assertNotNull("Should have result", testResult)
            val chunkCount = (testResult!!["chunkCount"] as Number).toInt()
            val totalBytes = (testResult["totalBytes"] as Number).toInt()
            val isUint8Array = testResult["isUint8Array"] as Boolean

            assertTrue("Should have encoded chunks", chunkCount > 0)
            assertEquals("Should encode 'Hello World' (11 bytes)", 11, totalBytes)
            assertTrue("Chunks should be Uint8Array", isUint8Array)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testTextDecoderStream() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var testResult: Map<*, *>? = null

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode('Hello'));
                        controller.enqueue(encoder.encode(' '));
                        controller.enqueue(encoder.encode('World'));
                        controller.close();
                    }
                });
                
                var decoderStream = new TextDecoderStream();
                var decoded = stream.pipeThrough(decoderStream);
                
                var chunks = [];
                var reader = decoded.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                return ({
                    chunkCount: chunks.length,
                    fullText: chunks.join(''),
                    isString: typeof chunks[0] === 'string'
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

        val chunkCount = (testResult!!["chunkCount"] as Number).toInt()
        val fullText = testResult!!["fullText"] as String
        val isString = testResult!!["isString"] as Boolean

        assertTrue("Should have decoded chunks", chunkCount > 0)
        assertEquals("Should decode to 'Hello World'", "Hello World", fullText)
        assertTrue("Chunks should be strings", isString)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testTextEncoderStreamUTF8() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var totalBytes = 0

        val script = """
            (async () => {
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue('Hello 世界 🌍');
                        controller.close();
                    }
                });
                
                var encoderStream = new TextEncoderStream();
                var encoded = stream.pipeThrough(encoderStream);
                
                var chunks = [];
                var reader = encoded.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                return chunks.reduce((sum, chunk) => sum + chunk.length, 0);
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                totalBytes = (result as Number).toInt()
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        // "Hello 世界 🌍" = 5 + 1 + 6 + 1 + 4 = 17 bytes in UTF-8
        assertEquals("Should correctly encode multi-byte UTF-8 characters", 17, totalBytes)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testTextDecoderStreamUTF8() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var decodedText = ""

        val script = """
            (async () => {
                var encoder = new TextEncoder();
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(encoder.encode('Hello 世界 🌍'));
                        controller.close();
                    }
                });
                
                var decoderStream = new TextDecoderStream();
                var decoded = stream.pipeThrough(decoderStream);
                
                var chunks = [];
                var reader = decoded.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                return chunks.join('');
            })()
        """

        engine.executeAsync(script) { result, error ->
            if (error != null) {
                fail("JavaScript Error: ${error.message}")
            } else {
                decodedText = result as String
                latch.countDown()
            }
        }

        assertTrue("Test should complete within timeout", latch.await(10, TimeUnit.SECONDS))
        assertEquals("Should correctly decode multi-byte UTF-8 characters", "Hello 世界 🌍", decodedText)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testTextEncoderDecoderRoundTrip() {
        val engine = JavaScriptEngine(JvmPlatformContext())
        try {
        val latch = CountDownLatch(1)
        var testResult: Map<*, *>? = null

        val script = """
            (async () => {
                var original = 'Test string with émojis 🎉 and unicode ñ';
                
                var stream = new ReadableStream({
                    start(controller) {
                        controller.enqueue(original);
                        controller.close();
                    }
                });
                
                var encoded = stream.pipeThrough(new TextEncoderStream());
                var decoded = encoded.pipeThrough(new TextDecoderStream());
                
                var chunks = [];
                var reader = decoded.getReader();
                
                while (true) {
                    var result = await reader.read();
                    if (result.done) break;
                    chunks.push(result.value);
                }
                
                var result = chunks.join('');
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
        assertTrue("Encode/decode round trip should preserve original text", match)
        } finally {
            engine.close()
        }
    }
}
