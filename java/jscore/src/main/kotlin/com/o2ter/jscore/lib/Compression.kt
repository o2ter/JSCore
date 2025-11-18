//
//  Compression.kt
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
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.primitive.V8ValueInteger
import com.caoccao.javet.values.reference.V8ValueObject
import com.caoccao.javet.values.reference.V8ValueTypedArray
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream
import java.util.zip.Deflater
import java.util.zip.DeflaterOutputStream
import java.util.zip.Inflater

/**
 * Compression bridge for JavaScript Compression Streams API
 * Provides gzip, deflate, and deflate-raw compression/decompression
 */
class Compression(private val v8Runtime: V8Runtime) {
    
    enum class CompressionFormat {
        GZIP,
        DEFLATE,
        DEFLATE_RAW;
        
        companion object {
            fun fromString(format: String): CompressionFormat? {
                return when (format.lowercase()) {
                    "gzip" -> GZIP
                    "deflate" -> DEFLATE
                    "deflate-raw" -> DEFLATE_RAW
                    else -> null
                }
            }
        }
    }
    
    /**
     * Compression stream object exposed to JavaScript with transform() and flush() methods
     */
    inner class CompressionStreamObject(private val format: CompressionFormat) {
        private val buffer = ByteArrayOutputStream()
        private var lastReturnedSize = 0
        
        private val gzipStream: GZIPOutputStream? = if (format == CompressionFormat.GZIP) {
            GZIPOutputStream(buffer)
        } else null
        
        private val deflater: Deflater? = when (format) {
            CompressionFormat.DEFLATE -> Deflater(Deflater.DEFAULT_COMPRESSION, false)
            CompressionFormat.DEFLATE_RAW -> Deflater(Deflater.DEFAULT_COMPRESSION, true)
            else -> null
        }
        
        private val deflaterStream: DeflaterOutputStream? = deflater?.let { 
            // Write DEFLATE header before creating the stream
            if (format == CompressionFormat.DEFLATE) {
                buffer.write(0x78)  // CMF
                buffer.write(0x9c)  // FLG
                lastReturnedSize = 2  // Track that we've written the header
            }
            DeflaterOutputStream(buffer, it, true)
        }
        
        fun transform(data: V8Value): V8Value {
            val inputBytes = extractBytes(data)
                ?: throw RuntimeException("Invalid input data")
            
            if (inputBytes.isEmpty()) {
                return createUint8Array(ByteArray(0))
            }
            
            // Write to appropriate stream
            when (format) {
                CompressionFormat.GZIP -> {
                    gzipStream!!.write(inputBytes)
                    gzipStream.flush()
                }
                CompressionFormat.DEFLATE, CompressionFormat.DEFLATE_RAW -> {
                    deflaterStream!!.write(inputBytes)
                    deflaterStream.flush()
                }
            }
            
            // Return compressed chunk (all new data since last call)
            val allData = buffer.toByteArray()
            val compressed = if (lastReturnedSize < allData.size) {
                allData.sliceArray(lastReturnedSize until allData.size)
            } else {
                ByteArray(0)
            }
            
            lastReturnedSize = allData.size
            
            return createUint8Array(compressed)
        }
        
        fun flush(): V8Value {
            // Finalize compression
            gzipStream?.finish()
            deflaterStream?.finish()
            deflater?.finish()
            
            val allData = buffer.toByteArray()
            
            // Return only the final chunk that hasn't been returned yet
            val finalChunk = if (lastReturnedSize < allData.size) {
                allData.sliceArray(lastReturnedSize until allData.size)
            } else {
                ByteArray(0)
            }
            
            // Clean up
            gzipStream?.close()
            deflaterStream?.close()
            deflater?.end()
            
            return createUint8Array(finalChunk)
        }
    }
    
    /**
     * Decompression stream object exposed to JavaScript with transform() and flush() methods
     */
    inner class DecompressionStreamObject(private val format: CompressionFormat) {
        private val inputBuffer = ByteArrayOutputStream()
        
        private val inflater: Inflater = when (format) {
            CompressionFormat.GZIP -> Inflater(true)  // true for GZIP (nowrap mode)
            CompressionFormat.DEFLATE -> Inflater(false)  // false for zlib wrapper
            CompressionFormat.DEFLATE_RAW -> Inflater(true)  // true for raw deflate (no wrapper)
        }
        
        fun transform(data: V8Value): V8Value {
            val inputBytes = extractBytes(data)
                ?: throw RuntimeException("Invalid input data")
            
            if (inputBytes.isEmpty()) {
                return v8Runtime.createV8ValueNull()
            }
            
            // For GZIP format, accumulate data and try to decompress
            if (format == CompressionFormat.GZIP) {
                inputBuffer.write(inputBytes)
                
                // Try to decompress accumulated data
                try {
                    val decompressed = ByteArrayOutputStream()
                    val gzipInput = GZIPInputStream(ByteArrayInputStream(inputBuffer.toByteArray()))
                    val buffer = ByteArray(8192)
                    var count: Int
                    while (gzipInput.read(buffer).also { count = it } != -1) {
                        decompressed.write(buffer, 0, count)
                    }
                    
                    // Successfully decompressed - clear input buffer
                    inputBuffer.reset()
                    
                    val result = decompressed.toByteArray()
                    return if (result.isNotEmpty()) {
                        createUint8Array(result)
                    } else {
                        v8Runtime.createV8ValueNull()
                    }
                } catch (e: Exception) {
                    // Not enough data yet or incomplete stream - keep accumulating
                    return v8Runtime.createV8ValueNull()
                }
            }
            
            // For DEFLATE and DEFLATE_RAW, use Inflater for streaming decompression
            inflater.setInput(inputBytes)
            
            val decompressed = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            
            try {
                while (!inflater.needsInput() && !inflater.finished()) {
                    val count = inflater.inflate(buffer)
                    if (count > 0) {
                        decompressed.write(buffer, 0, count)
                    } else if (inflater.needsDictionary()) {
                        throw RuntimeException("Decompression requires a preset dictionary")
                    }
                }
            } catch (e: Exception) {
                // Incomplete data, will continue on next chunk
            }
            
            val result = decompressed.toByteArray()
            return if (result.isNotEmpty()) {
                createUint8Array(result)
            } else {
                v8Runtime.createV8ValueNull()
            }
        }
        
        fun flush(): V8Value {
            val decompressed = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            
            // Process any remaining buffered GZIP data
            if (format == CompressionFormat.GZIP && inputBuffer.size() > 0) {
                try {
                    val gzipInput = GZIPInputStream(ByteArrayInputStream(inputBuffer.toByteArray()))
                    var count: Int
                    while (gzipInput.read(buffer).also { count = it } != -1) {
                        decompressed.write(buffer, 0, count)
                    }
                } catch (e: Exception) {
                    // Ignore incomplete data
                }
            }
            
            // Process any remaining data in the inflater for DEFLATE/DEFLATE_RAW
            if (format != CompressionFormat.GZIP) {
                try {
                    while (!inflater.finished()) {
                        val count = inflater.inflate(buffer)
                        if (count > 0) {
                            decompressed.write(buffer, 0, count)
                        } else {
                            break
                        }
                    }
                } catch (e: Exception) {
                    // Ignore incomplete data
                }
            }
            
            cleanup()
            
            val result = decompressed.toByteArray()
            return if (result.isNotEmpty()) {
                createUint8Array(result)
            } else {
                v8Runtime.createV8ValueNull()
            }
        }
        
        private fun cleanup() {
            inflater.end()
        }
    }
    
    // MARK: - Helper Methods
    
    private fun extractBytes(data: V8Value): ByteArray? {
        return when (data) {
            is V8ValueTypedArray -> {
                val byteArray = ByteArray(data.length)
                for (i in 0 until data.length) {
                    (data.get(i) as? V8ValueInteger)?.use { element ->
                        byteArray[i] = element.value.toByte()
                    } ?: run {
                        byteArray[i] = 0
                    }
                }
                byteArray
            }
            else -> null
        }
    }
    
    private fun createUint8Array(bytes: ByteArray): V8ValueTypedArray {
        return v8Runtime.createV8ValueTypedArray(
            com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
            bytes.size
        ).also { array ->
            bytes.forEachIndexed { index, byte ->
                array.set(index, byte.toInt() and 0xFF)
            }
        }
    }
    
    // MARK: - Streaming Compression APIs
    
    /**
     * Create a streaming compression context object with transform() and flush() methods
     * @param format Compression format ("gzip", "deflate", or "deflate-raw")
     * @return Stream object for JavaScript
     */
    fun createCompressionStream(format: String): V8Value {
        val compressionFormat = CompressionFormat.fromString(format)
            ?: throw RuntimeException("Unsupported compression format: $format")
        
        val streamObj = CompressionStreamObject(compressionFormat)
        
        // Create V8 object with transform and flush methods
        val obj = v8Runtime.createV8ValueObject()
        obj.bindFunction(JavetCallbackContext(
            "transform",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { args -> 
                if (args.isEmpty()) throw RuntimeException("transform() requires 1 argument")
                return@NoThisAndResult streamObj.transform(args[0])
            }
        ))
        obj.bindFunction(JavetCallbackContext(
            "flush",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { _ -> return@NoThisAndResult streamObj.flush() }
        ))
        return obj
    }
    
    /**
     * Create a streaming decompression context object with transform() and flush() methods
     * @param format Compression format ("gzip", "deflate", or "deflate-raw")
     * @return Stream object for JavaScript
     */
    fun createDecompressionStream(format: String): V8Value {
        val compressionFormat = CompressionFormat.fromString(format)
            ?: throw RuntimeException("Unsupported compression format: $format")
        
        val streamObj = DecompressionStreamObject(compressionFormat)
        
        // Create V8 object with transform and flush methods
        val obj = v8Runtime.createV8ValueObject()
        obj.bindFunction(JavetCallbackContext(
            "transform",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { args -> 
                if (args.isEmpty()) throw RuntimeException("transform() requires 1 argument")
                return@NoThisAndResult streamObj.transform(args[0])
            }
        ))
        obj.bindFunction(JavetCallbackContext(
            "flush",
            JavetCallbackType.DirectCallNoThisAndResult,
            IJavetDirectCallable.NoThisAndResult<Exception> { _ -> return@NoThisAndResult streamObj.flush() }
        ))
        return obj
    }
    
    /**
     * Setup compression bridge in the native bridge object
     * @param nativeBridge The native bridge object to register compression APIs
     */
    fun setupBridge(nativeBridge: V8ValueObject) {
        val compressionBridge = v8Runtime.createV8ValueObject()
        try {
            compressionBridge.bindFunction(JavetCallbackContext("createCompressionStream",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("createCompressionStream() requires 1 argument")
                    }
                    return@NoThisAndResult createCompressionStream(v8Values[0].toString())
                }))
            
            compressionBridge.bindFunction(JavetCallbackContext("createDecompressionStream",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty()) {
                        throw RuntimeException("createDecompressionStream() requires 1 argument")
                    }
                    return@NoThisAndResult createDecompressionStream(v8Values[0].toString())
                }))
            
            nativeBridge.set("compression", compressionBridge)
        } finally {
            compressionBridge.close()
        }
    }
}
