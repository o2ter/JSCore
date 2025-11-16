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
    func createCompressionStream(_ format: String) -> JSValue
    func createDecompressionStream(_ format: String) -> JSValue
}

// JSExport protocol for compression stream
@objc protocol JSCompressionStreamExport: JSExport {
    func transform(_ chunk: JSValue) -> JSValue
    func flush() -> JSValue
}

// Streaming compression state - exposed to JavaScript
@objc final class JSCompressionStream: NSObject, JSCompressionStreamExport {
    private var stream: UnsafeMutablePointer<compression_stream>
    private var format: JSCompression.CompressionFormat
    private var headerWritten = false
    private var crc32: UInt32 = 0xffffffff
    private var adler32s1: UInt32 = 1
    private var adler32s2: UInt32 = 0
    private var uncompressedSize: UInt32 = 0
    private weak var compression: JSCompression?

    fileprivate init(
        stream: UnsafeMutablePointer<compression_stream>, format: JSCompression.CompressionFormat,
        compression: JSCompression
    ) {
        self.stream = stream
        self.format = format
        self.compression = compression
        super.init()
    }

    deinit {
        compression_stream_destroy(stream)
        stream.deallocate()
    }

    func transform(_ chunk: JSValue) -> JSValue {
        guard let compression = compression,
            let chunkData = compression.extractData(from: chunk),
            let context = chunk.context
        else {
            return JSValue(undefinedIn: chunk.context)
        }

        var outputData = Data()

        // Write header on first chunk
        if !headerWritten {
            headerWritten = true
            switch format {
            case .gzip:
                outputData.append(contentsOf: [
                    0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff,
                ])
            case .deflate:
                outputData.append(contentsOf: [0x78, 0x9c])
            case .deflateRaw:
                break
            }
        }

        // Update checksums
        if format == .gzip {
            compression.updateCRC32(&crc32, data: chunkData)
            uncompressedSize = uncompressedSize &+ UInt32(chunkData.count)
        } else if format == .deflate {
            compression.updateAdler32(s1: &adler32s1, s2: &adler32s2, data: chunkData)
        }

        // Compress chunk
        let compressed = chunkData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
            stream.pointee.src_ptr = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            stream.pointee.src_size = chunkData.count

            var result = Data()
            let bufferSize = 65536
            var destBuffer = Data(count: bufferSize)

            repeat {
                let bytesWritten = destBuffer.withUnsafeMutableBytes {
                    (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                    stream.pointee.dst_ptr = destPtr.baseAddress!.assumingMemoryBound(
                        to: UInt8.self)
                    stream.pointee.dst_size = bufferSize
                    compression_stream_process(stream, 0)
                    return bufferSize - stream.pointee.dst_size
                }
                if bytesWritten > 0 {
                    result.append(destBuffer.prefix(bytesWritten))
                }
            } while stream.pointee.src_size > 0

            return result
        }

        outputData.append(compressed)
        return compression.createUint8Array(from: outputData, in: context)
    }

    func flush() -> JSValue {
        guard let compression = compression,
            let context = JSContext.current()
        else {
            return JSValue(undefinedIn: nil)
        }

        var outputData = Data()

        // Flush remaining data
        let bufferSize = 65536
        var destBuffer = Data(count: bufferSize)

        repeat {
            let bytesWritten = destBuffer.withUnsafeMutableBytes {
                (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                stream.pointee.dst_ptr = destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                stream.pointee.dst_size = bufferSize
                compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                return bufferSize - stream.pointee.dst_size
            }
            if bytesWritten > 0 {
                outputData.append(destBuffer.prefix(bytesWritten))
            }
        } while stream.pointee.dst_size == 0

        // Write footer
        switch format {
        case .gzip:
            let finalCRC = crc32 ^ 0xffffffff
            withUnsafeBytes(of: finalCRC.littleEndian) { outputData.append(contentsOf: $0) }
            withUnsafeBytes(of: uncompressedSize.littleEndian) { outputData.append(contentsOf: $0) }
        case .deflate:
            let adler32 = (adler32s2 << 16) | adler32s1
            withUnsafeBytes(of: adler32.bigEndian) { outputData.append(contentsOf: $0) }
        case .deflateRaw:
            break
        }

        return compression.createUint8Array(from: outputData, in: context)
    }
}

// JSExport protocol for decompression stream
@objc protocol JSDecompressionStreamExport: JSExport {
    func transform(_ chunk: JSValue) -> JSValue
    func flush() -> JSValue
}

// Streaming decompression state - exposed to JavaScript
@objc final class JSDecompressionStream: NSObject, JSDecompressionStreamExport {
    private var stream: UnsafeMutablePointer<compression_stream>
    private var format: JSCompression.CompressionFormat
    private var headerSkipped = false
    private var bytesToSkip = 0
    private var footerBytes = Data()
    private weak var compression: JSCompression?

    fileprivate init(
        stream: UnsafeMutablePointer<compression_stream>, format: JSCompression.CompressionFormat,
        compression: JSCompression
    ) {
        self.stream = stream
        self.format = format
        self.compression = compression

        // Determine header size to skip
        switch format {
        case .gzip:
            self.bytesToSkip = 10
        case .deflate:
            self.bytesToSkip = 2
        case .deflateRaw:
            self.bytesToSkip = 0
        }

        super.init()
    }

    deinit {
        compression_stream_destroy(stream)
        stream.deallocate()
    }

    func transform(_ chunk: JSValue) -> JSValue {
        guard let compression = compression,
            var inputData = compression.extractData(from: chunk),
            let context = chunk.context
        else {
            return JSValue(undefinedIn: chunk.context)
        }

        // Skip header on first chunk
        if !headerSkipped && bytesToSkip > 0 {
            headerSkipped = true
            if inputData.count >= bytesToSkip {
                inputData = inputData.dropFirst(bytesToSkip)
            } else {
                bytesToSkip -= inputData.count
                return JSValue(nullIn: context)
            }
        }

        // Buffer footer bytes for gzip/deflate
        let footerSize = format == .gzip ? 8 : (format == .deflate ? 4 : 0)
        if footerSize > 0 {
            footerBytes.append(inputData)
            if footerBytes.count <= footerSize {
                return JSValue(nullIn: context)
            }
            inputData = footerBytes.dropLast(footerSize)
            footerBytes = footerBytes.suffix(footerSize)
        }

        if inputData.isEmpty {
            return JSValue(nullIn: context)
        }

        // Decompress chunk
        let decompressed = inputData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
            stream.pointee.src_ptr = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            stream.pointee.src_size = inputData.count

            var result = Data()
            let bufferSize = 65536
            var destBuffer = Data(count: bufferSize)

            repeat {
                let bytesWritten = destBuffer.withUnsafeMutableBytes {
                    (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                    stream.pointee.dst_ptr = destPtr.baseAddress!.assumingMemoryBound(
                        to: UInt8.self)
                    stream.pointee.dst_size = bufferSize
                    compression_stream_process(stream, 0)
                    return bufferSize - stream.pointee.dst_size
                }
                if bytesWritten > 0 {
                    result.append(destBuffer.prefix(bytesWritten))
                }
            } while stream.pointee.src_size > 0

            return result
        }

        return compression.createUint8Array(from: decompressed, in: context)
    }

    func flush() -> JSValue {
        guard let compression = compression,
            let context = JSContext.current()
        else {
            return JSValue(undefinedIn: nil)
        }

        var outputData = Data()

        // Flush remaining data
        let bufferSize = 65536
        var destBuffer = Data(count: bufferSize)

        repeat {
            let bytesWritten = destBuffer.withUnsafeMutableBytes {
                (destPtr: UnsafeMutableRawBufferPointer) -> Int in
                stream.pointee.dst_ptr = destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                stream.pointee.dst_size = bufferSize
                compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                return bufferSize - stream.pointee.dst_size
            }
            if bytesWritten > 0 {
                outputData.append(destBuffer.prefix(bytesWritten))
            }
        } while stream.pointee.dst_size == 0

        if outputData.isEmpty {
            return JSValue(nullIn: context)
        }

        return compression.createUint8Array(from: outputData, in: context)
    }
}

@objc final class JSCompression: NSObject, JSCompressionExport {

    fileprivate enum CompressionFormat {
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


    
    // MARK: - Helper Methods

    fileprivate func extractData(from value: JSValue) -> Data? {
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

    fileprivate func createUint8Array(from data: Data, in context: JSContext) -> JSValue {
        let uint8ArrayConstructor = context.globalObject.forProperty("Uint8Array")
        let array = uint8ArrayConstructor?.construct(
            withArguments: [data.count])

        // Fill array with data
        data.enumerated().forEach { index, byte in
            array?.setObject(byte, forKeyedSubscript: index as NSNumber)
        }
        
        return array ?? JSValue(undefinedIn: context)
    }
    

    
    fileprivate func updateCRC32(_ crc: inout UInt32, data: Data) {
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
    }

    fileprivate func updateAdler32(s1: inout UInt32, s2: inout UInt32, data: Data) {
        for byte in data {
            s1 = (s1 + UInt32(byte)) % 65521
            s2 = (s2 + s1) % 65521
        }
    }

    // MARK: - Streaming Compression APIs

    func createCompressionStream(_ format: String) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: nil)
        }

        guard let compressionFormat = CompressionFormat(string: format) else {
            return JSValue(
                newErrorFromMessage: "Unsupported compression format: \(format)", in: context)
        }

        // Create compression stream
        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        let dummyDst = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        let dummySrc = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        streamPtr.pointee.dst_ptr = dummyDst
        streamPtr.pointee.dst_size = 0
        streamPtr.pointee.src_ptr = UnsafePointer(dummySrc)
        streamPtr.pointee.src_size = 0
        streamPtr.pointee.state = nil

        let status = compression_stream_init(
            streamPtr, COMPRESSION_STREAM_ENCODE, compressionFormat.algorithm)
        guard status == COMPRESSION_STATUS_OK else {
            streamPtr.deallocate()
            return JSValue(
                newErrorFromMessage: "Failed to initialize compression stream", in: context)
        }

        let streamObj = JSCompressionStream(
            stream: streamPtr, format: compressionFormat, compression: self)
        return JSValue(object: streamObj, in: context)
    }

    func createDecompressionStream(_ format: String) -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(undefinedIn: nil)
        }

        guard let compressionFormat = CompressionFormat(string: format) else {
            return JSValue(
                newErrorFromMessage: "Unsupported compression format: \(format)", in: context)
        }

        // Create decompression stream
        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        let dummyDst = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        let dummySrc = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        streamPtr.pointee.dst_ptr = dummyDst
        streamPtr.pointee.dst_size = 0
        streamPtr.pointee.src_ptr = UnsafePointer(dummySrc)
        streamPtr.pointee.src_size = 0
        streamPtr.pointee.state = nil

        let status = compression_stream_init(
            streamPtr, COMPRESSION_STREAM_DECODE, compressionFormat.algorithm)
        guard status == COMPRESSION_STATUS_OK else {
            streamPtr.deallocate()
            return JSValue(
                newErrorFromMessage: "Failed to initialize decompression stream", in: context)
        }

        let streamObj = JSDecompressionStream(
            stream: streamPtr, format: compressionFormat, compression: self)
        return JSValue(object: streamObj, in: context)
    }
}
