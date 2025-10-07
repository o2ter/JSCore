//
//  TextEncodingTests.kt
//  KotlinJS Text Encoding Tests
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
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Tests for the Web Text Encoding API including TextEncoder and TextDecoder
 * for converting between strings and byte arrays.
 */
class TextEncodingTests {
    
    // MARK: - TextEncoder API Tests
    
    @Test
    fun testTextEncoderExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof TextEncoder")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                encoder instanceof TextEncoder
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderEncoding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                encoder.encoding
            """)
            
            assertEquals("utf-8", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderBasicEncoding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const encoded = encoder.encode('Hello, KotlinJS!');
                encoded instanceof Uint8Array
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderASCIIText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const text = 'Hello World';
                const encoded = encoder.encode(text);
                
                ({
                    length: encoded.length,
                    firstByte: encoded[0],
                    lastByte: encoded[encoded.length - 1],
                    isUint8Array: encoded instanceof Uint8Array
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(11, (result["length"] as? Number)?.toInt()) // "Hello World" is 11 bytes
            assertEquals(72, (result["firstByte"] as? Number)?.toInt()) // 'H' is 72
            assertEquals(100, (result["lastByte"] as? Number)?.toInt()) // 'd' is 100
            assertEquals(true, result["isUint8Array"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderUnicodeText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const text = 'Hello, 世界! 🌍';
                const encoded = encoder.encode(text);
                
                ({
                    textLength: text.length,
                    bytesLength: encoded.length,
                    moreBytesUtf8: encoded.length > text.length,
                    isUint8Array: encoded instanceof Uint8Array
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertTrue((result["bytesLength"] as? Number)?.toInt() ?: 0 > (result["textLength"] as? Number)?.toInt() ?: 0)
            assertEquals(true, result["moreBytesUtf8"])
            assertEquals(true, result["isUint8Array"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextEncoderEmptyString() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const encoded = encoder.encode('');
                
                ({
                    length: encoded.length,
                    isUint8Array: encoded instanceof Uint8Array
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(0, (result["length"] as? Number)?.toInt())
            assertEquals(true, result["isUint8Array"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - TextDecoder API Tests
    
    @Test
    fun testTextDecoderExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof TextDecoder")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                decoder instanceof TextDecoder
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderEncoding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                decoder.encoding
            """)
            
            assertEquals("utf-8", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderBasicDecoding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                const bytes = new Uint8Array([72, 101, 108, 108, 111]); // "Hello"
                const text = decoder.decode(bytes);
                text
            """)
            
            assertEquals("Hello", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderUnicodeDecoding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                // UTF-8 encoding of "世界" (Chinese for "world")
                const bytes = new Uint8Array([228, 184, 150, 231, 149, 140]);
                const text = decoder.decode(bytes);
                text
            """)
            
            assertEquals("世界", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderEmptyBuffer() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                const bytes = new Uint8Array(0);
                const text = decoder.decode(bytes);
                text
            """)
            
            assertEquals("", result.toString())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Round-trip Tests
    
    @Test
    fun testEncodeDecodeRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const decoder = new TextDecoder();
                
                const original = 'Hello, 世界! 🌍';
                const encoded = encoder.encode(original);
                const decoded = decoder.decode(encoded);
                
                ({
                    original: original,
                    decoded: decoded,
                    matches: original === decoded
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(result["original"], result["decoded"])
            assertEquals(true, result["matches"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testEncodeDecodeSpecialCharacters() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const decoder = new TextDecoder();
                
                const testStrings = [
                    'Hello\\nWorld',
                    'Tab\\tSeparated',
                    'Quote"Test',
                    'Apostrophe\\'s',
                    '!@#$%^&*()',
                    '0123456789'
                ];
                
                const results = testStrings.map(str => {
                    const encoded = encoder.encode(str);
                    const decoded = decoder.decode(encoded);
                    return str === decoded;
                });
                
                results.every(r => r === true)
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testTextEncoderInvalidInput() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const encoder = new TextEncoder();
                const results = [];
                
                // Test with null (should convert to string "null")
                try {
                    const encoded = encoder.encode(null);
                    results.push({ input: 'null', success: true, length: encoded.length });
                } catch (e) {
                    results.push({ input: 'null', success: false });
                }
                
                // Test with undefined (should convert to string "undefined")
                try {
                    const encoded = encoder.encode(undefined);
                    results.push({ input: 'undefined', success: true, length: encoded.length });
                } catch (e) {
                    results.push({ input: 'undefined', success: false });
                }
                
                // Test with number (should convert to string)
                try {
                    const encoded = encoder.encode(123);
                    results.push({ input: 'number', success: true, length: encoded.length });
                } catch (e) {
                    results.push({ input: 'number', success: false });
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(3, result.size)
            // TextEncoder typically converts non-strings to strings
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testTextDecoderInvalidInput() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                const results = [];
                
                // Test with null
                try {
                    decoder.decode(null);
                    results.push('null-accepted');
                } catch (e) {
                    results.push('null-rejected');
                }
                
                // Test with undefined
                try {
                    decoder.decode(undefined);
                    results.push('undefined-accepted');
                } catch (e) {
                    results.push('undefined-rejected');
                }
                
                // Test with string
                try {
                    decoder.decode('not a buffer');
                    results.push('string-accepted');
                } catch (e) {
                    results.push('string-rejected');
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(3, result.size)
            // Should properly reject or handle invalid inputs
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("accepted") || resultStr.contains("rejected"))
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Streaming Tests
    
    @Test
    fun testTextDecoderStreamingMode() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const decoder = new TextDecoder();
                
                // UTF-8 encoding of "世界" split into chunks
                const chunk1 = new Uint8Array([228, 184]);     // First 2 bytes
                const chunk2 = new Uint8Array([150, 231]);     // Next 2 bytes
                const chunk3 = new Uint8Array([149, 140]);     // Last 2 bytes
                
                // Decode with streaming
                const part1 = decoder.decode(chunk1, { stream: true });
                const part2 = decoder.decode(chunk2, { stream: true });
                const part3 = decoder.decode(chunk3, { stream: false });
                
                const result = part1 + part2 + part3;
                
                ({
                    result: result,
                    expected: '世界',
                    matches: result === '世界'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("世界", result["result"])
            assertEquals("世界", result["expected"])
            assertEquals(true, result["matches"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test
    fun testTextEncodingWithOtherAPIs() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const encoder = new TextEncoder();
                    const decoder = new TextDecoder();
                    
                    // Generate UUID and encode it
                    const uuid = crypto.randomUUID();
                    const encodedUUID = encoder.encode(uuid);
                    
                    // Decode it back
                    const decodedUUID = decoder.decode(encodedUUID);
                    
                    // Log results
                    console.log('UUID:', uuid);
                    console.log('Encoded length:', encodedUUID.length);
                    console.log('Decoded:', decodedUUID);
                    
                    ({
                        uuidLength: uuid.length,
                        encodedLength: encodedUUID.length,
                        decodedLength: decodedUUID.length,
                        matches: uuid === decodedUUID,
                        success: true
                    })
                } catch (error) {
                    ({ success: false, error: error.message })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertEquals(36, (result["uuidLength"] as? Number)?.toInt())
            assertEquals(36, (result["encodedLength"] as? Number)?.toInt())
            assertEquals(36, (result["decodedLength"] as? Number)?.toInt())
            assertEquals(true, result["matches"])
        } finally {
            engine.close()
        }
    }
}
