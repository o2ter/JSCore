//
//  JSBridge.kt
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

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.V8Value
import kotlin.reflect.KProperty1
import kotlin.reflect.full.memberProperties

/**
 * Helper class for easy conversion between Kotlin and JavaScript values/functions
 * Provides a simple API for creating native bridges and exposing Kotlin functionality to JavaScript
 */
class JSBridge(private val v8Runtime: V8Runtime) {

    fun createJSObject(value: Any?): V8Value {
        return when (value) {
            null -> v8Runtime.createV8ValueNull()
            is Boolean -> v8Runtime.createV8ValueBoolean(value)
            is Int -> v8Runtime.createV8ValueInteger(value)
            is Long -> v8Runtime.createV8ValueLong(value)
            is Float -> v8Runtime.createV8ValueDouble(value.toDouble())
            is Double -> v8Runtime.createV8ValueDouble(value)
            is String -> v8Runtime.createV8ValueString(value)
            is V8Value -> value // Already a JS value
            else -> {
                val handler = v8Runtime.createV8ValueObject()
                handler.bindFunction(JavetCallbackContext(
                    "ownKeys",
                    JavetCallbackType.DirectCallNoThisAndResult,
                    IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                        val array = v8Runtime.createV8ValueArray()
                        value::class.memberProperties.forEachIndexed { index, entry ->
                            array.set(index, entry.name)
                        }
                        array
                    }
                ))
                handler.bindFunction(JavetCallbackContext(
                    "get",
                    JavetCallbackType.DirectCallNoThisAndResult,
                    IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                        val prop = v8Values[1].toString()
                        val property = value::class.memberProperties.find { it.name == prop }
                        if (property != null) {
                            val propValue = (property as KProperty1<Any, *>).get(value)
                            return@NoThisAndResult createJSObject(propValue)
                        }
                        v8Runtime.createV8ValueUndefined()
                    }
                ))
                v8Runtime.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)}
        }
    }
}
