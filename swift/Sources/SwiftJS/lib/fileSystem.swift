//
//  fileSystem.swift
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
import UniformTypeIdentifiers

@objc protocol JSFileSystemExport: JSExport {
    func homeDirectory() -> String
    func temporaryDirectory() -> String
    func currentDirectoryPath() -> String
    func changeCurrentDirectoryPath(_ path: String) -> Bool
    func removeItem(_ path: String) -> Bool
    func readFile(_ path: String, _ options: JSValue) -> JSValue?
    func writeFile(_ path: String, _ data: JSValue, _ flags: Int) -> Bool
    func readDirectory(_ path: String) -> [String]?
    func createDirectory(_ path: String) -> Bool
    func exists(_ path: String) -> Bool
    func isDirectory(_ path: String) -> Bool
    func isFile(_ path: String) -> Bool
    func stat(_ path: String) -> JSValue?
    func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool
    func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool
    
    // Link operations
    func createSymbolicLink(_ targetPath: String, _ linkPath: String) -> Bool
    func createHardLink(_ sourcePath: String, _ linkPath: String) -> Bool
    func readSymbolicLink(_ path: String) -> String?
    func lstat(_ path: String) -> JSValue?

    // MIME type detection
    func getMimeType(_ fileExtension: String) -> String

    // Streaming methods for efficient file reading
    func getFileSize(_ path: String) -> Int

    // Promise-based streaming API (non-blocking)

    /// - createReadFileHandle returns a Promise<number> resolving to handle id or -1 on failure
    func createReadFileHandle(_ path: String) -> JSValue
    /// - readFileHandleChunk returns a Promise<Uint8Array|null> resolving with chunk or null at EOF
    func readFileHandleChunk(_ handle: Int, _ length: Int) -> JSValue
    /// - closeFileHandle returns a Promise<void>
    func closeFileHandle(_ handle: Int) -> JSValue

    // Write streaming methods for memory-efficient file writing
    /// - createWriteFileHandle returns a Promise<number> resolving to handle id or -1 on failure
    /// - Parameters:
    ///   - path: File path
    ///   - flags: File open flags (bit flags: 1=append, 2=exclusive)
    func createWriteFileHandle(_ path: String, _ flags: Int) -> JSValue
    /// - writeFileHandleChunk returns a Promise<boolean> resolving with success status
    func writeFileHandleChunk(_ handle: Int, _ data: JSValue) -> JSValue
    
    // Directory streaming methods for memory-efficient directory iteration
    /// - openDirectoryStream returns a number (handle id) or -1 on failure
    func openDirectoryStream(_ path: String) -> Int
    /// - readNextDirectoryEntry returns an object with entry metadata or null when done
    func readNextDirectoryEntry(_ handle: Int) -> JSValue?
    /// - closeDirectoryStream closes the directory handle
    func closeDirectoryStream(_ handle: Int) -> Bool
}

@objc final class JSFileSystem: NSObject, JSFileSystemExport, @unchecked Sendable {

    // File operation flags (bit flags)
    // Bit 0 (value 1): Append mode
    // Bit 1 (value 2): Exclusive mode (O_EXCL - atomic create, fail if exists)
    // Examples: 0 = truncate, 1 = append, 2 = exclusive, 3 = append+exclusive

    private let context: SwiftJS.Context
    private let runloop: RunLoop

    init(context: SwiftJS.Context, runloop: RunLoop) {
        self.context = context
        self.runloop = runloop
        super.init()
    }

    func homeDirectory() -> String {
        return NSHomeDirectory()
    }

    func temporaryDirectory() -> String {
        let tempDir = NSTemporaryDirectory()
        // Remove trailing slash if present
        return tempDir.hasSuffix("/") ? String(tempDir.dropLast()) : tempDir
    }

    func currentDirectoryPath() -> String {
        return FileManager.default.currentDirectoryPath
    }

    func changeCurrentDirectoryPath(_ path: String) -> Bool {
        return FileManager.default.changeCurrentDirectoryPath(path)
    }

    func removeItem(_ path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            let context = JSContext.current()!
            if let error = error as? JSValue {
                context.exception = error
            } else {
                context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            }
            return false
        }
    }

    func readFile(_ path: String, _ options: JSValue) -> JSValue? {
        let context = JSContext.current()!
        let encoding =
            options.forProperty("encoding").isString
            ? options.forProperty("encoding").toString()
            : "utf-8"

        // Check for byte-range reading options (for File.slice() support)
        let hasStart = options.forProperty("start").isNumber
        let hasEnd = options.forProperty("end").isNumber
        
        do {
            if encoding == "binary" {
                // Handle byte-range reading for efficient file slicing
                if hasStart || hasEnd {
                    guard let fileHandle = FileHandle(forReadingAtPath: path) else {
                        context.exception = JSValue(
                            newErrorFromMessage: "Failed to open file: \(path)", in: context)
                        return nil
                    }
                    defer { fileHandle.closeFile() }

                    // Get file size
                    let fileSize = try fileHandle.seekToEnd()

                    // Calculate byte range
                    let start = hasStart ? Int(options.forProperty("start").toInt32()) : 0
                    let end = hasEnd ? Int(options.forProperty("end").toInt32()) : Int(fileSize)

                    // Validate range
                    let clampedStart = max(0, min(start, Int(fileSize)))
                    let clampedEnd = max(clampedStart, min(end, Int(fileSize)))
                    let length = clampedEnd - clampedStart

                    if length <= 0 {
                        // Return empty Uint8Array for empty range
                        return JSValue.uint8Array(count: 0, in: context) { _ in }
                    }

                    // Seek to start position and read the byte range
                    try fileHandle.seek(toOffset: UInt64(clampedStart))
                    let data = try fileHandle.read(upToCount: length) ?? Data()

                    let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                        data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
                    }
                    return uint8Array
                } else {
                    // Return Uint8Array for binary data (full file read)
                    let data = try Data(
                        contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                    let uint8Array = JSValue.uint8Array(count: data.count, in: context) { buffer in
                        data.copyBytes(to: buffer.bindMemory(to: UInt8.self), count: data.count)
                    }
                    return uint8Array
                }
            } else {
                // Return string for text data
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return JSValue(object: content, in: context)
            }
        } catch {
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func writeFile(_ path: String, _ data: JSValue, _ flags: Int) -> Bool {
        let context = JSContext.current()!

        // Decode flags: bit 0 = append, bit 1 = exclusive
        let append = (flags & 1) != 0
        let exclusive = (flags & 2) != 0

        // Convert JS data to Swift Data
        let swiftData: Data

        if data.isTypedArray {
            let bytes = data.typedArrayBytes
            swiftData = Data(bytes.bindMemory(to: UInt8.self))
        } else if data.isString {
            swiftData = data.toString().data(using: .utf8) ?? Data()
        } else {
            context.exception = JSValue(
                newErrorFromMessage: "Unsupported data type for writeFile", in: context)
            return false
        }

        // Build POSIX open flags (same pattern as createWriteFileHandle)
        var openFlags = O_WRONLY | O_CREAT
        if exclusive {
            openFlags |= O_EXCL
        }
        if append {
            openFlags |= O_APPEND  // Use O_APPEND for atomic append operations
        } else {
            openFlags |= O_TRUNC
        }

        // Open file using POSIX (atomic for exclusive mode)
        let fd = open(path, openFlags, 0o644)

        if fd == -1 {
            let errorNum = errno
            let error = String(cString: strerror(errorNum))
            let message =
                errorNum == EEXIST
                ? "File already exists: \(path)"
                : "Failed to open file: \(error)"
            context.exception = JSValue(newErrorFromMessage: message, in: context)
            return false
        }

        defer { close(fd) }

        // Write data (O_APPEND flag ensures atomic append to end of file)
        let written = swiftData.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }

        if written != swiftData.count {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to write all data to file", in: context)
            return false
        }

        return true
    }

    func readDirectory(_ path: String) -> [String]? {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func createDirectory(_ path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func exists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func isFile(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }

    func stat(_ path: String) -> JSValue? {
        do {
            // stat() should follow symbolic links to get information about the target
            // First resolve the path if it's a symlink
            var resolvedPath = path
            let initialAttributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileType = initialAttributes[.type] as? FileAttributeType,
                fileType == .typeSymbolicLink
            {
                // It's a symlink, resolve it
                let linkDestination = try FileManager.default.destinationOfSymbolicLink(
                    atPath: path)
                // Handle relative paths
                if linkDestination.hasPrefix("/") {
                    resolvedPath = linkDestination
                } else {
                    let parentDir = (path as NSString).deletingLastPathComponent
                    resolvedPath = (parentDir as NSString).appendingPathComponent(linkDestination)
                }
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: resolvedPath)
            let context = JSContext.current()!

            let stat = JSValue(newObjectIn: context)!

            // File size
            if let size = attributes[.size] as? NSNumber {
                stat.setObject(size, forKeyedSubscript: "size")
            }

            // Modification date (timestamp in milliseconds)
            if let modDate = attributes[.modificationDate] as? Date {
                stat.setObject(modDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "mtime")
                stat.setObject(
                    modDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "modificationDate")
            }

            // Creation date (timestamp in milliseconds)
            if let createDate = attributes[.creationDate] as? Date {
                stat.setObject(
                    createDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "birthtime")
                stat.setObject(
                    createDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "creationDate")
            }

            // Access date (not available on all platforms, use modification date as fallback)
            if let accessDate = attributes[.modificationDate] as? Date {
                stat.setObject(
                    accessDate.timeIntervalSince1970 * 1000, forKeyedSubscript: "accessDate")
            }

            // POSIX file type detection (all 7 standard types)
            // After resolving symlinks, this should never be .typeSymbolicLink
            let fileType = attributes[FileAttributeKey.type] as? FileAttributeType
            let isFile = fileType == .typeRegular
            let isDirectory = fileType == .typeDirectory
            let isSymbolicLink = fileType == .typeSymbolicLink
            let isCharacterDevice = fileType == .typeCharacterSpecial
            let isBlockDevice = fileType == .typeBlockSpecial
            let isSocket = fileType == .typeSocket  // Note: Also covers FIFOs in Swift

            stat.setObject(isFile, forKeyedSubscript: "isFile")
            stat.setObject(isDirectory, forKeyedSubscript: "isDirectory")
            stat.setObject(isSymbolicLink, forKeyedSubscript: "isSymbolicLink")
            stat.setObject(isCharacterDevice, forKeyedSubscript: "isCharacterDevice")
            stat.setObject(isBlockDevice, forKeyedSubscript: "isBlockDevice")
            stat.setObject(isSocket, forKeyedSubscript: "isSocket")

            // Permissions (POSIX mode)
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                stat.setObject(posixPermissions, forKeyedSubscript: "mode")
                stat.setObject(posixPermissions, forKeyedSubscript: "permissions")
            }

            // Number of hard links
            if let referenceCount = attributes[.referenceCount] as? NSNumber {
                stat.setObject(referenceCount, forKeyedSubscript: "nlink")
            }

            return stat
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func copyItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func moveItem(_ sourcePath: String, _ destinationPath: String) -> Bool {
        do {
            try FileManager.default.moveItem(atPath: sourcePath, toPath: destinationPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }
    
    // Link operations

    func createSymbolicLink(_ targetPath: String, _ linkPath: String) -> Bool {
        do {
            try FileManager.default.createSymbolicLink(
                atPath: linkPath,
                withDestinationPath: targetPath
            )
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func createHardLink(_ sourcePath: String, _ linkPath: String) -> Bool {
        do {
            try FileManager.default.linkItem(atPath: sourcePath, toPath: linkPath)
            return true
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return false
        }
    }

    func readSymbolicLink(_ path: String) -> String? {
        do {
            return try FileManager.default.destinationOfSymbolicLink(atPath: path)
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    func lstat(_ path: String) -> JSValue? {
        // lstat returns information about the symlink itself, not its target
        // Use URL with .withoutResolvingSymlinks option
        let url = URL(fileURLWithPath: path)

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .creationDateKey,
                .contentModificationDateKey,
                .contentAccessDateKey,
                .fileResourceTypeKey,
            ])

            let context = JSContext.current()!
            let result = JSValue(newObjectIn: context)

            // File size
            if let size = resourceValues.fileSize {
                result?.setValue(size, forProperty: "size")
            } else if let size = attributes[.size] as? Int {
                result?.setValue(size, forProperty: "size")
            } else {
                result?.setValue(0, forProperty: "size")
            }

            // Dates
            if let creationDate = resourceValues.creationDate {
                result?.setValue(
                    creationDate.timeIntervalSince1970 * 1000, forProperty: "creationDate")
            }
            if let modDate = resourceValues.contentModificationDate {
                result?.setValue(
                    modDate.timeIntervalSince1970 * 1000, forProperty: "modificationDate")
            }
            if let accessDate = resourceValues.contentAccessDate {
                result?.setValue(accessDate.timeIntervalSince1970 * 1000, forProperty: "accessDate")
            }

            // Permissions
            if let permissions = attributes[.posixPermissions] as? Int {
                result?.setValue(permissions, forProperty: "permissions")
            }

            // POSIX file types - using FileAttributeType from attributes
            // This is the key difference from stat() - we don't resolve symlinks
            let fileType = attributes[.type] as? FileAttributeType

            result?.setValue(fileType == .typeRegular, forProperty: "isFile")
            result?.setValue(fileType == .typeDirectory, forProperty: "isDirectory")
            result?.setValue(fileType == .typeSymbolicLink, forProperty: "isSymbolicLink")
            result?.setValue(fileType == .typeCharacterSpecial, forProperty: "isCharacterDevice")
            result?.setValue(fileType == .typeBlockSpecial, forProperty: "isBlockDevice")
            result?.setValue(fileType == .typeSocket, forProperty: "isSocket")

            return result
        } catch {
            let context = JSContext.current()!
            context.exception = JSValue(newErrorFromMessage: "\(error)", in: context)
            return nil
        }
    }

    // MIME type detection with system fallback
    func getMimeType(_ fileExtension: String) -> String {
        // Normalize extension (remove leading dot if present, convert to lowercase)
        let normalizedExt =
            fileExtension.hasPrefix(".")
            ? String(fileExtension.dropFirst()).lowercased()
            : fileExtension.lowercased()

        // Try to get MIME type from system UTType (UniformTypeIdentifiers)
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            if let utType = UTType(filenameExtension: normalizedExt),
                let mimeType = utType.preferredMIMEType
            {
                return mimeType
            }
        }

        // Fallback to common MIME types mapping
        // Based on MDN Common MIME types: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types
        let commonMimes: [String: String] = [
            // Audio
            "aac": "audio/aac",
            "mid": "audio/midi",
            "midi": "audio/x-midi",
            "mp3": "audio/mpeg",
            "oga": "audio/ogg",
            "opus": "audio/ogg",
            "wav": "audio/wav",
            "weba": "audio/webm",
            "3gp": "audio/3gpp",
            "3g2": "audio/3gpp2",

            // Video
            "avi": "video/x-msvideo",
            "mp4": "video/mp4",
            "mpeg": "video/mpeg",
            "ogv": "video/ogg",
            "ts": "video/mp2t",
            "webm": "video/webm",

            // Images
            "apng": "image/apng",
            "avif": "image/avif",
            "bmp": "image/bmp",
            "gif": "image/gif",
            "ico": "image/vnd.microsoft.icon",
            "jpeg": "image/jpeg",
            "jpg": "image/jpeg",
            "png": "image/png",
            "svg": "image/svg+xml",
            "tif": "image/tiff",
            "tiff": "image/tiff",
            "webp": "image/webp",

            // Fonts
            "otf": "font/otf",
            "ttf": "font/ttf",
            "woff": "font/woff",
            "woff2": "font/woff2",

            // Documents
            "abw": "application/x-abiword",
            "azw": "application/vnd.amazon.ebook",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "epub": "application/epub+zip",
            "md": "text/markdown",
            "odt": "application/vnd.oasis.opendocument.text",
            "pdf": "application/pdf",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "rtf": "application/rtf",
            "vsd": "application/vnd.visio",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",

            // Spreadsheets & Presentations
            "odp": "application/vnd.oasis.opendocument.presentation",
            "ods": "application/vnd.oasis.opendocument.spreadsheet",

            // Web
            "css": "text/css",
            "htm": "text/html",
            "html": "text/html",
            "js": "text/javascript",
            "mjs": "text/javascript",
            "xhtml": "application/xhtml+xml",

            // Data
            "csv": "text/csv",
            "ics": "text/calendar",
            "json": "application/json",
            "jsonld": "application/ld+json",
            "xml": "application/xml",

            // Archives
            "7z": "application/x-7z-compressed",
            "arc": "application/x-freearc",
            "bz": "application/x-bzip",
            "bz2": "application/x-bzip2",
            "gz": "application/gzip",
            "jar": "application/java-archive",
            "rar": "application/vnd.rar",
            "tar": "application/x-tar",
            "zip": "application/zip",

            // Scripts & Code
            "csh": "application/x-csh",
            "php": "application/x-httpd-php",
            "sh": "application/x-sh",

            // Other
            "bin": "application/octet-stream",
            "cda": "application/x-cdf",
            "eot": "application/vnd.ms-fontobject",
            "mpkg": "application/vnd.apple.installer+xml",
            "ogx": "application/ogg",
            "txt": "text/plain",
            "webmanifest": "application/manifest+json",
            "xul": "application/vnd.mozilla.xul+xml",
        ]

        return commonMimes[normalizedExt] ?? "application/octet-stream"
    }

    // Streaming methods for efficient file reading
    func getFileSize(_ path: String) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            return 0
        }
    }

    func createReadFileHandle(_ path: String) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, _ in
            // Open file on a background queue to avoid blocking the JS thread
            DispatchQueue.global().async {
                if let fileHandle = FileHandle(forReadingAtPath: path) {
                    // Register the handle in a thread-safe way using the context lock
                    self.context.handleLock.lock()
                    self.context.handleCounter += 1
                    let handleId = self.context.handleCounter
                    self.context.openFileHandles[handleId] = fileHandle
                    self.context.handleLock.unlock()

                    resolve?.call(withArguments: [
                        JSValue(double: Double(handleId), in: jsContext)!
                    ])
                } else {
                    resolve?.call(withArguments: [JSValue(double: Double(-1), in: jsContext)!])
                }
            }
        }
    }

    func readFileHandleChunk(_ handle: Int, _ length: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            // Obtain the file handle in a thread-safe way
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles[handle]
            self.context.handleLock.unlock()

            guard let fileHandle = fileHandle else {
                // Must call resolve on JS thread
                resolve?.call(withArguments: [JSValue(nullIn: jsContext)!])
                return
            }

            // Read from file on a background queue
            DispatchQueue.global().async {
                do {
                    let data = try fileHandle.read(upToCount: length) ?? Data()

                    if data.isEmpty {
                        // EOF - resolve on JS thread
                        self.runloop.perform {
                            resolve?.call(withArguments: [JSValue(nullIn: jsContext)!])
                        }
                        return
                    }
                    // Create JS typed array and resolve on JS thread
                    let dataCopy = data  // capture
                    self.runloop.perform {
                        let uint8Array = JSValue.uint8Array(count: dataCopy.count, in: jsContext) {
                            buffer in
                            dataCopy.copyBytes(
                                to: buffer.bindMemory(to: UInt8.self), count: dataCopy.count)
                        }
                        resolve?.call(withArguments: [uint8Array])
                    }
                } catch {
                    self.runloop.perform {
                        reject?.call(withArguments: [
                            JSValue(newErrorFromMessage: "\(error)", in: jsContext)!
                        ])
                    }
                }
            }
        }
    }

    func closeFileHandle(_ handle: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, _ in
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles.removeValue(forKey: handle)
            self.context.handleLock.unlock()

            if let fileHandle = fileHandle {
                DispatchQueue.global().async { fileHandle.closeFile() }
            }

            resolve?.call(withArguments: [JSValue(undefinedIn: jsContext)!])
        }
    }

    // Write streaming methods for memory-efficient file writing
    func createWriteFileHandle(_ path: String, _ flags: Int) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            DispatchQueue.global().async {
                // Decode flags: bit 0 = append, bit 1 = exclusive
                let append = (flags & 1) != 0
                let exclusive = (flags & 2) != 0

                // Build POSIX open flags
                var openFlags = O_WRONLY | O_CREAT
                if exclusive {
                    openFlags |= O_EXCL
                }
                if append {
                    openFlags |= O_APPEND  // Use O_APPEND for atomic append operations
                } else {
                    openFlags |= O_TRUNC
                }

                // Open file using POSIX (atomic for exclusive mode)
                let fd = open(path, openFlags, 0o644)

                if fd == -1 {
                    let errorNum = errno
                    let error = String(cString: strerror(errorNum))
                    self.runloop.perform {
                        let message =
                            errorNum == EEXIST
                            ? "File already exists: \(path)"
                            : "Failed to open file: \(error)"
                        reject?.call(withArguments: [
                            JSValue(newErrorFromMessage: message, in: jsContext)!
                        ])
                    }
                    return
                }

                let fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)

                // Note: No need to seek - O_APPEND flag ensures atomic append to end of file

                // Register the write handle
                self.context.handleLock.lock()
                self.context.handleCounter += 1
                let handleId = self.context.handleCounter
                self.context.openFileHandles[handleId] = fileHandle
                self.context.handleLock.unlock()

                self.runloop.perform {
                    resolve?.call(withArguments: [
                        JSValue(double: Double(handleId), in: jsContext)!
                    ])
                }
            }
        }
    }

    func writeFileHandleChunk(_ handle: Int, _ data: JSValue) -> JSValue {
        guard let jsContext = JSContext.current() else {
            return JSValue(undefinedIn: JSContext.current() ?? JSContext())
        }

        return JSValue(newPromiseIn: jsContext) { resolve, reject in
            self.context.handleLock.lock()
            let fileHandle = self.context.openFileHandles[handle]
            self.context.handleLock.unlock()

            guard let fileHandle = fileHandle else {
                self.runloop.perform {
                    reject?.call(withArguments: [
                        JSValue(newErrorFromMessage: "Invalid file handle", in: jsContext)!
                    ])
                }
                return
            }

            // Convert JS data to Swift Data
            DispatchQueue.global().async {
                do {
                    let swiftData: Data

                    if data.isTypedArray {
                        let bytes = data.typedArrayBytes
                        swiftData = Data(bytes.bindMemory(to: UInt8.self))
                    } else if data.isString {
                        swiftData = data.toString().data(using: .utf8) ?? Data()
                    } else {
                        self.runloop.perform {
                            reject?.call(withArguments: [
                                JSValue(
                                    newErrorFromMessage: "Unsupported data type for write",
                                    in: jsContext)!
                            ])
                        }
                        return
                    }

                    // Write chunk to file
                    try fileHandle.write(contentsOf: swiftData)

                    self.runloop.perform {
                        resolve?.call(withArguments: [JSValue(bool: true, in: jsContext)!])
                    }
                } catch {
                    self.runloop.perform {
                        reject?.call(withArguments: [
                            JSValue(newErrorFromMessage: "\(error)", in: jsContext)!
                        ])
                    }
                }
            }
        }
    }
    
    // MARK: - Directory Streaming Methods

    func openDirectoryStream(_ path: String) -> Int {
        let fileManager = FileManager.default

        // Check if path exists and is a directory
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return -1
        }

        // Create a true streaming enumerator (lazy, doesn't load all entries upfront)
        // Use skipsSubdirectoryDescendants option for shallow (non-recursive) iteration
        let url = URL(fileURLWithPath: path)
        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants]
            )
        else {
            return -1
        }

        // Store enumerator with handle ID
        context.handleLock.lock()
        let handleId = context.nextHandleId
        context.nextHandleId += 1
        context.openDirectoryEnumerators[handleId] = (enumerator, path)
        context.handleLock.unlock()

        return handleId
    }

    func readNextDirectoryEntry(_ handle: Int) -> JSValue? {
        guard let jsContext = JSContext.current() else {
            return nil
        }

        context.handleLock.lock()
        guard let (enumerator, basePath) = context.openDirectoryEnumerators[handle] else {
            context.handleLock.unlock()
            return nil
        }
        context.handleLock.unlock()

        // Get next entry from enumerator (true streaming - no full array loaded)
        guard let fileURL = enumerator.nextObject() as? URL else {
            // End of directory - return null
            return JSValue(nullIn: jsContext)
        }

        let fullPath = fileURL.path
        let name = fileURL.lastPathComponent
        let parentPath = basePath

        // Get file attributes
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: fullPath) else {
            // If we can't get attributes, skip this entry and try next one
            return readNextDirectoryEntry(handle)
        }

        let fileType = attributes[FileAttributeKey.type] as? FileAttributeType
        
        // POSIX file type detection (all 7 standard types)
        let isFile = fileType == .typeRegular
        let isDirectory = fileType == .typeDirectory
        let isSymbolicLink = fileType == .typeSymbolicLink
        let isCharacterDevice = fileType == .typeCharacterSpecial
        let isBlockDevice = fileType == .typeBlockSpecial
        let isSocket = fileType == .typeSocket  // Note: Also covers FIFOs in Swift

        let size = (attributes[FileAttributeKey.size] as? NSNumber)?.int64Value ?? 0
        let modificationDate = (attributes[FileAttributeKey.modificationDate] as? Date) ?? Date()
        let creationDate = (attributes[FileAttributeKey.creationDate] as? Date) ?? Date()

        // Build entry object with all POSIX file type flags
        let entry = JSValue(newObjectIn: jsContext)!
        entry.setValue(name, forProperty: "name")
        entry.setValue(fullPath, forProperty: "path")
        entry.setValue(parentPath, forProperty: "parentPath")
        entry.setValue(isFile, forProperty: "isFile")
        entry.setValue(isDirectory, forProperty: "isDirectory")
        entry.setValue(isSymbolicLink, forProperty: "isSymbolicLink")
        entry.setValue(isCharacterDevice, forProperty: "isCharacterDevice")
        entry.setValue(isBlockDevice, forProperty: "isBlockDevice")
        entry.setValue(isSocket, forProperty: "isSocket")
        entry.setValue(size, forProperty: "size")
        entry.setValue(
            modificationDate.timeIntervalSince1970 * 1000, forProperty: "modificationDate")
        entry.setValue(creationDate.timeIntervalSince1970 * 1000, forProperty: "creationDate")

        // Add permissions if available (POSIX)
        if let posixPermissions = attributes[FileAttributeKey.posixPermissions] as? NSNumber {
            entry.setValue(posixPermissions.intValue, forProperty: "permissions")
        }

        return entry
    }

    func closeDirectoryStream(_ handle: Int) -> Bool {
        context.handleLock.lock()
        let removed = context.openDirectoryEnumerators.removeValue(forKey: handle) != nil
        context.handleLock.unlock()
        return removed
    }
}
