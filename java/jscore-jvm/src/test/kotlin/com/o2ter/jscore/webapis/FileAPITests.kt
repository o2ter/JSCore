//
//  FileAPITests.kt
//  KotlinJS File API Comprehensive Tests
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

package com.o2ter.jscore.webapis

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.executeAsync
import com.o2ter.jscore.jvm.JvmPlatformContext
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Comprehensive tests for Web File and Blob APIs including File, Blob,
 * File.fromPath with disk-based operations, slicing, and streaming.
 */
class FileAPITests {
    
    // Helper method to create temp directory for tests
    private fun createTempDir(engine: JavaScriptEngine): String {
        val result = engine.execute("""
            const tempBase = SystemFS.temp;
            const testDir = Path.join(tempBase, 'KotlinJS-FileTests-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9));
            SystemFS.mkdir(testDir);
            testDir
        """)
        return result.toString()
    }
    
    // Helper method to clean up temp directory
    private fun cleanupTempDir(tempDir: String, engine: JavaScriptEngine) {
        engine.execute("""
            if (SystemFS.exists('$tempDir')) {
                SystemFS.rmdir('$tempDir', { recursive: true });
            }
        """)
    }
    
    // MARK: - Blob API Tests
    
    @Test
    fun testBlobExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof Blob")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const blob = new Blob(['Hello, World!']);
                blob instanceof Blob
            """)
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobBasicProperties() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const blob = new Blob(['Hello, World!'], { type: 'text/plain' });
                ({
                    size: blob.size,
                    type: blob.type,
                    isBlob: blob instanceof Blob
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(13, (result["size"] as? Number)?.toInt()) // "Hello, World!" is 13 bytes
            assertEquals("text/plain", result["type"])
            assertEquals(true, result["isBlob"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobFromMultipleParts() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const blob = new Blob(['Hello, ', 'World!', ' 🌍'], { type: 'text/plain' });
                ({
                    size: blob.size,
                    type: blob.type
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("text/plain", result["type"])
            val size = (result["size"] as? Number)?.toInt() ?: 0
            assertTrue(size > 15) // Should be at least 15 bytes (emoji takes multiple bytes)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobArrayBufferConversion() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const blob = new Blob(['Hello, World!']);
                    const buffer = await blob.arrayBuffer();
                    const view = new Uint8Array(buffer);
                    return {
                        size: buffer.byteLength,
                        firstByte: view[0], // 'H'
                        lastByte: view[view.length - 1], // '!'
                        isArrayBuffer: buffer instanceof ArrayBuffer
                    };
                })()
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(13, (result["size"] as? Number)?.toInt())
            assertEquals(72, (result["firstByte"] as? Number)?.toInt()) // 'H' = 72
            assertEquals(33, (result["lastByte"] as? Number)?.toInt()) // '!' = 33
            assertEquals(true, result["isArrayBuffer"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobTextConversion() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const blob = new Blob(['Hello, World! 🌍']);
                    return await blob.text();
                })()
            """)
            
            assertEquals("Hello, World! 🌍", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBlobSlice() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const originalBlob = new Blob(['Hello, World!']);
                    const slicedBlob = originalBlob.slice(0, 5);
                    
                    const original = await originalBlob.text();
                    const sliced = await slicedBlob.text();
                    
                    return {
                        original: original,
                        sliced: sliced,
                        originalSize: originalBlob.size,
                        slicedSize: slicedBlob.size
                    };
                })()
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("Hello, World!", result["original"])
            assertEquals("Hello", result["sliced"])
            assertEquals(13, (result["originalSize"] as? Number)?.toInt())
            assertEquals(5, (result["slicedSize"] as? Number)?.toInt())
        } finally {
            engine.close()
        }
    }
    
    // MARK: - File API Tests
    
    @Test
    fun testFileExists() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("typeof File")
            assertEquals("function", result.toString())
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileInstantiation() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const file = new File(['Hello, World!'], 'test.txt', { type: 'text/plain' });
                file instanceof File
            """)
            assertTrue(result as? Boolean == true)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileProperties() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                const now = Date.now();
                const file = new File(['Hello, World!'], 'test.txt', { 
                    type: 'text/plain',
                    lastModified: now
                });
                
                ({
                    name: file.name,
                    size: file.size,
                    type: file.type,
                    lastModified: file.lastModified,
                    isFile: file instanceof File,
                    isBlob: file instanceof Blob,
                    lastModifiedCorrect: file.lastModified === now
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("test.txt", result["name"])
            assertEquals(13, (result["size"] as? Number)?.toInt())
            assertEquals("text/plain", result["type"])
            assertEquals(true, result["isFile"])
            assertEquals(true, result["isBlob"])
            assertEquals(true, result["lastModifiedCorrect"])
        } finally {
            engine.close()
        }
    }
    
    // MARK: - File.fromPath Tests
    
    @Test
    fun testFileFromPath() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = engine.execute("""
                // Create a test file first
                const testFile = Path.join('$tempDir', 'test-file.txt');
                const testContent = 'Hello from file system!';
                SystemFS.writeFile(testFile, testContent);
                
                // Now test File.fromPath
                try {
                    const file = File.fromPath(testFile);
                    ({
                        success: true,
                        name: file.name,
                        type: file.type,
                        size: file.size,
                        isFile: file instanceof File,
                        exists: SystemFS.exists(testFile)
                    })
                } catch (error) {
                    ({
                        success: false,
                        error: error.message
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertEquals("test-file.txt", result["name"])
            assertEquals("text/plain", result["type"])
            assertEquals(true, result["isFile"])
            assertEquals(true, result["exists"])
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileFromPathWithMimeTypes() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = engine.execute("""
                const testFiles = [
                    { name: 'test.txt', expected: 'text/plain' },
                    { name: 'test.html', expected: 'text/html' },
                    { name: 'test.json', expected: 'application/json' },
                    { name: 'test.js', expected: 'text/javascript' },
                    { name: 'test.css', expected: 'text/css' },
                    { name: 'test.png', expected: 'image/png' },
                    { name: 'test.jpg', expected: 'image/jpeg' },
                    { name: 'test.unknown', expected: 'application/octet-stream' }
                ];
                
                const results = [];
                
                for (const testFile of testFiles) {
                    const filePath = Path.join('$tempDir', testFile.name);
                    SystemFS.writeFile(filePath, 'test content');
                    
                    try {
                        const file = File.fromPath(filePath);
                        results.push({
                            name: testFile.name,
                            expected: testFile.expected,
                            actual: file.type,
                            match: file.type === testFile.expected
                        });
                    } catch (error) {
                        results.push({
                            name: testFile.name,
                            error: error.message
                        });
                    }
                }
                
                results
            """) as? List<*>
            
            assertNotNull(result)
            assertEquals(8, result.size)
            
            // Check that all MIME types are correctly detected
            result.forEach { testResult ->
                val resultMap = testResult as? Map<*, *>
                assertNotNull(resultMap)
                assertEquals(true, resultMap["match"], "MIME type mismatch for ${resultMap["name"]}")
            }
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileStreamingFromPath() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = executeAsync(engine, """
                (async () => {
                    // Create a larger test file
                    const testFile = Path.join('$tempDir', 'large-test.txt');
                    const testContent = 'Hello from file system! '.repeat(1000);
                    SystemFS.writeFile(testFile, testContent);
                    
                    const file = File.fromPath(testFile);
                    const stream = file.stream();
                    const reader = stream.getReader();
                    
                    let chunks = [];
                    let totalSize = 0;
                    
                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;
                        chunks.push(value);
                        totalSize += value.byteLength;
                    }
                    
                    const combined = new Uint8Array(totalSize);
                    let offset = 0;
                    for (const chunk of chunks) {
                        combined.set(chunk, offset);
                        offset += chunk.byteLength;
                    }
                    const text = new TextDecoder().decode(combined);
                    
                    return {
                        success: true,
                        chunkCount: chunks.length,
                        totalSize: totalSize,
                        textLength: text.length,
                        matchesOriginal: text === testContent,
                        expectedLength: testContent.length
                    };
                })()
            """, timeoutMs = 30000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(true, result["success"])
            assertTrue((result["chunkCount"] as? Number)?.toInt() ?: 0 > 0)
            assertTrue((result["totalSize"] as? Number)?.toInt() ?: 0 > 20000) // Should be substantial
            assertEquals(true, result["matchesOriginal"])
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - File.slice() Tests with Disk-Based Files
    
    @Test
    fun testFileSliceFromDisk() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = executeAsync(engine, """
                (async () => {
                    // Create a test file with known content
                    const testFile = Path.join('$tempDir', 'slice-test.txt');
                    const content = 'Hello, World! This is a test file for slicing.';
                    SystemFS.writeFile(testFile, content);
                    
                    // Create File from path and slice it
                    const file = File.fromPath(testFile);
                    const slice1 = file.slice(0, 5);      // "Hello"
                    const slice2 = file.slice(7, 12);     // "World"
                    const slice3 = file.slice(14, 18);    // "This"
                    const slice4 = file.slice(-8);        // "slicing."
                    
                    const text1 = await slice1.text();
                    const text2 = await slice2.text();
                    const text3 = await slice3.text();
                    const text4 = await slice4.text();
                    
                    return {
                        slice1: text1,
                        slice2: text2,
                        slice3: text3,
                        slice4: text4,
                        slice1Size: slice1.size,
                        slice2Size: slice2.size,
                        originalSize: file.size
                    };
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("Hello", result["slice1"])
            assertEquals("World", result["slice2"])
            assertEquals("This", result["slice3"])
            assertEquals("slicing.", result["slice4"])
            assertEquals(5, (result["slice1Size"] as? Number)?.toInt())
            assertEquals(5, (result["slice2Size"] as? Number)?.toInt())
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileSliceLargeFileFromDisk() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = executeAsync(engine, """
                (async () => {
                    // Create a larger file for testing memory efficiency
                    const testFile = Path.join('$tempDir', 'large-slice-test.txt');
                    const chunk = 'ABCDEFGHIJ'; // 10 bytes
                    const content = chunk.repeat(10000); // 100KB
                    SystemFS.writeFile(testFile, content);
                    
                    const file = File.fromPath(testFile);
                    
                    // Slice different parts of the large file
                    const slice1 = file.slice(0, 10);           // First chunk
                    const slice2 = file.slice(50000, 50010);    // Middle chunk
                    const slice3 = file.slice(-10);             // Last chunk
                    
                    const text1 = await slice1.text();
                    const text2 = await slice2.text();
                    const text3 = await slice3.text();
                    
                    return {
                        firstChunk: text1,
                        middleChunk: text2,
                        lastChunk: text3,
                        slice1Size: slice1.size,
                        slice2Size: slice2.size,
                        slice3Size: slice3.size,
                        originalSize: file.size
                    };
                })()
            """, timeoutMs = 15000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("ABCDEFGHIJ", result["firstChunk"])
            assertEquals("ABCDEFGHIJ", result["middleChunk"])
            assertEquals("ABCDEFGHIJ", result["lastChunk"])
            assertEquals(10, (result["slice1Size"] as? Number)?.toInt())
            assertEquals(10, (result["slice2Size"] as? Number)?.toInt())
            assertEquals(10, (result["slice3Size"] as? Number)?.toInt())
            assertEquals(100000, (result["originalSize"] as? Number)?.toInt())
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileSliceEdgeCases() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = executeAsync(engine, """
                (async () => {
                    const testFile = Path.join('$tempDir', 'edge-case-test.txt');
                    const content = 'Hello, World!'; // 13 bytes
                    SystemFS.writeFile(testFile, content);
                    
                    const file = File.fromPath(testFile);
                    
                    // Edge cases
                    const emptySlice = file.slice(5, 5);          // Empty slice (start == end)
                    const outOfBounds = file.slice(100, 200);     // Beyond file size
                    const negativeStart = file.slice(-5, -2);     // Negative indices
                    const noEnd = file.slice(7);                  // No end parameter
                    const zeroStart = file.slice(0, 0);           // Zero-length at start
                    
                    const text1 = await emptySlice.text();
                    const text2 = await outOfBounds.text();
                    const text3 = await negativeStart.text();
                    const text4 = await noEnd.text();
                    const text5 = await zeroStart.text();
                    
                    return {
                        emptySlice: text1,
                        emptySliceSize: emptySlice.size,
                        outOfBounds: text2,
                        outOfBoundsSize: outOfBounds.size,
                        negativeStart: text3,
                        negativeStartSize: negativeStart.size,
                        noEnd: text4,
                        noEndSize: noEnd.size,
                        zeroStart: text5,
                        zeroStartSize: zeroStart.size
                    };
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            
            // Empty slice
            assertEquals("", result["emptySlice"])
            assertEquals(0, (result["emptySliceSize"] as? Number)?.toInt())
            
            // Out of bounds
            assertEquals("", result["outOfBounds"])
            assertEquals(0, (result["outOfBoundsSize"] as? Number)?.toInt())
            
            // Negative start (last 5 chars minus last 2 = "orl")
            assertEquals("orl", result["negativeStart"])
            assertEquals(3, (result["negativeStartSize"] as? Number)?.toInt())
            
            // No end (from position 7 to end = "World!")
            assertEquals("World!", result["noEnd"])
            assertEquals(6, (result["noEndSize"] as? Number)?.toInt())
            
            // Zero start
            assertEquals("", result["zeroStart"])
            assertEquals(0, (result["zeroStartSize"] as? Number)?.toInt())
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileSliceBinaryData() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = executeAsync(engine, """
                (async () => {
                    const testFile = Path.join('$tempDir', 'binary-slice-test.bin');
                    
                    // Create binary data
                    const binaryData = new Uint8Array(256);
                    for (let i = 0; i < 256; i++) {
                        binaryData[i] = i;
                    }
                    
                    SystemFS.writeFile(testFile, binaryData);
                    
                    const file = File.fromPath(testFile);
                    
                    // Slice binary data at different positions
                    const slice1 = file.slice(0, 10);      // First 10 bytes
                    const slice2 = file.slice(100, 110);   // Bytes 100-109
                    const slice3 = file.slice(246, 256);   // Last 10 bytes
                    
                    const buffer1 = await slice1.arrayBuffer();
                    const buffer2 = await slice2.arrayBuffer();
                    const buffer3 = await slice3.arrayBuffer();
                    
                    const view1 = new Uint8Array(buffer1);
                    const view2 = new Uint8Array(buffer2);
                    const view3 = new Uint8Array(buffer3);
                    
                    return {
                        slice1First: view1[0],
                        slice1Last: view1[9],
                        slice2First: view2[0],
                        slice2Last: view2[9],
                        slice3First: view3[0],
                        slice3Last: view3[9],
                        sizes: [view1.length, view2.length, view3.length]
                    };
                })()
            """, timeoutMs = 10000) as? Map<*, *>
            
            assertNotNull(result)
            
            // First slice: bytes 0-9
            assertEquals(0, (result["slice1First"] as? Number)?.toInt())
            assertEquals(9, (result["slice1Last"] as? Number)?.toInt())
            
            // Second slice: bytes 100-109
            assertEquals(100, (result["slice2First"] as? Number)?.toInt())
            assertEquals(109, (result["slice2Last"] as? Number)?.toInt())
            
            // Third slice: bytes 246-255
            assertEquals(246, (result["slice3First"] as? Number)?.toInt())
            assertEquals(255, (result["slice3Last"] as? Number)?.toInt())
            
            val sizes = result["sizes"] as? List<*>
            assertNotNull(sizes)
            assertEquals(10, (sizes[0] as? Number)?.toInt())
            assertEquals(10, (sizes[1] as? Number)?.toInt())
            assertEquals(10, (sizes[2] as? Number)?.toInt())
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testFileSliceWithContentType() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val tempDir = createTempDir(engine)
            
            val result = engine.execute("""
                const testFile = Path.join('$tempDir', 'content-type-test.txt');
                const content = 'Hello, World!';
                SystemFS.writeFile(testFile, content);
                
                const file = File.fromPath(testFile);
                
                // Slice with different content types
                const slice1 = file.slice(0, 5, 'text/plain');
                const slice2 = file.slice(7, 12, 'application/json');
                const slice3 = file.slice(0, 5);  // No content type
                
                ({
                    type1: slice1.type,
                    type2: slice2.type,
                    type3: slice3.type
                })
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals("text/plain", result["type1"])
            assertEquals("application/json", result["type2"])
            assertEquals("", result["type3"]) // Empty when not specified
            
            cleanupTempDir(tempDir, engine)
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    fun testFileFromPathNonexistentFile() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = engine.execute("""
                try {
                    const file = File.fromPath('/nonexistent/path/file.txt');
                    ({
                        success: true,
                        file: file
                    })
                } catch (error) {
                    ({
                        success: false,
                        error: error.message,
                        errorType: error.constructor.name
                    })
                }
            """) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(false, result["success"])
            val errorMsg = result["error"].toString()
            assertTrue(errorMsg.contains("not found", ignoreCase = true) || errorMsg.contains("File not found", ignoreCase = true))
        } finally {
            engine.close()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test
    fun testEmptyFile() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    const emptyFile = new File([], 'empty.txt');
                    
                    const text = await emptyFile.text();
                    const arrayBuffer = await emptyFile.arrayBuffer();
                    
                    return {
                        text: text,
                        arrayBuffer: arrayBuffer,
                        size: emptyFile.size,
                        textIsEmpty: text === '',
                        bufferIsEmpty: arrayBuffer.byteLength === 0
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(0, (result["size"] as? Number)?.toInt())
            assertEquals(true, result["textIsEmpty"])
            assertEquals(true, result["bufferIsEmpty"])
        } finally {
            engine.close()
        }
    }
    
    @Test
    fun testBinaryFileHandling() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        try {
            val result = executeAsync(engine, """
                (async () => {
                    // Create a binary-like file with various byte values
                    const binaryData = new Uint8Array(256);
                    for (let i = 0; i < 256; i++) {
                        binaryData[i] = i;
                    }
                    
                    const binaryBlob = new Blob([binaryData], { type: 'application/octet-stream' });
                    const binaryFile = new File([binaryBlob], 'binary.bin', { type: 'application/octet-stream' });
                    
                    const buffer = await binaryFile.arrayBuffer();
                    const view = new Uint8Array(buffer);
                    let allCorrect = true;
                    for (let i = 0; i < 256; i++) {
                        if (view[i] !== i) {
                            allCorrect = false;
                            break;
                        }
                    }
                    
                    return {
                        size: buffer.byteLength,
                        firstByte: view[0],
                        lastByte: view[255],
                        allBytesCorrect: allCorrect
                    };
                })()
            """, timeoutMs = 5000) as? Map<*, *>
            
            assertNotNull(result)
            assertEquals(256, (result["size"] as? Number)?.toInt())
            assertEquals(0, (result["firstByte"] as? Number)?.toInt())
            assertEquals(255, (result["lastByte"] as? Number)?.toInt())
            assertEquals(true, result["allBytesCorrect"])
        } finally {
            engine.close()
        }
    }
}
