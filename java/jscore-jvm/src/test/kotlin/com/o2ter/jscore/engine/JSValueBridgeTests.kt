//
//  JSValueBridgeTests.kt
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
import kotlin.test.assertNull
import kotlin.test.assertTrue

class JSValueBridgeTests {

    @Test
    fun testConvertJSArrayToKotlinList() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("[1, 2, 3]")
            assertTrue(result is List<*>)
            assertEquals(listOf(1, 2, 3), result)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSErrorObjectToKotlin() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("(function() { try { throw new Error('fail!') } catch(e) { return e; } })()")
            assertTrue(result is String)
            assertTrue(result.contains("fail!"))
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlinListRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val list = listOf(10, 20, 30)
            engine.set("kList", list)
            val result = engine.execute("Array.isArray(kList) ? kList.slice() : null")
            assertTrue(result == list)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlinMapRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val map = mapOf("foo" to 1, "bar" to 2)
            engine.set("kMap", map)
            val result = engine.execute("kMap.foo + kMap.bar")
            assertEquals(3, result)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlinFunctionRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val fn = { x: Int, y: Int -> x + y }
            engine.set("kFn", fn)
            // Should be callable from JS if reflection works, else undefined
            val result = engine.execute("typeof kFn === 'function' ? kFn(2, 3) : null")
            assertTrue(result == 5)
        } finally {
            engine.close()
        }
    }

    data class TestData(val a: Int, val b: String)

    @Test
    fun testCreateJSObjectFromKotlinDataClassRoundTrip() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val obj = TestData(7, "hi")
            engine.set("kObj", obj)
            val result = engine.execute("kObj.a + '-' + kObj.b")
            assertEquals("7-hi", result)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSFunctionToKotlinCall() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            engine.set("kotlinValue", 6)
            val result = engine.execute("(function(x, y) { return x * y; })(kotlinValue, 7)")
            assertEquals(42, result)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSNestedObject() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("({foo: {bar: [1,2,3]}, baz: 9})")
            assertTrue(result is Map<*, *>)
            val foo = (result as Map<*, *>) ["foo"]
            assertTrue(foo is Map<*, *>)
            val bar = (foo as Map<*, *>) ["bar"]
            assertEquals(listOf(1,2,3), bar)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSObjectWithNoProperties() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("Object.create(null)")
            assertTrue(result is Map<*, *>)
            assertTrue(result.isEmpty())
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSObjectToKotlinMap() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("({foo: 123, bar: 'baz'})")
            assertTrue(result is Map<*, *>)
            assertEquals(123, (result as Map<*, *>) ["foo"])
            assertEquals("baz", result["bar"])
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSPrimitivesToKotlin() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            assertEquals(42, engine.execute("42"))
            assertEquals(true, engine.execute("true"))
            assertEquals("hello", engine.execute("'hello'"))
            assertEquals(3.14, engine.execute("3.14"))
        } finally {
            engine.close()
        }
    }

    @Test
    fun testConvertJSNullAndUndefinedToKotlin() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            assertNull(engine.execute("null"))
            assertNull(engine.execute("undefined"))
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlin() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            engine.set("kInt", 42)
            engine.set("kBool", true)
            engine.set("kStr", "hello")
            engine.set("kDouble", 3.14)
            engine.set("kLong", 123456789L)

            assertEquals(42, engine.execute("kInt"))
            assertEquals(true, engine.execute("kBool"))
            assertEquals("hello", engine.execute("kStr"))
            assertEquals(3.14, engine.execute("kDouble"))
            assertEquals(123456789L, engine.execute("kLong"))
        } finally {
            engine.close()
        }
    }
}
