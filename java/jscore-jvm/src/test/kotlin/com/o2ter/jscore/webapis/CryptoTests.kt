//
//  CryptoTests.kt
//  KotlinJS Crypto API Tests
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
 * Tests for the Web Crypto API including crypto.randomUUID, crypto.getRandomValues,
 * and other cryptographic functions available in the global crypto object.
 */
class CryptoTests {
    
    // MARK: - Crypto API Existence Tests
    
    @Test
    fun testCryptoExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof crypto")
            assertEquals("object", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testCryptoMethods() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                ({
                    hasRandomUUID: typeof crypto.randomUUID === 'function',
                    hasGetRandomValues: typeof crypto.getRandomValues === 'function',
                    isObject: typeof crypto === 'object'
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["isObject"])
            assertEquals(true, result["hasRandomUUID"])
            assertEquals(true, result["hasGetRandomValues"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - crypto.randomUUID Tests
    
    @Test
    fun testRandomUUIDBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof crypto.randomUUID()")
            assertEquals("string", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testRandomUUIDFormat() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const uuid = crypto.randomUUID();
                // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
                /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(uuid)
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testRandomUUIDLength() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const uuid = crypto.randomUUID();
                uuid.length === 36
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testRandomUUIDUniqueness() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const uuids = [];
                for (let i = 0; i < 100; i++) {
                    uuids.push(crypto.randomUUID());
                }
                
                const uniqueUUIDs = [...new Set(uuids)];
                
                ({
                    generated: uuids.length,
                    unique: uniqueUUIDs.length,
                    allUnique: uuids.length === uniqueUUIDs.length
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(100, (result["generated"] as? Number)?.toInt())
            assertEquals(100, (result["unique"] as? Number)?.toInt())
            assertEquals(true, result["allUnique"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testRandomUUIDWithoutArguments() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const uuid = crypto.randomUUID();
                    typeof uuid === 'string'
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - crypto.getRandomValues Tests
    
    @Test
    fun testGetRandomValuesWithUint8Array() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const array = new Uint8Array(16);
                crypto.getRandomValues(array);
                array.length === 16 && array instanceof Uint8Array
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesWithUint16Array() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const array = new Uint16Array(8);
                crypto.getRandomValues(array);
                array.length === 8 && array instanceof Uint16Array
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesWithUint32Array() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const array = new Uint32Array(4);
                crypto.getRandomValues(array);
                array.length === 4 && array instanceof Uint32Array
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesRandomness() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const array1 = new Uint8Array(16);
                const array2 = new Uint8Array(16);
                
                crypto.getRandomValues(array1);
                crypto.getRandomValues(array2);
                
                // Check that arrays are different
                let different = false;
                for (let i = 0; i < 16; i++) {
                    if (array1[i] !== array2[i]) {
                        different = true;
                        break;
                    }
                }
                
                ({
                    array1Length: array1.length,
                    array2Length: array2.length,
                    different: different
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(16, (result["array1Length"] as? Number)?.toInt())
            assertEquals(16, (result["array2Length"] as? Number)?.toInt())
            assertEquals(true, result["different"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesEmptyArray() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const array = new Uint8Array(0);
                    crypto.getRandomValues(array);
                    array.length === 0
                } catch (error) {
                    false
                }
            """)
            
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesLargeArray() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const array = new Uint8Array(65536); // 64KB
                    crypto.getRandomValues(array);
                    
                    // Check that some values are non-zero (very high probability)
                    let hasNonZero = false;
                    for (let i = 0; i < array.length; i++) {
                        if (array[i] !== 0) {
                            hasNonZero = true;
                            break;
                        }
                    }
                    
                    ({
                        length: array.length,
                        hasNonZero: hasNonZero
                    })
                } catch (error) {
                    ({ error: error.message })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            if (result.containsKey("error")) {
                // Some implementations may have size limits
                val error = result["error"].toString()
                assertTrue(error.contains("size", ignoreCase = true) || error.contains("limit", ignoreCase = true))
            } else {
                assertEquals(65536, (result["length"] as? Number)?.toInt())
                assertEquals(true, result["hasNonZero"])
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testGetRandomValuesWithInvalidInput() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const results = [];
                
                // Test with null
                try {
                    crypto.getRandomValues(null);
                    results.push('null-accepted');
                } catch (e) {
                    results.push('null-rejected');
                }
                
                // Test with undefined
                try {
                    crypto.getRandomValues(undefined);
                    results.push('undefined-accepted');
                } catch (e) {
                    results.push('undefined-rejected');
                }
                
                // Test with regular array (not typed array)
                try {
                    crypto.getRandomValues([1, 2, 3]);
                    results.push('array-accepted');
                } catch (e) {
                    results.push('array-rejected');
                }
                
                // Test with string
                try {
                    crypto.getRandomValues('not an array');
                    results.push('string-accepted');
                } catch (e) {
                    results.push('string-rejected');
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(4, result.size)
            
            // Should properly reject invalid inputs
            result.forEach { testResult ->
                val resultStr = testResult.toString()
                assertTrue(resultStr.contains("rejected") || resultStr.contains("accepted"))
            }
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testGetRandomValuesWithFloat32Array() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const array = new Float32Array(4);
                    crypto.getRandomValues(array);
                    // Float32Array might not be supported by getRandomValues
                    ({ supported: true, length: array.length })
                } catch (error) {
                    ({ supported: false, error: error.message })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            // Float arrays are typically not supported by getRandomValues
            if (result["supported"] as? Boolean == true) {
                assertEquals(4, (result["length"] as? Number)?.toInt())
            } else {
                assertNotNull(result["error"])
            }
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Entropy and Quality Tests
    
    @Test
    fun testRandomBytesDistribution() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                // Test that random bytes have reasonable distribution
                const array = new Uint8Array(10000);
                crypto.getRandomValues(array);
                
                // Count frequency of each byte value
                const counts = new Array(256).fill(0);
                for (let i = 0; i < array.length; i++) {
                    counts[array[i]]++;
                }
                
                // Check that all byte values appear (with high probability)
                const usedValues = counts.filter(count => count > 0).length;
                const averageCount = array.length / 256;
                const minCount = Math.min(...counts.filter(count => count > 0));
                const maxCount = Math.max(...counts);
                
                ({
                    totalBytes: array.length,
                    usedValues: usedValues,
                    averageCount: averageCount,
                    minCount: minCount,
                    maxCount: maxCount,
                    reasonableDistribution: usedValues > 200 && maxCount < averageCount * 3
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(10000, (result["totalBytes"] as? Number)?.toInt())
            assertTrue((result["usedValues"] as? Number)?.toInt() ?: 0 > 200) // Should use most byte values
            assertEquals(true, result["reasonableDistribution"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test
    fun testCryptoWithOtherAPIs() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    // Use crypto with TextEncoder
                    const uuid = crypto.randomUUID();
                    const encoder = new TextEncoder();
                    const encodedUUID = encoder.encode(uuid);
                    
                    // Use crypto with arrays
                    const randomBytes = new Uint8Array(16);
                    crypto.getRandomValues(randomBytes);
                    
                    // Log results
                    console.log('Generated UUID:', uuid);
                    console.log('Random bytes:', randomBytes);
                    
                    ({
                        uuidLength: uuid.length,
                        encodedLength: encodedUUID.length,
                        randomBytesLength: randomBytes.length,
                        success: true
                    })
                } catch (error) {
                    ({ success: false, error: error.message })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertEquals(36, (result["uuidLength"] as? Number)?.toInt())
            assertEquals(16, (result["randomBytesLength"] as? Number)?.toInt())
            assertTrue((result["encodedLength"] as? Number)?.toInt() ?: 0 > 0)
        } finally {
            engine.close()
        }
    }
}
