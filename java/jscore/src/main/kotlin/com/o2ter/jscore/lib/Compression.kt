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
import com.caoccao.javet.values.V8Value
import com.caoccao.javet.values.primitive.V8ValueInteger
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
        private var headerWritten = false
        
        private val gzipStream: GZIPOutputStream? = if (format == CompressionFormat.GZIP) {
            GZIPOutputStream(buffer)
        } else null
        
        private val deflater: Deflater? = when (format) {
            CompressionFormat.DEFLATE -> Deflater(Deflater.DEFAULT_COMPRESSION, false)
            CompressionFormat.DEFLATE_RAW -> Deflater(Deflater.DEFAULT_COMPRESSION, true)
            else -> null
        }
        
        private val deflaterStream: DeflaterOutputStream? = deflater?.let {
            DeflaterOutputStream(buffer, it, true)
        }
        
        fun transform(data: V8Value): V8Value {
            val inputBytes = extractBytes(data)
                ?: throw RuntimeException("Invalid input data")
            
            if (inputBytes.isEmpty()) {
                return createUint8Array(ByteArray(0))
            }
            
            // Write header on first chunk
            if (!headerWritten) {
                headerWritten = true
                when (format) {
                    CompressionFormat.GZIP -> {
                        // GZIPOutputStream writes header automatically
                    }
                    CompressionFormat.DEFLATE -> {
                        buffer.write(0x78)  // CMF
                        buffer.write(0x9c)  // FLG
                    }
                    CompressionFormat.DEFLATE_RAW -> {
                        // No header for raw deflate
                    }
                }
            }
            
            val beforeSize = buffer.size()
            
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
            
            // Return compressed chunk
            val allData = buffer.toByteArray()
            val compressed = if (beforeSize < allData.size) {
                allData.sliceArray(beforeSize until allData.size)
            } else {
                ByteArray(0)
            }
            
            return createUint8Array(compressed)
        }
        
        fun flush(): V8Value {
            // Close streams to finalize
            gzipStream?.finish()
            deflaterStream?.finish()
            deflater?.finish()
            
            val result = buffer.toByteArray()
            
            // Clean up
            gzipStream?.close()
            deflaterStream?.close()
            deflater?.end()
            
            return createUint8Array(result)
        }
    }
    
    /**
     * Decompression stream object exposed to JavaScript with transform() and flush() methods
     */
    inner class DecompressionStreamObject(private val format: CompressionFormat) {
        private var inputBuffer = ByteArrayOutputStream()
        private var headerSkipped = false
        private var footerBytes = ByteArrayOutputStream()
        
        private val inflater: Inflater? = when (format) {
            CompressionFormat.DEFLATE -> Inflater(false)
            CompressionFormat.DEFLATE_RAW -> Inflater(true)
            else -> null
        }
        
        fun transform(data: V8Value): V8Value {
            val inputBytes = extractBytes(data)
                ?: throw RuntimeException("Invalid input data")
            
            if (inputBytes.isEmpty()) {
                return createUint8Array(ByteArray(0))
            }
            
            // Accumulate input
            inputBuffer.write(inputBytes)
            
            var inputData = inputBuffer.toByteArray()
            
            // Skip header on first chunk
            if (!headerSkipped) {
                val bytesToSkip = when (format) {
                    CompressionFormat.GZIP -> 10
                    CompressionFormat.DEFLATE -> 2
                    CompressionFormat.DEFLATE_RAW -> 0
                }
                
                if (inputData.size < bytesToSkip) {
                    return v8Runtime.createV8ValueNull()
                }
                
                headerSkipped = true
                if (bytesToSkip > 0) {
                    inputData = inputData.sliceArray(bytesToSkip until inputData.size)
                }
            }
            
            // Buffer footer bytes for gzip/deflate
            val footerSize = when (format) {
                CompressionFormat.GZIP -> 8
                CompressionFormat.DEFLATE -> 4
                CompressionFormat.DEFLATE_RAW -> 0
            }
            
            if (footerSize > 0) {
                footerBytes.write(inputData)
                val allFooterData = footerBytes.toByteArray()
                if (allFooterData.size <= footerSize) {
                    return v8Runtime.createV8ValueNull()
                }
                inputData = allFooterData.sliceArray(0 until allFooterData.size - footerSize)
                footerBytes.reset()
                footerBytes.write(allFooterData.sliceArray(allFooterData.size - footerSize until allFooterData.size))
            }
            
            if (inputData.isEmpty()) {
                return v8Runtime.createV8ValueNull()
            }
            
            // Decompress chunk
            val decompressed = try {
                when (format) {
                    CompressionFormat.GZIP -> {
                        val inputStream = ByteArrayInputStream(inputBuffer.toByteArray())
                        val outputStream = ByteArrayOutputStream()
                        GZIPInputStream(inputStream).use { it.copyTo(outputStream) }
                        
                        // Clear input buffer after successful decompression
                        inputBuffer.reset()
                        outputStream.toByteArray()
                    }
                    CompressionFormat.DEFLATE, CompressionFormat.DEFLATE_RAW -> {
                        inflater!!.setInput(inputData)
                        val outputStream = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        
                        while (!inflater.needsInput() && !inflater.finished()) {
                            val count = inflater.inflate(buffer)
                            if (count > 0) {
                                outputStream.write(buffer, 0, count)
                            }
                        }
                        
                        outputStream.toByteArray()
                    }
                }
            } catch (e: Exception) {
                // Not enough data yet, return null
                return v8Runtime.createV8ValueNull()
            }
            
            return createUint8Array(decompressed)
        }
        
        fun flush(): V8Value {
            // Try to decompress any remaining data
            val inputData = inputBuffer.toByteArray()
            if (inputData.isEmpty()) {
                cleanup()
                return v8Runtime.createV8ValueNull()
            }
            
            val decompressed = try {
                when (format) {
                    CompressionFormat.GZIP -> {
                        val inputStream = ByteArrayInputStream(inputData)
                        val outputStream = ByteArrayOutputStream()
                        GZIPInputStream(inputStream).use { it.copyTo(outputStream) }
                        outputStream.toByteArray()
                    }
                    CompressionFormat.DEFLATE, CompressionFormat.DEFLATE_RAW -> {
                        val outputStream = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        
                        while (!inflater!!.finished()) {
                            val count = inflater.inflate(buffer)
                            if (count > 0) {
                                outputStream.write(buffer, 0, count)
                            } else {
                                break
                            }
                        }
                        
                        outputStream.toByteArray()
                    }
                }
            } catch (e: Exception) {
                ByteArray(0)
            } finally {
                cleanup()
            }
            
            if (decompressed.isEmpty()) {
                return v8Runtime.createV8ValueNull()
            }
            
            return createUint8Array(decompressed)
        }
        
        private fun cleanup() {
            inflater?.end()
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
        return v8Runtime.createV8ValueObject().apply {
            bind("transform", true, streamObj::transform)
            bind("flush", true, streamObj::flush)
        }
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
        return v8Runtime.createV8ValueObject().apply {
            bind("transform", true, streamObj::transform)
            bind("flush", true, streamObj::flush)
        }
    }
}
