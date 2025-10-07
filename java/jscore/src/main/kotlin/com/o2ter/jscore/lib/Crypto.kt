//
//  Crypto.kt
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

package com.o2ter.jscore.lib

import com.caoccao.javet.interop.V8Runtime
import com.caoccao.javet.interop.callback.IJavetDirectCallable
import com.caoccao.javet.interop.callback.JavetCallbackContext
import com.caoccao.javet.interop.callback.JavetCallbackType
import com.caoccao.javet.values.primitive.V8ValueInteger
import com.caoccao.javet.values.reference.V8ValueObject
import com.caoccao.javet.values.reference.V8ValueTypedArray
import com.o2ter.jscore.PlatformContext
import java.security.SecureRandom

/**
 * Crypto native bridge
 * Exposes cryptographic functions to JavaScript via __NATIVE_BRIDGE__.crypto
 */
class Crypto(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    private val secureRandom = SecureRandom()
    
    fun setupBridge(nativeBridge: V8ValueObject) {
        val cryptoObject = v8Runtime.createV8ValueObject()
        
        try {
            // randomUUID() - generate UUID v4
            cryptoObject.bindFunction(JavetCallbackContext(
                "randomUUID",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueString(java.util.UUID.randomUUID().toString())
                }
            ))
            
            // randomBytes(length) - generate random bytes
            cryptoObject.bindFunction(JavetCallbackContext(
                "randomBytes",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueInteger) {
                        throw RuntimeException("randomBytes requires a length argument")
                    }
                    
                    val length = (v8Values[0] as V8ValueInteger).value
                    
                    if (length <= 0 || length > 65536) {
                        throw RuntimeException("Invalid length for randomBytes: $length")
                    }
                    
                    val bytes = ByteArray(length)
                    secureRandom.nextBytes(bytes)
                    
                    val array = v8Runtime.createV8ValueTypedArray(
                        com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                        length
                    )
                    array.fromBytes(bytes)
                    array
                }
            ))
            
            // getRandomValues(buffer) - fill TypedArray with random values
            cryptoObject.bindFunction(JavetCallbackContext(
                "getRandomValues",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueTypedArray) {
                        throw RuntimeException("getRandomValues requires a TypedArray argument")
                    }
                    
                    val array = v8Values[0] as V8ValueTypedArray
                    val length = array.length
                    
                    if (length > 65536) {
                        throw RuntimeException("TypedArray too large for getRandomValues: $length")
                    }
                    
                    val bytes = ByteArray(length)
                    secureRandom.nextBytes(bytes)
                    array.fromBytes(bytes)
                    
                    array
                }
            ))
            
            // Register with __NATIVE_BRIDGE__
            nativeBridge.set("crypto", cryptoObject)
            
        } finally {
            cryptoObject.close()
        }
    }
}
