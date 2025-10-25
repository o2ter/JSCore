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
import kotlin.reflect.KType
import kotlin.reflect.full.memberFunctions
import kotlin.reflect.full.memberProperties
import kotlin.reflect.jvm.ExperimentalReflectionOnLambdas
import kotlin.reflect.jvm.reflect

/**
 * Helper class for easy conversion between Kotlin and JavaScript values/functions
 * Provides a simple API for creating native bridges and exposing Kotlin functionality to JavaScript
 */
class JSBridge(private val v8Runtime: V8Runtime) {

    fun createJSObject(value: Any?): V8Value {
        return when (value) {
            null -> v8Runtime.createV8ValueUndefined()
            is Boolean -> v8Runtime.createV8ValueBoolean(value)
            is Int -> v8Runtime.createV8ValueInteger(value)
            is Long -> v8Runtime.createV8ValueLong(value)
            is Float -> v8Runtime.createV8ValueDouble(value.toDouble())
            is Double -> v8Runtime.createV8ValueDouble(value)
            is String -> v8Runtime.createV8ValueString(value)
            is V8Value -> value // Already a JS value
            is List<*> -> createListProxy(value)
            is Map<*, *> -> createMapProxy(value)
            is Function<*> -> createJSFunction(value, null)
            else -> createProxy(value)
        }
    }

    private fun createListProxy(value: List<*>): V8Value {
        // TODO: Implement array proxy
        return v8Runtime.createV8ValueUndefined()
    }

    private fun createMapProxy(value: Map<*, *>): V8Value {
        val handler = v8Runtime.createV8ValueObject()
        handler.bindFunction(JavetCallbackContext(
            "ownKeys",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                val array = v8Runtime.createV8ValueArray()
                value.keys.forEachIndexed { index, entry ->
                    array.set(index, entry.toString())
                }
                array
            }
        ))
        handler.bindFunction(JavetCallbackContext(
            "get",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                val prop = v8Values[1].toString()
                createJSObject(value[prop])
            }
        ))
        return v8Runtime.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)
    }

    private fun createProxy(value: Any): V8Value {
        val handler = v8Runtime.createV8ValueObject()
        handler.bindFunction(JavetCallbackContext(
            "ownKeys",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                val array = v8Runtime.createV8ValueArray()
                value::class.memberProperties.forEachIndexed { index, entry ->
                    array.set(index, entry.name)
                }
                value::class.memberFunctions.forEachIndexed { index, entry ->
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
                val method = value::class.memberFunctions.find { it.name == prop }
                if (method != null) {
                    return@NoThisAndResult createJSFunction(method, value)
                }
                v8Runtime.createV8ValueUndefined()
            }
        ))
        return v8Runtime.invokeFunction("(function(handler) { return new Proxy({}, handler); })".trimIndent(), handler)
    }

    @OptIn(ExperimentalReflectionOnLambdas::class)
    private fun createJSFunction(value: Function<*>, thisObj: Any?): V8Value {
        val func = value.reflect()
        if (func == null) {
            return v8Runtime.createV8ValueUndefined()
        }
        v8Runtime.createV8ValueFunction(JavetCallbackContext(
            func.name,
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                val args = arrayOfNulls<Any>(func.parameters.size)
                v8Values.forEachIndexed { index, entry ->
                    if (index > 0 && index <= func.parameters.size) { // Skip the first argument which is 'this'
                        val param = func.parameters[index - 1]
                        if (param.isOptional && entry.isNullOrUndefined) {
                            args[index - 1] = null
                        } else {
                            args[index - 1] = convertNativeValue(param.type, entry)
                        }
                    }
                }
                val result = func.call(*args)
                return@NoThisAndResult createJSObject(result)
            }
        ))
    }

    private fun convertNativeValue(type: KType, value: V8Value): Any? {
        return when (type.classifier) {
            Boolean::class -> value.asBoolean()
            Int::class -> value.asInt()
            Long::class -> value.asLong()
            Float::class -> value.asDouble().toFloat()
            Double::class -> value.asDouble()
            String::class -> value.toString()
            else -> null // TODO: Handle more complex types
        }
    }
}
