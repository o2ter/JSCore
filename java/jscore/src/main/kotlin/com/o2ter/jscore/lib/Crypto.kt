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
import com.caoccao.javet.values.V8Value
import com.o2ter.jscore.PlatformContext
import com.o2ter.jscore.createJSObject
import java.security.SecureRandom
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Digest object for hashing data
 * Matches Swift's JSDigest implementation
 */
private class Digest(
    private val messageDigest: MessageDigest?,
    private val mac: Mac?
) {
    constructor(messageDigest: MessageDigest) : this(messageDigest, null)
    constructor(mac: Mac) : this(null, mac)
    
    fun update(data: ByteArray) {
        messageDigest?.update(data)
        mac?.update(data)
    }
    
    fun digest(): ByteArray {
        return messageDigest?.digest() ?: mac!!.doFinal()
    }
    
    fun clone(): Digest {
        return if (messageDigest != null) {
            Digest(messageDigest.clone() as MessageDigest)
        } else {
            Digest(mac!!.clone() as Mac)
        }
    }
}

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
        platformContext.logger.debug("Crypto", "Setting up Crypto bridge")
        val cryptoObject = v8Runtime.createJSObject(
            methods = mapOf(
                "randomUUID" to IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    platformContext.logger.debug("Crypto", "randomUUID called")
                    try {
                        val uuid = java.util.UUID.randomUUID().toString()
                        platformContext.logger.debug("Crypto", "Generated UUID: $uuid")
                        v8Runtime.createV8ValueString(uuid)
                    } catch (e: Exception) {
                        platformContext.logger.error("Crypto", "Error in randomUUID: ${e.message}")
                        throw e
                    }
                },
                "randomBytes" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    if (args.isEmpty() || args[0] !is V8ValueInteger) {
                        throw RuntimeException("randomBytes requires a length argument")
                    }
                    
                    val length = (args[0] as V8ValueInteger).value
                    
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
                },
                "getRandomValues" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    if (args.isEmpty() || args[0] !is V8ValueTypedArray) {
                        throw RuntimeException("getRandomValues requires a TypedArray argument")
                    }
                    
                    val array = args[0] as V8ValueTypedArray
                    val length = array.length
                    
                    if (length > 65536) {
                        throw RuntimeException("TypedArray too large for getRandomValues: $length")
                    }
                    
                    val bytes = ByteArray(length)
                    secureRandom.nextBytes(bytes)
                    array.fromBytes(bytes)
                    
                    array
                },
                "createHash" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    if (args.isEmpty()) {
                        throw RuntimeException("createHash requires an algorithm argument")
                    }
                    
                    val algorithm = args[0].toString()
                    val javaAlgorithm = when (algorithm.lowercase()) {
                        "md5" -> "MD5"
                        "sha1" -> "SHA-1"
                        "sha256" -> "SHA-256"
                        "sha384" -> "SHA-384"
                        "sha512" -> "SHA-512"
                        else -> throw RuntimeException("Unknown hash algorithm: $algorithm")
                    }
                    
                    val messageDigest = MessageDigest.getInstance(javaAlgorithm)
                    val digest = Digest(messageDigest)
                    
                    // Create digest object with update(), digest(), and clone() methods
                    createDigestObject(digest)
                },
                "createHmac" to IJavetDirectCallable.NoThisAndResult<Exception> { args ->
                    if (args.size < 2) {
                        throw RuntimeException("createHmac requires algorithm and secret arguments")
                    }
                    
                    val algorithm = args[0].toString()
                    val secretArray = args[1] as? V8ValueTypedArray
                        ?: throw RuntimeException("createHmac requires a TypedArray secret")
                    
                    val javaAlgorithm = when (algorithm.lowercase()) {
                        "md5" -> "HmacMD5"
                        "sha1" -> "HmacSHA1"
                        "sha256" -> "HmacSHA256"
                        "sha384" -> "HmacSHA384"
                        "sha512" -> "HmacSHA512"
                        else -> throw RuntimeException("Unknown HMAC algorithm: $algorithm")
                    }
                    
                    val secretBytes = secretArray.toBytes()
                    val secretKey = SecretKeySpec(secretBytes, javaAlgorithm)
                    val mac = Mac.getInstance(javaAlgorithm)
                    mac.init(secretKey)
                    
                    val digest = Digest(mac)
                    
                    // Create digest object with update(), digest(), and clone() methods
                    createDigestObject(digest)
                }
            )
        )
        
        try {
            // Register with __NATIVE_BRIDGE__
            nativeBridge.set("crypto", cryptoObject)
        } finally {
            cryptoObject.close()
        }
    }
    
    /**
     * Create a digest object with update(), digest(), and clone() methods
     * Matches Swift's JSDigest implementation
     */
    private fun createDigestObject(digest: Digest): V8ValueObject {
        val obj = v8Runtime.createV8ValueObject()
        
        // update(data: TypedArray) - update hash with new data
        obj.bindFunction(JavetCallbackContext(
            "update",
            JavetCallbackType.DirectCallNoThisAndNoResult,
            IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                if (v8Values.isNotEmpty() && v8Values[0] is V8ValueTypedArray) {
                    val data = (v8Values[0] as V8ValueTypedArray).toBytes()
                    digest.update(data)
                }
            }
        ))
        
        // digest() - finalize and return hash as Uint8Array
        obj.bindFunction(JavetCallbackContext(
            "digest",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                val hashBytes = digest.digest()
                val array = v8Runtime.createV8ValueTypedArray(
                    com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                    hashBytes.size
                )
                array.fromBytes(hashBytes)
                array
            }
        ))
        
        // clone() - create a copy of the digest object
        obj.bindFunction(JavetCallbackContext(
            "clone",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                createDigestObject(digest.clone())
            }
        ))
        
        return obj
    }
}
