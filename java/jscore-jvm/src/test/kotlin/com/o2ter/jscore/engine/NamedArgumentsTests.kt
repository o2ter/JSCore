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
import kotlin.test.assertNotNull

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
                "value === undefined"
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

    @Test
    fun testMapObjectPropertyAccess() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "config" to mapOf(
                        "host" to "example.com",
                        "port" to 8080,
                        "secure" to true
                    )
                ),
                """
                ({
                    host: config.host,
                    port: config.port,
                    secure: config.secure,
                    url: config.host + ':' + config.port
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("example.com", map["host"])
            assertEquals(8080, map["port"])
            assertEquals(true, map["secure"])
            assertEquals("example.com:8080", map["url"])
        }
    }

    @Test
    fun testListArrayAccess() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "items" to listOf("apple", "banana", "cherry")
                ),
                """
                ({
                    first: items[0],
                    second: items[1],
                    third: items[2],
                    length: items.length,
                    joined: items.join(', ')
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("apple", map["first"])
            assertEquals("banana", map["second"])
            assertEquals("cherry", map["third"])
            assertEquals(3, map["length"])
            assertEquals("apple, banana, cherry", map["joined"])
        }
    }

    @Test
    fun testNestedObjects() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "data" to mapOf(
                        "user" to mapOf(
                            "name" to "Alice",
                            "age" to 30,
                            "tags" to listOf("admin", "developer")
                        ),
                        "settings" to mapOf(
                            "theme" to "dark",
                            "notifications" to true
                        )
                    )
                ),
                """
                ({
                    userName: data.user.name,
                    userAge: data.user.age,
                    firstTag: data.user.tags[0],
                    tagCount: data.user.tags.length,
                    theme: data.settings.theme,
                    notifications: data.settings.notifications
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals("Alice", map["userName"])
            assertEquals(30, map["userAge"])
            assertEquals("admin", map["firstTag"])
            assertEquals(2, map["tagCount"])
            assertEquals("dark", map["theme"])
            assertEquals(true, map["notifications"])
        }
    }

    @Test
    fun testObjectEnumeration() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "obj" to mapOf(
                        "a" to 1,
                        "b" to 2,
                        "c" to 3
                    )
                ),
                """
                ({
                    keys: Object.keys(obj),
                    values: Object.values(obj),
                    entries: Object.entries(obj)
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            
            val keys = map["keys"] as? List<*>
            assertNotNull(keys)
            assertTrue(keys.containsAll(listOf("a", "b", "c")))
            
            val values = map["values"] as? List<*>
            assertNotNull(values)
            assertTrue(values.containsAll(listOf(1, 2, 3)))
            
            val entries = map["entries"] as? List<*>
            assertNotNull(entries)
            assertEquals(3, entries.size)
        }
    }

    @Test
    fun testArrayMethods() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "numbers" to listOf(1, 2, 3, 4, 5)
                ),
                """
                ({
                    filtered: numbers.filter(n => n > 2),
                    mapped: numbers.map(n => n * 2),
                    reduced: numbers.reduce((sum, n) => sum + n, 0),
                    some: numbers.some(n => n > 4),
                    every: numbers.every(n => n > 0),
                    find: numbers.find(n => n === 3)
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(listOf(3, 4, 5), map["filtered"])
            assertEquals(listOf(2, 4, 6, 8, 10), map["mapped"])
            assertEquals(15, map["reduced"])
            assertEquals(true, map["some"])
            assertEquals(true, map["every"])
            assertEquals(3, map["find"])
        }
    }

    @Test
    fun testComplexObjectModification() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "users" to listOf(
                        mapOf("name" to "Alice", "age" to 30),
                        mapOf("name" to "Bob", "age" to 25),
                        mapOf("name" to "Charlie", "age" to 35)
                    )
                ),
                """
                ({
                    names: users.map(u => u.name),
                    avgAge: users.reduce((sum, u) => sum + u.age, 0) / users.length,
                    adults: users.filter(u => u.age >= 30).map(u => u.name)
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(listOf("Alice", "Bob", "Charlie"), map["names"])
            // avgAge is 30 which may be returned as Int instead of Double
            val avgAge = map["avgAge"]
            assertTrue(avgAge is Number, "avgAge should be a Number, got ${avgAge?.javaClass}")
            assertEquals(30.0, (avgAge as Number).toDouble(), "avgAge should be 30")
            assertEquals(listOf("Alice", "Charlie"), map["adults"])
        }
    }

    @Test
    fun testMixedArrayTypes() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "mixed" to listOf(
                        1,
                        "two",
                        true,
                        mapOf("key" to "value"),
                        listOf(5, 6, 7)
                    )
                ),
                """
                ({
                    first: mixed[0],
                    second: mixed[1],
                    third: mixed[2],
                    fourthKey: mixed[3].key,
                    fifthFirst: mixed[4][0],
                    length: mixed.length
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(1, map["first"])
            assertEquals("two", map["second"])
            assertEquals(true, map["third"])
            assertEquals("value", map["fourthKey"])
            assertEquals(5, map["fifthFirst"])
            assertEquals(5, map["length"])
        }
    }

    @Test
    fun testObjectSpreadOperator() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "obj1" to mapOf("a" to 1, "b" to 2),
                    "obj2" to mapOf("c" to 3, "d" to 4)
                ),
                """
                ({
                    merged: {...obj1, ...obj2},
                    override: {...obj1, b: 10}
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            
            val merged = map["merged"] as? Map<*, *>
            assertNotNull(merged)
            assertEquals(1, merged["a"])
            assertEquals(2, merged["b"])
            assertEquals(3, merged["c"])
            assertEquals(4, merged["d"])
            
            val override = map["override"] as? Map<*, *>
            assertNotNull(override)
            assertEquals(1, override["a"])
            assertEquals(10, override["b"])
        }
    }

    @Test
    fun testArraySpreadOperator() {
        val context = JvmPlatformContext("TestApp")
        JavaScriptEngine(context).use { engine ->
            val result = engine.execute(
                mapOf(
                    "arr1" to listOf(1, 2, 3),
                    "arr2" to listOf(4, 5, 6)
                ),
                """
                ({
                    combined: [...arr1, ...arr2],
                    withExtra: [...arr1, 99, ...arr2]
                })
                """
            )
            
            assertTrue(result is Map<*, *>)
            val map = result as Map<*, *>
            assertEquals(listOf(1, 2, 3, 4, 5, 6), map["combined"])
            assertEquals(listOf(1, 2, 3, 99, 4, 5, 6), map["withExtra"])
        }
    }
}
