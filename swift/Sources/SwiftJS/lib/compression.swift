//
//  compression.swift
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

import Foundation
import JavaScriptCore
import Compression

@objc protocol JSCompressionExport: JSExport {
    func compress(_ data: JSValue, _ format: String) -> JSValue
    func decompress(_ data: JSValue, _ format: String) -> JSValue
}

@objc final class JSCompression: NSObject, JSCompressionExport {
    
    private enum CompressionFormat {
        case gzip
        case deflate
        case deflateRaw
        
        var algorithm: compression_algorithm {
            switch self {
            case .gzip, .deflate, .deflateRaw:
                return COMPRESSION_ZLIB
            }
        }
        
        init?(string: String) {
            switch string.lowercased() {
            case "gzip":
                self = .gzip
            case "deflate":
                self = .deflate
            case "deflate-raw":
                self = .deflateRaw
            default:
                return nil
            }
        }
    }
    
    func compress(_ data: JSValue, _ format: String) -> JSValue {
        guard let compressionFormat = CompressionFormat(string: format) else {
            return JSValue(
                newErrorFromMessage: "Unsupported compression format: \(format)",
                in: data.context)
        }
        
        // Extract data from JSValue
        guard let inputData = extractData(from: data) else {
            return JSValue(newErrorFromMessage: "Invalid input data", in: data.context)
        }
        
        // Perform compression
        guard let compressed = performCompression(inputData, format: compressionFormat) else {
            return JSValue(
                newErrorFromMessage: "Compression failed", in: data.context)
        }
        
        // Return as Uint8Array
        return createUint8Array(from: compressed, in: data.context)
    }
    
    func decompress(_ data: JSValue, _ format: String) -> JSValue {
        guard let compressionFormat = CompressionFormat(string: format) else {
            return JSValue(
                newErrorFromMessage: "Unsupported compression format: \(format)",
                in: data.context)
        }
        
        // Extract data from JSValue
        guard let inputData = extractData(from: data) else {
            return JSValue(newErrorFromMessage: "Invalid input data", in: data.context)
        }
        
        // Perform decompression
        guard let decompressed = performDecompression(inputData, format: compressionFormat) else {
            return JSValue(
                newErrorFromMessage: "Decompression failed", in: data.context)
        }
        
        // Return as Uint8Array
        return createUint8Array(from: decompressed, in: data.context)
    }
    
    // MARK: - Helper Methods
    
    private func extractData(from value: JSValue) -> Data? {
        // Handle Uint8Array or ArrayBuffer
        let bufferProperty = value.forProperty("buffer")
        if value.isArray || (bufferProperty?.isObject ?? false) {
            // Try to get ArrayBuffer
            let buffer = (bufferProperty?.isObject ?? false) ? bufferProperty : value
            
            // Get byte length
            guard let byteLength = buffer?.forProperty("byteLength")?.toNumber() as? Int else {
                return nil
            }
            
            // Extract bytes
            var bytes = [UInt8](repeating: 0, count: byteLength)
            for i in 0..<byteLength {
                if let byte = value.atIndex(i).toNumber() as? UInt8 {
                    bytes[i] = byte
                }
            }
            
            return Data(bytes)
        }
        
        return nil
    }
    
    private func createUint8Array(from data: Data, in context: JSContext) -> JSValue {
        let uint8ArrayConstructor = context.globalObject.forProperty("Uint8Array")
        let array = uint8ArrayConstructor?.construct(
            withArguments: [data.count])
        
        // Fill array with data
        data.enumerated().forEach { index, byte in
            array?.setObject(byte, forKeyedSubscript: index as NSNumber)
        }
        
        return array ?? JSValue(undefinedIn: context)
    }
    
    private func performCompression(_ data: Data, format: CompressionFormat) -> Data? {
        switch format {
        case .gzip:
            return compressGzip(data)
        case .deflate:
            return compressDeflate(data)
        case .deflateRaw:
            return compressDeflateRaw(data)
        }
    }
    
    private func performDecompression(_ data: Data, format: CompressionFormat) -> Data? {
        switch format {
        case .gzip:
            return decompressGzip(data)
        case .deflate:
            return decompressDeflate(data)
        case .deflateRaw:
            return decompressDeflateRaw(data)
        }
    }
    
    // MARK: - Gzip (RFC 1952)
    
    private func compressGzip(_ data: Data) -> Data? {
        var outputData = Data()
        
        // Gzip header (RFC 1952)
        outputData.append(contentsOf: [
            0x1f, 0x8b,  // Magic number
            0x08,        // Compression method (deflate)
            0x00,        // Flags
            0x00, 0x00, 0x00, 0x00,  // Timestamp
            0x00,        // Extra flags
            0xff         // OS (unknown)
        ])
        
        // Compress data using deflate
        guard let compressed = data.withUnsafeBytes({ (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = data.count
            let destSize = sourceSize + 1024 // Add buffer for compression overhead
            var destBuffer = Data(count: destSize)
            
            let compressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_encode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if compressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(compressedSize)
        }) else {
            return nil
        }
        
        outputData.append(compressed)
        
        // CRC32 and uncompressed size
        let crc32 = calculateCRC32(data)
        let size = UInt32(data.count)
        
        withUnsafeBytes(of: crc32.littleEndian) { outputData.append(contentsOf: $0) }
        withUnsafeBytes(of: size.littleEndian) { outputData.append(contentsOf: $0) }
        
        return outputData
    }
    
    private func decompressGzip(_ data: Data) -> Data? {
        // Verify gzip header
        guard data.count >= 18,  // Minimum gzip size (header + footer)
              data[0] == 0x1f,
              data[1] == 0x8b,
              data[2] == 0x08  // Deflate compression
        else {
            return nil
        }
        
        // Extract compressed data (skip 10-byte header, leave 8-byte footer)
        let compressedData = data.dropFirst(10).dropLast(8)
        
        // Decompress
        return compressedData.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = compressedData.count
            let destSize = sourceSize * 10 // Estimate decompressed size
            var destBuffer = Data(count: destSize)
            
            let decompressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_decode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if decompressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(decompressedSize)
        }
    }
    
    // MARK: - Deflate with zlib wrapper (RFC 1950)
    
    private func compressDeflate(_ data: Data) -> Data? {
        var outputData = Data()
        
        // Zlib header (RFC 1950)
        let cmf: UInt8 = 0x78  // CM=8 (deflate), CINFO=7 (32K window)
        let flg: UInt8 = 0x9c  // FLEVEL=2 (default), FCHECK calculated for checksum
        outputData.append(contentsOf: [cmf, flg])
        
        // Compress data using deflate
        guard let compressed = data.withUnsafeBytes({ (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = data.count
            let destSize = sourceSize + 1024
            var destBuffer = Data(count: destSize)
            
            let compressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_encode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if compressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(compressedSize)
        }) else {
            return nil
        }
        
        outputData.append(compressed)
        
        // Adler-32 checksum
        let adler32 = calculateAdler32(data)
        withUnsafeBytes(of: adler32.bigEndian) { outputData.append(contentsOf: $0) }
        
        return outputData
    }
    
    private func decompressDeflate(_ data: Data) -> Data? {
        // Verify zlib header
        guard data.count >= 6,  // Minimum zlib size
              data[0] == 0x78  // CM=8 (deflate)
        else {
            return nil
        }
        
        // Extract compressed data (skip 2-byte header, leave 4-byte checksum)
        let compressedData = data.dropFirst(2).dropLast(4)
        
        // Decompress
        return compressedData.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = compressedData.count
            let destSize = sourceSize * 10
            var destBuffer = Data(count: destSize)
            
            let decompressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_decode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if decompressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(decompressedSize)
        }
    }
    
    // MARK: - Deflate raw (RFC 1951 - no wrapper)
    
    private func compressDeflateRaw(_ data: Data) -> Data? {
        return data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = data.count
            let destSize = sourceSize + 1024
            var destBuffer = Data(count: destSize)
            
            let compressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_encode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if compressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(compressedSize)
        }
    }
    
    private func decompressDeflateRaw(_ data: Data) -> Data? {
        return data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data? in
            let sourceSize = data.count
            let destSize = sourceSize * 10
            var destBuffer = Data(count: destSize)
            
            let decompressedSize = destBuffer.withUnsafeMutableBytes { (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                compression_decode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    sourcePtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            
            if decompressedSize == 0 {
                return nil
            }
            
            return destBuffer.prefix(decompressedSize)
        }
    }
    
    // MARK: - Checksum Calculations
    
    private func calculateCRC32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        
        for byte in data {
            crc = crc ^ UInt32(byte)
            for _ in 0..<8 {
                if (crc & 1) != 0 {
                    crc = (crc >> 1) ^ 0xedb88320
                } else {
                    crc = crc >> 1
                }
            }
        }
        
        return crc ^ 0xffffffff
    }
    
    private func calculateAdler32(_ data: Data) -> UInt32 {
        var s1: UInt32 = 1
        var s2: UInt32 = 0
        
        for byte in data {
            s1 = (s1 + UInt32(byte)) % 65521
            s2 = (s2 + s1) % 65521
        }
        
        return (s2 << 16) | s1
    }
}
