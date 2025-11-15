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
import java.util.zip.InflaterInputStream
import java.util.zip.CRC32
import java.util.zip.Adler32

/**
 * Compression bridge for JavaScript Compression Streams API
 * Provides gzip, deflate, and deflate-raw compression/decompression
 */
class Compression(private val v8Runtime: V8Runtime) {
    
    private enum class CompressionFormat {
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
     * Compress data using the specified format
     * @param data Input data as Uint8Array or TypedArray
     * @param format Compression format ("gzip", "deflate", or "deflate-raw")
     * @return Compressed data as Uint8Array
     */
    fun compress(data: V8Value, format: String): V8Value {
        val compressionFormat = CompressionFormat.fromString(format)
            ?: throw RuntimeException("Unsupported compression format: $format")
        
        val inputBytes = extractBytes(data)
            ?: throw RuntimeException("Invalid input data")
        
        val compressed = try {
            when (compressionFormat) {
                CompressionFormat.GZIP -> compressGzip(inputBytes)
                CompressionFormat.DEFLATE -> compressDeflate(inputBytes)
                CompressionFormat.DEFLATE_RAW -> compressDeflateRaw(inputBytes)
            }
        } catch (e: Exception) {
            throw RuntimeException("Compression failed: ${e.message}", e)
        }
        
        return createUint8Array(compressed)
    }
    
    /**
     * Decompress data using the specified format
     * @param data Input data as Uint8Array or TypedArray
     * @param format Compression format ("gzip", "deflate", or "deflate-raw")
     * @return Decompressed data as Uint8Array
     */
    fun decompress(data: V8Value, format: String): V8Value {
        val compressionFormat = CompressionFormat.fromString(format)
            ?: throw RuntimeException("Unsupported compression format: $format")
        
        val inputBytes = extractBytes(data)
            ?: throw RuntimeException("Invalid input data")
        
        val decompressed = try {
            when (compressionFormat) {
                CompressionFormat.GZIP -> decompressGzip(inputBytes)
                CompressionFormat.DEFLATE -> decompressDeflate(inputBytes)
                CompressionFormat.DEFLATE_RAW -> decompressDeflateRaw(inputBytes)
            }
        } catch (e: Exception) {
            throw RuntimeException("Decompression failed: ${e.message}", e)
        }
        
        return createUint8Array(decompressed)
    }
    
    // MARK: - Helper Methods
    
    private fun extractBytes(data: V8Value): ByteArray? {
        return when (data) {
            is V8ValueTypedArray -> {
                val byteArray = ByteArray(data.length)
                for (i in 0 until data.length) {
                    byteArray[i] = (data.get(i) as? V8ValueInteger)?.value?.toByte() ?: 0
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
    
    // MARK: - Gzip Compression (RFC 1952)
    
    private fun compressGzip(data: ByteArray): ByteArray {
        val outputStream = ByteArrayOutputStream()
        GZIPOutputStream(outputStream).use { gzipStream ->
            gzipStream.write(data)
        }
        return outputStream.toByteArray()
    }
    
    private fun decompressGzip(data: ByteArray): ByteArray {
        val inputStream = ByteArrayInputStream(data)
        val outputStream = ByteArrayOutputStream()
        
        GZIPInputStream(inputStream).use { gzipStream ->
            gzipStream.copyTo(outputStream)
        }
        
        return outputStream.toByteArray()
    }
    
    // MARK: - Deflate with zlib wrapper (RFC 1950)
    
    private fun compressDeflate(data: ByteArray): ByteArray {
        val outputStream = ByteArrayOutputStream()
        
        // Zlib header (RFC 1950)
        outputStream.write(0x78)  // CMF: CM=8 (deflate), CINFO=7 (32K window)
        outputStream.write(0x9c)  // FLG: FLEVEL=2 (default compression)
        
        // Compress data
        val deflater = Deflater(Deflater.DEFAULT_COMPRESSION, false)
        try {
            DeflaterOutputStream(outputStream, deflater, true).use { deflaterStream ->
                deflaterStream.write(data)
            }
        } finally {
            deflater.end()
        }
        
        // Add Adler-32 checksum
        val adler32 = Adler32()
        adler32.update(data)
        val checksum = adler32.value.toInt()
        
        outputStream.write((checksum shr 24) and 0xFF)
        outputStream.write((checksum shr 16) and 0xFF)
        outputStream.write((checksum shr 8) and 0xFF)
        outputStream.write(checksum and 0xFF)
        
        return outputStream.toByteArray()
    }
    
    private fun decompressDeflate(data: ByteArray): ByteArray {
        // Verify zlib header
        if (data.size < 6 || data[0] != 0x78.toByte()) {
            throw IllegalArgumentException("Invalid deflate header")
        }
        
        // Extract compressed data (skip 2-byte header, leave 4-byte checksum)
        val compressedData = data.sliceArray(2 until data.size - 4)
        
        val inputStream = ByteArrayInputStream(compressedData)
        val outputStream = ByteArrayOutputStream()
        
        val inflater = Inflater(false)
        try {
            InflaterInputStream(inputStream, inflater).use { inflaterStream ->
                inflaterStream.copyTo(outputStream)
            }
        } finally {
            inflater.end()
        }
        
        return outputStream.toByteArray()
    }
    
    // MARK: - Deflate raw (RFC 1951 - no wrapper)
    
    private fun compressDeflateRaw(data: ByteArray): ByteArray {
        val outputStream = ByteArrayOutputStream()
        
        // Use nowrap=true for raw deflate (no zlib wrapper)
        val deflater = Deflater(Deflater.DEFAULT_COMPRESSION, true)
        try {
            DeflaterOutputStream(outputStream, deflater, true).use { deflaterStream ->
                deflaterStream.write(data)
            }
        } finally {
            deflater.end()
        }
        
        return outputStream.toByteArray()
    }
    
    private fun decompressDeflateRaw(data: ByteArray): ByteArray {
        val inputStream = ByteArrayInputStream(data)
        val outputStream = ByteArrayOutputStream()
        
        // Use nowrap=true for raw deflate (no zlib wrapper)
        val inflater = Inflater(true)
        try {
            InflaterInputStream(inputStream, inflater).use { inflaterStream ->
                inflaterStream.copyTo(outputStream)
            }
        } finally {
            inflater.end()
        }
        
        return outputStream.toByteArray()
    }
}
