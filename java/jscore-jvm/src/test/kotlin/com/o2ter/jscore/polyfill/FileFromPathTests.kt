//
//  FileFromPathTests.kt
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

package com.o2ter.jscore.polyfill

import com.o2ter.jscore.executeAsync
import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Tests for File.fromPath() API including filesystem access and MIME type detection
 */
class FileFromPathTests {
    
    @Test
    fun testFileFromPathBasic() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Create a temporary test file
        val tempFile = File.createTempFile("test", ".txt")
        tempFile.writeText("Hello, World!")
        tempFile.deleteOnExit()
        
        val result = executeAsync(engine, """
            (async () => {
                const file = File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}');
                return {
                    name: file.name,
                    size: file.size,
                    type: file.type
                };
            })()
        """)
        
        assertTrue(result?.toString()?.contains("txt") == true, "Should create File from path")
    }
    
    @Test
    fun testFileFromPathReadAsText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val tempFile = File.createTempFile("test", ".txt")
        tempFile.writeText("Test content")
        tempFile.deleteOnExit()
        
        val result = executeAsync(engine, """
            (async () => {
                const file = File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}');
                return await file.text();
            })()
        """)
        
        assertEquals("Test content", result?.toString(), "Should read file content as text")
    }
    
    @Test
    fun testFileFromPathStream() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val tempFile = File.createTempFile("test", ".bin")
        tempFile.writeBytes(byteArrayOf(1, 2, 3, 4, 5))
        tempFile.deleteOnExit()
        
        val result = executeAsync(engine, """
            (async () => {
                const file = File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}');
                const stream = file.stream();
                const reader = stream.getReader();
                
                let totalBytes = 0;
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    totalBytes += value.length;
                }
                
                return totalBytes;
            })()
        """)
        
        assertEquals(5, (result as? Number)?.toInt(), "Should stream file content")
    }
    
    @Test
    fun testFileFromPathMimeType() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Create temporary files with different extensions
        val txtFile = File.createTempFile("test", ".txt")
        txtFile.writeText("text")
        txtFile.deleteOnExit()
        
        val jsonFile = File.createTempFile("test", ".json")
        jsonFile.writeText("{}")
        jsonFile.deleteOnExit()
        
        val result = engine.execute("""
            ({
                txt: File.fromPath('${txtFile.absolutePath.replace("\\", "\\\\")}').type,
                json: File.fromPath('${jsonFile.absolutePath.replace("\\", "\\\\")}').type
            })
        """)
        
        assertTrue(result?.toString()?.contains("text") == true, "Should detect MIME types")
    }
    
    @Test
    fun testFileFromPathSize() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        // Create a file with known size
        val tempFile = File.createTempFile("test", ".txt")
        tempFile.writeText("12345")
        tempFile.deleteOnExit()
        
        val result = engine.execute("""
            File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}').size
        """)
        
        assertEquals(5, (result as? Number)?.toInt(), "Should report correct file size")
    }
    
    @Test
    fun testFileFromPathArrayBuffer() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val tempFile = File.createTempFile("test", ".bin")
        tempFile.writeBytes(byteArrayOf(65, 66, 67)) // ABC
        tempFile.deleteOnExit()
        
        val result = executeAsync(engine, """
            (async () => {
                const file = File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}');
                const buffer = await file.arrayBuffer();
                const view = new Uint8Array(buffer);
                return Array.from(view);
            })()
        """)
        
        assertTrue(result?.toString()?.contains("65") == true, "Should read as ArrayBuffer")
    }
    
    @Test
    fun testFileFromPathSlice() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val tempFile = File.createTempFile("test", ".txt")
        tempFile.writeText("0123456789")
        tempFile.deleteOnExit()
        
        val result = executeAsync(engine, """
            (async () => {
                const file = File.fromPath('${tempFile.absolutePath.replace("\\", "\\\\")}');
                const slice = file.slice(2, 5);
                return await slice.text();
            })()
        """)
        
        assertEquals("234", result?.toString(), "Should slice file content")
    }
}
