//
//  NamedArgumentsTests.kt
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

package com.o2ter.jscore

import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class NamedArgumentsTests {

    @Test
    fun testExecuteWithNamedArguments() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "url" to "https://example.com",
                    "timeout" to 30
                ),
                """
                ({
                    url: url,
                    timeout: timeout,
                    combined: url + ' - timeout: ' + timeout
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            assertEquals("https://example.com", (result as Map<*, *>)["url"])
            assertEquals(30, result["timeout"])
            assertEquals("https://example.com - timeout: 30", result["combined"])
        }
    }

    @Test
    fun testExecuteWithNamedArgumentsComplex() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "numbers" to listOf(1, 2, 3, 4, 5),
                    "multiplier" to 2
                ),
                """
                numbers.map(n => n * multiplier)
                """
            )
            
            assertTrue(result is List<*>)
            assertEquals(listOf(2, 4, 6, 8, 10), result)
        }
    }

    @Test
    fun testExecuteWithMixedTypes() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "str" to "hello",
                    "num" to 42,
                    "bool" to true,
                    "arr" to listOf(1, 2, 3),
                    "obj" to mapOf("key" to "value")
                ),
                """
                ({
                    string: str.toUpperCase(),
                    number: num * 2,
                    boolean: !bool,
                    array: arr.length,
                    object: obj.key
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("HELLO", map["string"])
            assertEquals(84, map["number"])
            assertEquals(false, map["boolean"])
            assertEquals(3, map["array"])
            assertEquals("value", map["object"])
        }
    }

    @Test
    fun testExecuteWithNoArguments() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                emptyMap(),
                "42 * 2"
            )
            
            assertEquals(84, result)
        }
    }

    @Test
    fun testExecuteWithNullArgument() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf("value" to null),
                "value === null"
            )
            
            assertEquals(true, result)
        }
    }

    @Test
    fun testExecuteWithFunctionCall() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "text" to "hello world",
                    "separator" to " "
                ),
                """
                text.split(separator).map(w => w.toUpperCase()).join('-')
                """
            )
            
            assertEquals("HELLO-WORLD", result)
        }
    }
}
