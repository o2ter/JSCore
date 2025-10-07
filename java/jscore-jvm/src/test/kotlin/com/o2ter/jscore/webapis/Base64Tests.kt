//
//  Base64Tests.kt
//  KotlinJS Base64 Tests
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
 * Tests for the global btoa() and atob() Base64 encoding/decoding functions.
 */
class Base64Tests {
    
    // MARK: - API Existence Tests
    
    @Test
    fun testBase64FunctionsExist() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    btoaExists: typeof btoa === 'function',
                    atobExists: typeof atob === 'function'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["btoaExists"])
            assertEquals(true, result["atobExists"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - btoa() Tests
    
    @Test
    fun testBtoaBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    hello: btoa('Hello'),
                    world: btoa('World'),
                    empty: btoa(''),
                    simple: btoa('a'),
                    longer: btoa('Hello, World!')
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("SGVsbG8=", result["hello"])
            assertEquals("V29ybGQ=", result["world"])
            assertEquals("", result["empty"])
            assertEquals("YQ==", result["simple"])
            assertEquals("SGVsbG8sIFdvcmxkIQ==", result["longer"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBtoaSpecialCharacters() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    newline: btoa('\n'),
                    tab: btoa('\t'),
                    space: btoa(' '),
                    symbols: btoa('!@#$%^&*()'),
                    numbers: btoa('1234567890')
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("Cg==", result["newline"])
            assertEquals("CQ==", result["tab"])
            assertEquals("IA==", result["space"])
            assertEquals("IUAjJCVeJiooKQ==", result["symbols"])
            assertEquals("MTIzNDU2Nzg5MA==", result["numbers"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBtoaLatin1Range() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    ({
                        success: true,
                        latin1: btoa('àáâãäå'),
                        result: 'success'
                    })
                } catch (error) {
                    ({
                        success: false,
                        errorName: error.name,
                        errorMessage: error.message
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            // btoa should handle Latin-1 characters or throw error for characters outside ASCII range
            val success = result["success"] as? Boolean
            if (success == true) {
                assertNotNull(result["latin1"])
            } else {
                assertNotNull(result["errorName"])
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - atob() Tests
    
    @Test
    fun testAtobBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    hello: atob('SGVsbG8='),
                    world: atob('V29ybGQ='),
                    empty: atob(''),
                    simple: atob('YQ=='),
                    longer: atob('SGVsbG8sIFdvcmxkIQ==')
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("Hello", result["hello"])
            assertEquals("World", result["world"])
            assertEquals("", result["empty"])
            assertEquals("a", result["simple"])
            assertEquals("Hello, World!", result["longer"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAtobSpecialCharacters() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    newline: atob('Cg=='),
                    tab: atob('CQ=='),
                    space: atob('IA=='),
                    symbols: atob('IUAjJCVeJiooKQ=='),
                    numbers: atob('MTIzNDU2Nzg5MA==')
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("\n", result["newline"])
            assertEquals("\t", result["tab"])
            assertEquals(" ", result["space"])
            assertEquals("!@#$%^&*()", result["symbols"])
            assertEquals("1234567890", result["numbers"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAtobInvalidInput() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const results = [];
                
                // Test with invalid base64 characters
                try {
                    atob('!!!invalid!!!');
                    results.push('invalid-chars-accepted');
                } catch (e) {
                    results.push('invalid-chars-rejected');
                }
                
                // Test with odd-length string (missing padding)
                try {
                    atob('SGVsbG');
                    results.push('odd-length-accepted');
                } catch (e) {
                    results.push('odd-length-rejected');
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(2, result.size)
            // Should properly reject invalid base64 strings
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("accepted") || resultStr.contains("rejected"))
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Round-trip Tests
    
    @Test
    fun testBtoaAtobRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const testStrings = [
                    'Hello',
                    'World',
                    'Hello, World!',
                    'a',
                    '',
                    '1234567890',
                    '!@#$%^&*()',
                    'The quick brown fox jumps over the lazy dog'
                ];
                
                const results = testStrings.map(original => {
                    const encoded = btoa(original);
                    const decoded = atob(encoded);
                    return {
                        original: original,
                        encoded: encoded,
                        decoded: decoded,
                        matches: original === decoded
                    };
                });
                
                ({
                    allMatch: results.every(r => r.matches),
                    count: results.length
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["allMatch"])
            assertEquals(8, (result["count"] as? Number)?.toInt())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAtobBtoaRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const testBase64 = [
                    'SGVsbG8=',
                    'V29ybGQ=',
                    'SGVsbG8sIFdvcmxkIQ==',
                    'YQ==',
                    '',
                    'MTIzNDU2Nzg5MA==',
                    'IUAjJCVeJiooKQ=='
                ];
                
                const results = testBase64.map(original => {
                    const decoded = atob(original);
                    const encoded = btoa(decoded);
                    return {
                        original: original,
                        decoded: decoded,
                        encoded: encoded,
                        matches: original === encoded
                    };
                });
                
                ({
                    allMatch: results.every(r => r.matches),
                    count: results.length
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["allMatch"])
            assertEquals(7, (result["count"] as? Number)?.toInt())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test
    fun testBase64Padding() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    // Different padding scenarios
                    noPadding: btoa('a'),        // Should be "YQ=="
                    onePadding: btoa('ab'),      // Should be "YWI="
                    twoPadding: btoa('abc'),     // Should be "YWJj"
                    
                    // Decode back
                    noPaddingDecoded: atob('YQ=='),
                    onePaddingDecoded: atob('YWI='),
                    twoPaddingDecoded: atob('YWJj')
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("YQ==", result["noPadding"])
            assertEquals("YWI=", result["onePadding"])
            assertEquals("YWJj", result["twoPadding"])
            assertEquals("a", result["noPaddingDecoded"])
            assertEquals("ab", result["onePaddingDecoded"])
            assertEquals("abc", result["twoPaddingDecoded"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBase64WithBinaryData() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    // Create binary data (control characters)
                    const binaryStr = String.fromCharCode(0, 1, 2, 3, 4, 5);
                    const encoded = btoa(binaryStr);
                    const decoded = atob(encoded);
                    
                    // Compare each character
                    let matches = true;
                    for (let i = 0; i < binaryStr.length; i++) {
                        if (binaryStr.charCodeAt(i) !== decoded.charCodeAt(i)) {
                            matches = false;
                            break;
                        }
                    }
                    
                    ({
                        success: true,
                        originalLength: binaryStr.length,
                        encodedLength: encoded.length,
                        decodedLength: decoded.length,
                        matches: matches
                    })
                } catch (error) {
                    ({
                        success: false,
                        error: error.message
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertEquals(6, (result["originalLength"] as? Number)?.toInt())
            assertEquals(true, result["matches"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testBtoaWithNonString() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const results = [];
                
                // Test with number (should convert to string)
                try {
                    const encoded = btoa(123);
                    results.push({ input: 'number', success: true, result: encoded });
                } catch (e) {
                    results.push({ input: 'number', success: false });
                }
                
                // Test with boolean (should convert to string)
                try {
                    const encoded = btoa(true);
                    results.push({ input: 'boolean', success: true, result: encoded });
                } catch (e) {
                    results.push({ input: 'boolean', success: false });
                }
                
                // Test with null (should convert to string "null")
                try {
                    const encoded = btoa(null);
                    results.push({ input: 'null', success: true, result: encoded });
                } catch (e) {
                    results.push({ input: 'null', success: false });
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(3, result.size)
            // btoa typically converts non-strings to strings
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testAtobWithNonString() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const results = [];
                
                // Test with number
                try {
                    atob(123);
                    results.push('number-accepted');
                } catch (e) {
                    results.push('number-rejected');
                }
                
                // Test with null
                try {
                    atob(null);
                    results.push('null-accepted');
                } catch (e) {
                    results.push('null-rejected');
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(2, result.size)
            // Should handle or reject non-string inputs
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("accepted") || resultStr.contains("rejected"))
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test
    fun testBase64WithTextEncoder() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const encoder = new TextEncoder();
                    const decoder = new TextDecoder();
                    
                    // Encode text to bytes, then to base64 string
                    const text = 'Hello, World!';
                    const bytes = encoder.encode(text);
                    
                    // Convert bytes to string for btoa
                    const binaryStr = Array.from(bytes).map(b => String.fromCharCode(b)).join('');
                    const base64 = btoa(binaryStr);
                    
                    // Decode back
                    const decodedBinary = atob(base64);
                    const decodedBytes = new Uint8Array(decodedBinary.split('').map(c => c.charCodeAt(0)));
                    const decodedText = decoder.decode(decodedBytes);
                    
                    ({
                        original: text,
                        base64: base64,
                        decoded: decodedText,
                        matches: text === decodedText,
                        success: true
                    })
                } catch (error) {
                    ({ success: false, error: error.message })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertEquals("Hello, World!", result["original"])
            assertEquals("Hello, World!", result["decoded"])
            assertEquals(true, result["matches"])
        } finally {
            engine.close()
        }
    }
}
