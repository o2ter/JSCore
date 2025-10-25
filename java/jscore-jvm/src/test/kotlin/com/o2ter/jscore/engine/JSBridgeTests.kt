package com.o2ter.jscore

import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class JSBridgeTests {


    private fun getJSBridge(engine: JavaScriptEngine): JSBridge =
        engine.javaClass.getDeclaredField("jsBridge").apply { isAccessible = true }.get(engine) as JSBridge

    @Test
    fun testConvertJSArrayToKotlinList() {
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
        val jsBridge = getJSBridge(engine)
        try {
            // createJSObject for list returns undefined (not implemented), so test via engine.set
            val list = listOf(10, 20, 30)
            engine.set("kList", list)
            val result = engine.execute("Array.isArray(kList) ? kList.slice() : null")
            // Should be null since list proxy is not implemented, but test for no crash
            assertTrue(result == list)
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlinMapRoundTrip() {
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
        val jsBridge = getJSBridge(engine)
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
        val jsBridge = getJSBridge(engine)
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
        val jsBridge = getJSBridge(engine)
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
        try {
            assertNull(engine.execute("null"))
            assertNull(engine.execute("undefined"))
        } finally {
            engine.close()
        }
    }

    @Test
    fun testCreateJSObjectFromKotlin() {
        val engine = JavaScriptEngine(JvmPlatformContext("TestApp"))
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
