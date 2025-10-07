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
import com.caoccao.javet.values.primitive.*
import com.caoccao.javet.values.reference.*

/**
 * Helper class for easy conversion between Kotlin and JavaScript values/functions
 * Provides a simple API for creating native bridges and exposing Kotlin functionality to JavaScript
 */
class JSBridge(private val v8Runtime: V8Runtime) {
    
    // ====================
    // Value Conversion API
    // ====================
    
    /**
     * Convert Kotlin value to JavaScript value
     */
    fun toJS(value: Any?): V8Value {
        return when (value) {
            null -> v8Runtime.createV8ValueNull()
            is Boolean -> v8Runtime.createV8ValueBoolean(value)
            is Int -> v8Runtime.createV8ValueInteger(value)
            is Long -> v8Runtime.createV8ValueLong(value)
            is Float -> v8Runtime.createV8ValueDouble(value.toDouble())
            is Double -> v8Runtime.createV8ValueDouble(value)
            is String -> v8Runtime.createV8ValueString(value)
            is ByteArray -> createUint8Array(value)
            is IntArray -> createTypedArray(value)
            is DoubleArray -> createTypedArray(value)
            is Array<*> -> createArray(value.toList())
            is List<*> -> createArray(value)
            is Map<*, *> -> createObject(value)
            is V8Value -> value // Already a JS value
            else -> v8Runtime.createV8ValueString(value.toString())
        }
    }
    
    /**
     * Convert JavaScript value to Kotlin value
     */
    fun fromJS(value: V8Value): Any? {
        return when {
            value.isUndefined || value.isNull -> null
            value is V8ValueBoolean -> value.value
            value is V8ValueInteger -> value.value
            value is V8ValueLong -> value.value
            value is V8ValueDouble -> value.value
            value is V8ValueString -> value.value
            value is V8ValueArray -> convertArray(value)
            value is V8ValueTypedArray -> value // Return TypedArray as-is for now
            value is V8ValueArrayBuffer -> value // Return ArrayBuffer as-is for now
            value is V8ValueObject -> convertObject(value)
            else -> value.toString()
        }
    }
    
    // ====================
    // Function Binding API
    // ====================
    
    /**
     * Create a JavaScript function from a Kotlin lambda (no return value)
     */
    fun createVoidFunction(function: (List<Any?>) -> Unit): V8ValueFunction {
        val callback = IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
            val args = v8Values?.map { fromJS(it) } ?: emptyList()
            function(args)
        }
        val context = JavetCallbackContext("kotlinFunction", JavetCallbackType.DirectCallNoThisAndNoResult, callback)
        return v8Runtime.createV8ValueFunction(context)
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (with return value)
     */
    fun createFunction(function: (List<Any?>) -> Any?): V8ValueFunction {
        val callback = IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
            val args = v8Values?.map { fromJS(it) } ?: emptyList()
            val result = function(args)
            toJS(result)
        }
        val context = JavetCallbackContext("kotlinFunction", JavetCallbackType.DirectCallNoThisAndResult, callback)
        return v8Runtime.createV8ValueFunction(context)
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (0 args, return value)
     */
    fun createFunction0(function: () -> Any?): V8ValueFunction {
        return createFunction { function() }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (1 arg, return value)
     */
    fun createFunction1(function: (Any?) -> Any?): V8ValueFunction {
        return createFunction { args -> function(args.getOrNull(0)) }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (2 args, return value)
     */
    fun createFunction2(function: (Any?, Any?) -> Any?): V8ValueFunction {
        return createFunction { args -> function(args.getOrNull(0), args.getOrNull(1)) }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (3 args, return value)
     */
    fun createFunction3(function: (Any?, Any?, Any?) -> Any?): V8ValueFunction {
        return createFunction { args -> function(args.getOrNull(0), args.getOrNull(1), args.getOrNull(2)) }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (0 args, void)
     */
    fun createVoidFunction0(function: () -> Unit): V8ValueFunction {
        return createVoidFunction { function() }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (1 arg, void)
     */
    fun createVoidFunction1(function: (Any?) -> Unit): V8ValueFunction {
        return createVoidFunction { args -> function(args.getOrNull(0)) }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (2 args, void)
     */
    fun createVoidFunction2(function: (Any?, Any?) -> Unit): V8ValueFunction {
        return createVoidFunction { args -> function(args.getOrNull(0), args.getOrNull(1)) }
    }
    
    /**
     * Create a JavaScript function from a Kotlin lambda (3 args, void)
     */
    fun createVoidFunction3(function: (Any?, Any?, Any?) -> Unit): V8ValueFunction {
        return createVoidFunction { args -> function(args.getOrNull(0), args.getOrNull(1), args.getOrNull(2)) }
    }
    
    // ====================
    // Object Creation API
    // ====================
    
    /**
     * Create a JavaScript object from a Map
     */
    fun createObject(map: Map<*, *>): V8ValueObject {
        val obj = v8Runtime.createV8ValueObject()
        map.forEach { (key, value) ->
            val keyStr = key.toString()
            val jsValue = toJS(value)
            try {
                obj.set(keyStr, jsValue)
            } finally {
                if (jsValue != value) jsValue.close() // Close if we created a new V8Value
            }
        }
        return obj
    }
    
    /**
     * Create a JavaScript object with DSL-style builder
     */
    fun createObject(builder: JSObjectBuilder.() -> Unit): V8ValueObject {
        val objBuilder = JSObjectBuilder(this)
        objBuilder.builder()
        return objBuilder.build()
    }
    
    /**
     * Create a JavaScript array from a List
     */
    fun createArray(list: List<*>): V8ValueArray {
        val array = v8Runtime.createV8ValueArray()
        list.forEachIndexed { index, value ->
            val jsValue = toJS(value)
            try {
                array.set(index, jsValue)
            } finally {
                if (jsValue != value) jsValue.close()
            }
        }
        return array
    }
    
    /**
     * Create a Uint8Array from ByteArray
     */
    fun createUint8Array(bytes: ByteArray): V8Value {
        val code = buildString {
            append("new Uint8Array([")
            bytes.forEachIndexed { index, byte ->
                if (index > 0) append(", ")
                append(byte.toInt() and 0xFF)
            }
            append("])")
        }
        return v8Runtime.getExecutor(code).execute<V8Value>()
    }
    
    /**
     * Create a typed array from IntArray
     */
    fun createTypedArray(ints: IntArray): V8Value {
        val code = "new Int32Array([${ints.joinToString(", ")}])"
        return v8Runtime.getExecutor(code).execute<V8Value>()
    }
    
    /**
     * Create a typed array from DoubleArray
     */
    fun createTypedArray(doubles: DoubleArray): V8Value {
        val code = "new Float64Array([${doubles.joinToString(", ")}])"
        return v8Runtime.getExecutor(code).execute<V8Value>()
    }
    
    // ====================
    // Utility Methods
    // ====================
    
    /**
     * Execute JavaScript code with automatic value conversion
     */
    fun eval(code: String): Any? {
        val result = v8Runtime.getExecutor(code).execute<V8Value>()
        return try {
            fromJS(result)
        } finally {
            result.close()
        }
    }
    
    /**
     * Execute JavaScript code without return value
     */
    fun evalVoid(code: String) {
        v8Runtime.getExecutor(code).executeVoid()
    }
    
    /**
     * Set a global variable in JavaScript
     */
    fun setGlobal(name: String, value: Any?) {
        val jsValue = toJS(value)
        try {
            v8Runtime.globalObject.set(name, jsValue)
        } finally {
            if (jsValue != value) jsValue.close()
        }
    }
    
    /**
     * Get a global variable from JavaScript
     */
    fun getGlobal(name: String): Any? {
        val jsValue = v8Runtime.globalObject.get<V8Value>(name)
        return try {
            fromJS(jsValue)
        } finally {
            jsValue?.close()
        }
    }
    
    // ====================
    // Private Helper Methods
    // ====================
    
    private fun convertArray(array: V8ValueArray): List<Any?> {
        val result = mutableListOf<Any?>()
        for (i in 0 until array.length) {
            val value = array.get<V8Value>(i)
            try {
                result.add(fromJS(value))
            } finally {
                value.close()
            }
        }
        return result
    }
    
    private fun convertObject(obj: V8ValueObject): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        val keys = obj.ownPropertyNames
        try {
            for (i in 0 until keys.length) {
                val key = keys.getString(i)
                val value = obj.get<V8Value>(key)
                try {
                    result[key] = fromJS(value)
                } finally {
                    value.close()
                }
            }
        } finally {
            keys.close()
        }
        return result
    }
}

/**
 * DSL builder for creating JavaScript objects
 */
class JSObjectBuilder(private val bridge: JSBridge) {
    private val properties = mutableMapOf<String, Any?>()
    
    /**
     * Set a property value
     */
    infix fun String.to(value: Any?) {
        properties[this] = value
    }
    
    /**
     * Set a function property
     */
    fun String.func(function: (List<Any?>) -> Any?) {
        properties[this] = bridge.createFunction(function)
    }
    
    /**
     * Set a void function property
     */
    fun String.voidFunc(function: (List<Any?>) -> Unit) {
        properties[this] = bridge.createVoidFunction(function)
    }
    
    /**
     * Set a 0-arg function property
     */
    fun String.func0(function: () -> Any?) {
        properties[this] = bridge.createFunction0(function)
    }
    
    /**
     * Set a 1-arg function property
     */
    fun String.func1(function: (Any?) -> Any?) {
        properties[this] = bridge.createFunction1(function)
    }
    
    /**
     * Set a 2-arg function property
     */
    fun String.func2(function: (Any?, Any?) -> Any?) {
        properties[this] = bridge.createFunction2(function)
    }
    
    /**
     * Set a 3-arg function property
     */
    fun String.func3(function: (Any?, Any?, Any?) -> Any?) {
        properties[this] = bridge.createFunction3(function)
    }
    
    internal fun build(): V8ValueObject {
        return bridge.createObject(properties)
    }
}

/**
 * Extension functions for easier native bridge creation
 */

/**
 * Add a Kotlin function to a JavaScript object with automatic binding
 */
fun V8ValueObject.addFunction(name: String, bridge: JSBridge, function: (List<Any?>) -> Any?) {
    val jsFunction = bridge.createFunction(function)
    try {
        this.set(name, jsFunction)
    } finally {
        jsFunction.close()
    }
}

/**
 * Add a Kotlin void function to a JavaScript object with automatic binding
 */
fun V8ValueObject.addVoidFunction(name: String, bridge: JSBridge, function: (List<Any?>) -> Unit) {
    val jsFunction = bridge.createVoidFunction(function)
    try {
        this.set(name, jsFunction)
    } finally {
        jsFunction.close()
    }
}

/**
 * Add a Kotlin value to a JavaScript object with automatic conversion
 */
fun V8ValueObject.addValue(name: String, bridge: JSBridge, value: Any?) {
    val jsValue = bridge.toJS(value)
    try {
        this.set(name, jsValue)
    } finally {
        if (jsValue != value) jsValue.close()
    }
}