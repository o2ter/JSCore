//
//  FileSystem.kt
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
import com.caoccao.javet.values.primitive.V8ValueString
import com.caoccao.javet.values.reference.V8ValueArray
import com.caoccao.javet.values.reference.V8ValueObject
import com.caoccao.javet.values.reference.V8ValueTypedArray
import com.o2ter.jscore.PlatformContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
import java.nio.file.attribute.BasicFileAttributes
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * FileSystem native bridge
 * Exposes file system operations to JavaScript via __NATIVE_BRIDGE__.FileSystem
 * 
 * File operation flags (bit flags):
 * - Bit 0 (value 1): Append mode
 * - Bit 1 (value 2): Exclusive mode (fail if exists)
 * Examples: 0 = truncate, 1 = append, 2 = exclusive, 3 = append+exclusive
 */
class FileSystem(
    private val v8Runtime: V8Runtime,
    private val platformContext: PlatformContext
) {
    private val openFileHandles = ConcurrentHashMap<Int, RandomAccessFile>()
    private val handleCounter = AtomicInteger(0)
    
    // Directory streaming support
    private val openDirectoryStreams = ConcurrentHashMap<Int, Iterator<Path>>()
    private val directoryHandleCounter = AtomicInteger(0)
    
    /**
     * Check if there are any active file handles
     * Used by JavaScriptEngine to determine when to exit
     */
    val hasActiveFileHandles: Boolean
        get() = openFileHandles.isNotEmpty()
    
    /**
     * Get the count of active file handles
     */
    val activeFileHandleCount: Int
        get() = openFileHandles.size
    
    fun setupBridge(nativeBridge: V8ValueObject) {
        val fileSystemObject = v8Runtime.createV8ValueObject()
        
        try {
            // homeDirectory() - get home directory path
            fileSystemObject.bindFunction(JavetCallbackContext(
                "homeDirectory",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueString(System.getProperty("user.home"))
                }
            ))
            
            // temporaryDirectory() - get temporary directory path
            fileSystemObject.bindFunction(JavetCallbackContext(
                "temporaryDirectory",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    val tempDir = System.getProperty("java.io.tmpdir")
                    // Remove trailing separator if present
                    val normalized = if (tempDir.endsWith(File.separator)) {
                        tempDir.substring(0, tempDir.length - 1)
                    } else {
                        tempDir
                    }
                    v8Runtime.createV8ValueString(normalized)
                }
            ))
            
            // currentDirectoryPath() - get current working directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "currentDirectoryPath",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { _ ->
                    v8Runtime.createV8ValueString(System.getProperty("user.dir"))
                }
            ))
            
            // changeCurrentDirectoryPath(path) - change working directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "changeCurrentDirectoryPath",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    val path = (v8Values[0] as V8ValueString).value
                    val dir = File(path)
                    
                    if (dir.exists() && dir.isDirectory) {
                        System.setProperty("user.dir", dir.absolutePath)
                        v8Runtime.createV8ValueBoolean(true)
                    } else {
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // exists(path) - check if file/directory exists
            fileSystemObject.bindFunction(JavetCallbackContext(
                "exists",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    val path = (v8Values[0] as V8ValueString).value
                    v8Runtime.createV8ValueBoolean(File(path).exists())
                }
            ))
            
            // isDirectory(path) - check if path is a directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "isDirectory",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    val path = (v8Values[0] as V8ValueString).value
                    v8Runtime.createV8ValueBoolean(File(path).isDirectory)
                }
            ))
            
            // isFile(path) - check if path is a file
            fileSystemObject.bindFunction(JavetCallbackContext(
                "isFile",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    val path = (v8Values[0] as V8ValueString).value
                    v8Runtime.createV8ValueBoolean(File(path).isFile)
                }
            ))
            
            // stat(path) - get file statistics
            fileSystemObject.bindFunction(JavetCallbackContext(
                "stat",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val file = File(path)
                        
                        if (!file.exists()) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val attrs = Files.readAttributes(file.toPath(), BasicFileAttributes::class.java)
                        val stat = v8Runtime.createV8ValueObject()
                        
                        // Convert to Double to ensure JavaScript receives a Number, not BigInt
                        stat.set("size", attrs.size().toDouble())
                        
                        // Timestamps in milliseconds (compatible with JavaScript Date)
                        stat.set("mtime", attrs.lastModifiedTime().toMillis().toDouble())
                        stat.set("modificationDate", attrs.lastModifiedTime().toMillis().toDouble())
                        stat.set("birthtime", attrs.creationTime().toMillis().toDouble())
                        stat.set("creationDate", attrs.creationTime().toMillis().toDouble())
                        stat.set("accessDate", attrs.lastAccessTime().toMillis().toDouble())
                        
                        // POSIX file type flags (matching SwiftJS implementation)
                        val isFile = attrs.isRegularFile
                        val isDirectory = attrs.isDirectory
                        val isSymbolicLink = attrs.isSymbolicLink
                        val isOther = attrs.isOther
                        
                        // Java NIO doesn't distinguish between different "other" types
                        // (character devices, block devices, sockets, FIFOs all report as isOther)
                        val isCharacterDevice = false  // Would need platform-specific code
                        val isBlockDevice = false      // Would need platform-specific code  
                        val isSocket = isOther         // Best approximation - includes sockets, FIFOs, etc.
                        
                        stat.set("isFile", isFile)
                        stat.set("isDirectory", isDirectory)
                        stat.set("isSymbolicLink", isSymbolicLink)
                        stat.set("isCharacterDevice", isCharacterDevice)
                        stat.set("isBlockDevice", isBlockDevice)
                        stat.set("isSocket", isSocket)
                        
                        // Unix permissions (if available)
                        try {
                            val perms = Files.getPosixFilePermissions(file.toPath())
                            var mode = 0
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OWNER_READ)) mode = mode or 0x100
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OWNER_WRITE)) mode = mode or 0x80
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OWNER_EXECUTE)) mode = mode or 0x40
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.GROUP_READ)) mode = mode or 0x20
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.GROUP_WRITE)) mode = mode or 0x10
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.GROUP_EXECUTE)) mode = mode or 0x8
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_READ)) mode = mode or 0x4
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_WRITE)) mode = mode or 0x2
                            if (perms.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_EXECUTE)) mode = mode or 0x1
                            stat.set("mode", mode)
                            stat.set("permissions", mode)
                        } catch (e: Exception) {
                            // POSIX permissions not supported on this platform
                        }
                        
                        stat
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "stat failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // readFileData(path) - read entire file as binary data (Uint8Array)
            fileSystemObject.bindFunction(JavetCallbackContext(
                "readFileData",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val file = File(path)
                        
                        if (!file.exists() || !file.isFile) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val bytes = file.readBytes()
                        val array = v8Runtime.createV8ValueTypedArray(
                            com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                            bytes.size
                        )
                        array.fromBytes(bytes)
                        array
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "readFileData failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // readFile(path, options) - read file contents
            // options can be { encoding: 'binary', start: 0, end: 100 } for binary slice or omitted for text
            fileSystemObject.bindFunction(JavetCallbackContext(
                "readFile",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        
                        // Extract options: encoding, start, end
                        var encoding = "utf-8"
                        var start: Long? = null
                        var end: Long? = null
                        
                        if (v8Values.size > 1 && v8Values[1] is V8ValueObject) {
                            val options = v8Values[1] as V8ValueObject
                            
                            val encodingValue = options.get<V8Value>("encoding")
                            if (encodingValue is V8ValueString) {
                                encoding = encodingValue.value
                            }
                            encodingValue?.close()
                            
                            val startValue = options.get<V8Value>("start")
                            if (startValue is V8ValueInteger) {
                                start = startValue.value.toLong()
                            }
                            startValue?.close()
                            
                            val endValue = options.get<V8Value>("end")
                            if (endValue is V8ValueInteger) {
                                end = endValue.value.toLong()
                            }
                            endValue?.close()
                        }
                        
                        val file = File(path)
                        if (!file.exists() || !file.isFile) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        if (encoding == "binary") {
                            // Read binary data with optional byte range
                            val bytes = if (start != null || end != null) {
                                // Read slice from file
                                val fileSize = file.length()
                                val actualStart = start?.coerceIn(0, fileSize) ?: 0
                                val actualEnd = end?.coerceIn(0, fileSize) ?: fileSize
                                val length = (actualEnd - actualStart).toInt().coerceAtLeast(0)
                                
                                if (length == 0) {
                                    ByteArray(0)
                                } else {
                                    file.inputStream().use { input ->
                                        input.skip(actualStart)
                                        val buffer = ByteArray(length)
                                        val bytesRead = input.read(buffer)
                                        if (bytesRead < length) {
                                            buffer.copyOf(bytesRead)
                                        } else {
                                            buffer
                                        }
                                    }
                                }
                            } else {
                                // Read entire file
                                file.readBytes()
                            }
                            
                            val array = v8Runtime.createV8ValueTypedArray(
                                com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                                bytes.size
                            )
                            array.fromBytes(bytes)
                            array
                        } else {
                            // Return string for text data (encoding is handled by JavaScript if needed)
                            // Note: start/end not supported for text mode
                            val content = file.readText(Charsets.UTF_8)
                            v8Runtime.createV8ValueString(content)
                        }
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "readFile failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // writeFile(path, data, flags) - write file contents
            fileSystemObject.bindFunction(JavetCallbackContext(
                "writeFile",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.size < 2 || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val data = v8Values[1]
                        val flags = if (v8Values.size > 2 && v8Values[2] is V8ValueInteger) {
                            (v8Values[2] as V8ValueInteger).value
                        } else 0
                        
                        // Decode flags: bit 0 = append, bit 1 = exclusive
                        val append = (flags and 1) != 0
                        val exclusive = (flags and 2) != 0
                        
                        val file = File(path)
                        
                        // Check exclusive flag
                        if (exclusive && file.exists()) {
                            platformContext.logger.error("FileSystem", "File already exists: $path")
                            return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                        }
                        
                        // Convert data to bytes
                        val bytes = when (data) {
                            is V8ValueTypedArray -> data.toBytes()
                            is V8ValueString -> data.value.toByteArray(Charsets.UTF_8)
                            else -> {
                                platformContext.logger.error("FileSystem", "Unsupported data type for writeFile")
                                return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                            }
                        }
                        
                        // Write to file
                        if (append) {
                            FileOutputStream(file, true).use { it.write(bytes) }
                        } else {
                            file.writeBytes(bytes)
                        }
                        
                        v8Runtime.createV8ValueBoolean(true)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "writeFile failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // readDirectory(path) - list directory contents
            fileSystemObject.bindFunction(JavetCallbackContext(
                "readDirectory",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val dir = File(path)
                        
                        if (!dir.exists() || !dir.isDirectory) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val entries = dir.list() ?: emptyArray()
                        val array = v8Runtime.createV8ValueArray()
                        entries.forEachIndexed { index, entry ->
                            array.set(index, entry)
                        }
                        array
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "readDirectory failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // createDirectory(path) - create directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "createDirectory",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val result = File(path).mkdirs()
                        v8Runtime.createV8ValueBoolean(result)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "createDirectory failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // removeItem(path) - remove file or directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "removeItem",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val file = File(path)
                        val result = file.deleteRecursively()
                        v8Runtime.createV8ValueBoolean(result)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "removeItem failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // copyItem(source, dest) - copy file or directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "copyItem",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.size < 2 || 
                        v8Values[0] !is V8ValueString || 
                        v8Values[1] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val source = (v8Values[0] as V8ValueString).value
                        val dest = (v8Values[1] as V8ValueString).value
                        
                        Files.copy(
                            Paths.get(source),
                            Paths.get(dest),
                            StandardCopyOption.REPLACE_EXISTING
                        )
                        v8Runtime.createV8ValueBoolean(true)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "copyItem failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // moveItem(source, dest) - move/rename file or directory
            fileSystemObject.bindFunction(JavetCallbackContext(
                "moveItem",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.size < 2 || 
                        v8Values[0] !is V8ValueString || 
                        v8Values[1] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val source = (v8Values[0] as V8ValueString).value
                        val dest = (v8Values[1] as V8ValueString).value
                        
                        Files.move(
                            Paths.get(source),
                            Paths.get(dest),
                            StandardCopyOption.REPLACE_EXISTING
                        )
                        v8Runtime.createV8ValueBoolean(true)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "moveItem failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // getFileSize(path) - get file size
            fileSystemObject.bindFunction(JavetCallbackContext(
                "getFileSize",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(0)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val size = File(path).length()
                        v8Runtime.createV8ValueLong(size)
                    } catch (e: Exception) {
                        v8Runtime.createV8ValueInteger(0)
                    }
                }
            ))
            
            // createReadFileHandle(path) - create read handle
            fileSystemObject.bindFunction(JavetCallbackContext(
                "createReadFileHandle",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(-1)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val file = RandomAccessFile(path, "r")
                        val handleId = handleCounter.incrementAndGet()
                        openFileHandles[handleId] = file
                        v8Runtime.createV8ValueInteger(handleId)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "createReadFileHandle failed: ${e.message}")
                        v8Runtime.createV8ValueInteger(-1)
                    }
                }
            ))
            
            // readFileHandleChunk(handle, length) - read chunk from handle
            fileSystemObject.bindFunction(JavetCallbackContext(
                "readFileHandleChunk",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.size < 2 || 
                        v8Values[0] !is V8ValueInteger || 
                        v8Values[1] !is V8ValueInteger) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val handleId = (v8Values[0] as V8ValueInteger).value
                        val length = (v8Values[1] as V8ValueInteger).value
                        
                        val file = openFileHandles[handleId]
                        if (file == null) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val buffer = ByteArray(length)
                        val bytesRead = file.read(buffer)
                        
                        if (bytesRead <= 0) {
                            // EOF
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val actualData = if (bytesRead < length) {
                            buffer.copyOf(bytesRead)
                        } else {
                            buffer
                        }
                        
                        val array = v8Runtime.createV8ValueTypedArray(
                            com.caoccao.javet.enums.V8ValueReferenceType.Uint8Array,
                            actualData.size
                        )
                        array.fromBytes(actualData)
                        array
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "readFileHandleChunk failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // closeFileHandle(handle) - close file handle
            fileSystemObject.bindFunction(JavetCallbackContext(
                "closeFileHandle",
                JavetCallbackType.DirectCallNoThisAndNoResult,
                IJavetDirectCallable.NoThisAndNoResult<Exception> { v8Values ->
                    if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                        val handleId = (v8Values[0] as V8ValueInteger).value
                        val file = openFileHandles.remove(handleId)
                        file?.close()
                    }
                }
            ))
            
            // createWriteFileHandle(path, flags) - create write handle
            fileSystemObject.bindFunction(JavetCallbackContext(
                "createWriteFileHandle",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(-1)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val flags = if (v8Values.size > 1 && v8Values[1] is V8ValueInteger) {
                            (v8Values[1] as V8ValueInteger).value
                        } else 0
                        
                        // Decode flags: bit 0 = append, bit 1 = exclusive
                        val append = (flags and 1) != 0
                        val exclusive = (flags and 2) != 0
                        
                        val file = File(path)
                        
                        // Check exclusive flag
                        if (exclusive && file.exists()) {
                            platformContext.logger.error("FileSystem", "File already exists: $path")
                            return@NoThisAndResult v8Runtime.createV8ValueInteger(-1)
                        }
                        
                        // Open file for writing
                        val raf = RandomAccessFile(file, "rw")
                        
                        if (!append) {
                            // Truncate file
                            raf.setLength(0)
                        } else {
                            // Seek to end
                            raf.seek(raf.length())
                        }
                        
                        val handleId = handleCounter.incrementAndGet()
                        openFileHandles[handleId] = raf
                        v8Runtime.createV8ValueInteger(handleId)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "createWriteFileHandle failed: ${e.message}")
                        v8Runtime.createV8ValueInteger(-1)
                    }
                }
            ))
            
            // writeFileHandleChunk(handle, data) - write chunk to handle
            fileSystemObject.bindFunction(JavetCallbackContext(
                "writeFileHandleChunk",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.size < 2 || v8Values[0] !is V8ValueInteger) {
                        return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                    }
                    
                    try {
                        val handleId = (v8Values[0] as V8ValueInteger).value
                        val data = v8Values[1]
                        
                        val file = openFileHandles[handleId]
                        if (file == null) {
                            return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                        }
                        
                        // Convert data to bytes
                        val bytes = when (data) {
                            is V8ValueTypedArray -> data.toBytes()
                            is V8ValueString -> data.value.toByteArray(Charsets.UTF_8)
                            else -> {
                                platformContext.logger.error("FileSystem", "Unsupported data type for write")
                                return@NoThisAndResult v8Runtime.createV8ValueBoolean(false)
                            }
                        }
                        
                        file.write(bytes)
                        v8Runtime.createV8ValueBoolean(true)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "writeFileHandleChunk failed: ${e.message}")
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // openDirectoryStream(path) - open directory for streaming iteration
            fileSystemObject.bindFunction(JavetCallbackContext(
                "openDirectoryStream",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueInteger(-1)
                    }
                    
                    try {
                        val path = (v8Values[0] as V8ValueString).value
                        val dir = Paths.get(path)
                        
                        // Check if path exists and is a directory
                        if (!Files.exists(dir) || !Files.isDirectory(dir)) {
                            return@NoThisAndResult v8Runtime.createV8ValueInteger(-1)
                        }
                        
                        // Create directory stream (shallow iteration)
                        val stream = Files.newDirectoryStream(dir)
                        val iterator = stream.iterator()
                        
                        val handleId = directoryHandleCounter.incrementAndGet()
                        openDirectoryStreams[handleId] = iterator
                        v8Runtime.createV8ValueInteger(handleId)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "openDirectoryStream failed: ${e.message}")
                        v8Runtime.createV8ValueInteger(-1)
                    }
                }
            ))
            
            // readNextDirectoryEntry(handle) - read next entry from directory stream
            fileSystemObject.bindFunction(JavetCallbackContext(
                "readNextDirectoryEntry",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueInteger) {
                        return@NoThisAndResult v8Runtime.createV8ValueNull()
                    }
                    
                    try {
                        val handleId = (v8Values[0] as V8ValueInteger).value
                        val iterator = openDirectoryStreams[handleId]
                        
                        if (iterator == null || !iterator.hasNext()) {
                            return@NoThisAndResult v8Runtime.createV8ValueNull()
                        }
                        
                        val entryPath = iterator.next()
                        val name = entryPath.fileName.toString()
                        val fullPath = entryPath.toAbsolutePath().toString()
                        val parentPath = entryPath.parent.toAbsolutePath().toString()
                        
                        // Get file attributes
                        val attrs = Files.readAttributes(entryPath, BasicFileAttributes::class.java)
                        
                        // POSIX file type detection (matching SwiftJS implementation)
                        val isFile = attrs.isRegularFile
                        val isDirectory = attrs.isDirectory
                        val isSymbolicLink = attrs.isSymbolicLink
                        
                        // For other file types, we need platform-specific detection
                        // Java NIO doesn't provide detailed file type info beyond regular/directory/symlink/other
                        // On Unix-like systems, we can check if it's "other" and attempt to determine the specific type
                        val isOther = attrs.isOther
                        
                        // Note: Java NIO doesn't distinguish between character devices, block devices, sockets, and FIFOs
                        // They all report as isOther() = true
                        // For full POSIX file type support, we'd need JNI or platform-specific code
                        // For now, we conservatively set these to false unless we can definitively determine them
                        val isCharacterDevice = false  // Would need platform-specific code
                        val isBlockDevice = false      // Would need platform-specific code
                        val isSocket = isOther         // Best approximation - includes sockets, FIFOs, etc.
                        
                        // Build entry object - DO NOT use .use {} because we're returning this to JavaScript
                        val entry = v8Runtime.createV8ValueObject()
                        entry.set("name", name)
                        entry.set("path", fullPath)
                        entry.set("parentPath", parentPath)
                        entry.set("isFile", isFile)
                        entry.set("isDirectory", isDirectory)
                        entry.set("isSymbolicLink", isSymbolicLink)
                        entry.set("isCharacterDevice", isCharacterDevice)
                        entry.set("isBlockDevice", isBlockDevice)
                        entry.set("isSocket", isSocket)
                        entry.set("size", attrs.size().toDouble())  // Convert to Double to avoid BigInt
                        entry.set("modificationDate", attrs.lastModifiedTime().toMillis().toDouble())
                        entry.set("creationDate", attrs.creationTime().toMillis().toDouble())
                        
                        // Try to get POSIX permissions
                        try {
                            val posixAttrs = Files.getPosixFilePermissions(entryPath)
                            var mode = 0
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OWNER_READ)) mode = mode or 0x100
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OWNER_WRITE)) mode = mode or 0x080
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OWNER_EXECUTE)) mode = mode or 0x040
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.GROUP_READ)) mode = mode or 0x020
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.GROUP_WRITE)) mode = mode or 0x010
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.GROUP_EXECUTE)) mode = mode or 0x008
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_READ)) mode = mode or 0x004
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_WRITE)) mode = mode or 0x002
                            if (posixAttrs.contains(java.nio.file.attribute.PosixFilePermission.OTHERS_EXECUTE)) mode = mode or 0x001
                            entry.set("permissions", mode)
                        } catch (e: Exception) {
                            // POSIX permissions not available on this platform
                        }
                        
                        // Mark as weak so V8 GC will handle lifecycle
                        entry.setWeak()
                        return@NoThisAndResult entry
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "readNextDirectoryEntry failed: ${e.message}")
                        v8Runtime.createV8ValueNull()
                    }
                }
            ))
            
            // closeDirectoryStream(handle) - close directory stream
            fileSystemObject.bindFunction(JavetCallbackContext(
                "closeDirectoryStream",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isNotEmpty() && v8Values[0] is V8ValueInteger) {
                        val handleId = (v8Values[0] as V8ValueInteger).value
                        openDirectoryStreams.remove(handleId)
                        v8Runtime.createV8ValueBoolean(true)
                    } else {
                        v8Runtime.createV8ValueBoolean(false)
                    }
                }
            ))
            
            // getMimeType(fileExtension) - detect MIME type by file extension
            fileSystemObject.bindFunction(JavetCallbackContext(
                "getMimeType",
                JavetCallbackType.DirectCallNoThisAndResult,
                IJavetDirectCallable.NoThisAndResult<Exception> { v8Values ->
                    if (v8Values.isEmpty() || v8Values[0] !is V8ValueString) {
                        return@NoThisAndResult v8Runtime.createV8ValueString("application/octet-stream")
                    }
                    
                    try {
                        val fileExtension = (v8Values[0] as V8ValueString).value
                        val mimeType = detectMimeType(fileExtension)
                        v8Runtime.createV8ValueString(mimeType)
                    } catch (e: Exception) {
                        platformContext.logger.error("FileSystem", "getMimeType failed: ${e.message}")
                        v8Runtime.createV8ValueString("application/octet-stream")
                    }
                }
            ))
            
            // Register with __NATIVE_BRIDGE__
            nativeBridge.set("FileSystem", fileSystemObject)
            
        } finally {
            fileSystemObject.close()
        }
    }
    
    /**
     * Detect MIME type by file extension using Java's built-in capabilities with fallback
     * Based on MDN Common MIME types: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types
     */
    private fun detectMimeType(fileExtension: String): String {
        // Normalize extension (add dot if missing, convert to lowercase)
        val ext = if (fileExtension.startsWith(".")) {
            fileExtension.lowercase()
        } else {
            ".${fileExtension.lowercase()}"
        }
        
        // Try to use Java's built-in MIME type detection first
        try {
            val tempFileName = "temp$ext"
            val path = Paths.get(tempFileName)
            val mimeType = Files.probeContentType(path)
            if (mimeType != null && mimeType.isNotBlank()) {
                return mimeType
            }
        } catch (e: Exception) {
            // Fall through to hardcoded mapping
        }
        
        // Fallback to comprehensive MIME type mapping
        // Based on MDN Common MIME types: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types
        val commonMimes = mapOf(
            // Audio
            ".aac" to "audio/aac",
            ".mid" to "audio/midi",
            ".midi" to "audio/x-midi", 
            ".mp3" to "audio/mpeg",
            ".oga" to "audio/ogg",
            ".opus" to "audio/ogg",
            ".wav" to "audio/wav",
            ".weba" to "audio/webm",
            ".3gp" to "audio/3gpp",
            ".3g2" to "audio/3gpp2",
            
            // Video
            ".avi" to "video/x-msvideo",
            ".mp4" to "video/mp4",
            ".mpeg" to "video/mpeg",
            ".ogv" to "video/ogg",
            ".ts" to "video/mp2t",
            ".webm" to "video/webm",
            
            // Images
            ".apng" to "image/apng",
            ".avif" to "image/avif",
            ".bmp" to "image/bmp",
            ".gif" to "image/gif",
            ".ico" to "image/vnd.microsoft.icon",
            ".jpeg" to "image/jpeg",
            ".jpg" to "image/jpeg",
            ".png" to "image/png",
            ".svg" to "image/svg+xml",
            ".tif" to "image/tiff",
            ".tiff" to "image/tiff",
            ".webp" to "image/webp",
            
            // Fonts
            ".otf" to "font/otf",
            ".ttf" to "font/ttf",
            ".woff" to "font/woff",
            ".woff2" to "font/woff2",
            
            // Documents
            ".abw" to "application/x-abiword",
            ".azw" to "application/vnd.amazon.ebook",
            ".doc" to "application/msword",
            ".docx" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".epub" to "application/epub+zip",
            ".md" to "text/markdown",
            ".odt" to "application/vnd.oasis.opendocument.text",
            ".pdf" to "application/pdf",
            ".ppt" to "application/vnd.ms-powerpoint",
            ".pptx" to "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            ".rtf" to "application/rtf",
            ".vsd" to "application/vnd.visio",
            ".xls" to "application/vnd.ms-excel",
            ".xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            
            // Spreadsheets & Presentations
            ".odp" to "application/vnd.oasis.opendocument.presentation",
            ".ods" to "application/vnd.oasis.opendocument.spreadsheet",
            
            // Web
            ".css" to "text/css",
            ".htm" to "text/html",
            ".html" to "text/html",
            ".js" to "text/javascript",
            ".mjs" to "text/javascript",
            ".xhtml" to "application/xhtml+xml",
            
            // Data
            ".csv" to "text/csv",
            ".ics" to "text/calendar",
            ".json" to "application/json",
            ".jsonld" to "application/ld+json",
            ".xml" to "application/xml",
            
            // Archives
            ".7z" to "application/x-7z-compressed",
            ".arc" to "application/x-freearc",
            ".bz" to "application/x-bzip",
            ".bz2" to "application/x-bzip2",
            ".gz" to "application/gzip",
            ".jar" to "application/java-archive",
            ".rar" to "application/vnd.rar",
            ".tar" to "application/x-tar",
            ".zip" to "application/zip",
            
            // Scripts & Code
            ".csh" to "application/x-csh",
            ".php" to "application/x-httpd-php",
            ".sh" to "application/x-sh",
            
            // Other
            ".bin" to "application/octet-stream",
            ".cda" to "application/x-cdf",
            ".eot" to "application/vnd.ms-fontobject",
            ".mpkg" to "application/vnd.apple.installer+xml",
            ".ogx" to "application/ogg",
            ".txt" to "text/plain",
            ".webmanifest" to "application/manifest+json",
            ".xul" to "application/vnd.mozilla.xul+xml"
        )
        
        return commonMimes[ext] ?: "application/octet-stream"
    }

    /**
     * Close all open file handles
     * Implements standard resource cleanup pattern
     */
    fun close() {
        openFileHandles.values.forEach { it.close() }
        openFileHandles.clear()
        openDirectoryStreams.clear()
    }
}
