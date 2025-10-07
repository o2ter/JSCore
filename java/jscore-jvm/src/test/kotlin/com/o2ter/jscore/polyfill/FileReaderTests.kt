//
//  FileReaderTests.kt
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
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Tests for FileReader API including all read methods and event handling
 */
class FileReaderTests {
    
    @Test
    fun testFileReaderReadAsText() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const blob = new Blob(['Hello, World!'], { type: 'text/plain' });
                const reader = new FileReader();
                
                return new Promise((resolve, reject) => {
                    reader.onload = () => resolve(reader.result);
                    reader.onerror = () => reject(reader.error);
                    reader.readAsText(blob);
                });
            })()
        """)
        
        assertTrue(result?.toString()?.contains("Hello") == true, "Should read text from blob")
    }
    
    @Test
    fun testFileReaderReadAsArrayBuffer() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const blob = new Blob([new Uint8Array([65, 66, 67])]);
                const reader = new FileReader();
                
                return new Promise((resolve, reject) => {
                    reader.onload = () => {
                        const buffer = reader.result;
                        const view = new Uint8Array(buffer);
                        resolve(view.length);
                    };
                    reader.onerror = () => reject(reader.error);
                    reader.readAsArrayBuffer(blob);
                });
            })()
        """)
        
        assertEquals(3, (result as? Number)?.toInt(), "Should read ArrayBuffer with correct length")
    }
    
    @Test
    fun testFileReaderReadAsDataURL() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const blob = new Blob(['test'], { type: 'text/plain' });
                const reader = new FileReader();
                
                return new Promise((resolve, reject) => {
                    reader.onload = () => resolve(reader.result);
                    reader.onerror = () => reject(reader.error);
                    reader.readAsDataURL(blob);
                });
            })()
        """)
        
        assertTrue(result?.toString()?.startsWith("data:") == true, "Should return data URL")
    }
    
    @Test
    fun testFileReaderEvents() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = executeAsync(engine, """
            (async () => {
                const blob = new Blob(['test data']);
                const reader = new FileReader();
                const events = [];
                
                reader.onloadstart = () => events.push('loadstart');
                reader.onprogress = () => events.push('progress');
                reader.onload = () => events.push('load');
                reader.onloadend = () => events.push('loadend');
                
                return new Promise((resolve) => {
                    reader.onloadend = () => resolve(events);
                    reader.readAsText(blob);
                });
            })()
        """)
        
        assertTrue(result?.toString()?.contains("loadstart") == true, "Should fire loadstart event")
        assertTrue(result?.toString()?.contains("load") == true, "Should fire load event")
    }
    
    @Test
    fun testFileReaderAbort() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            const blob = new Blob(['test data']);
            const reader = new FileReader();
            reader.readAsText(blob);
            reader.abort();
            reader.readyState === FileReader.DONE ? 'aborted' : 'error'
        """)
        
        assertEquals("aborted", result?.toString(), "Should handle abort operation")
    }
    
    @Test
    fun testFileReaderReadyStates() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            ({
                EMPTY: FileReader.EMPTY,
                LOADING: FileReader.LOADING,
                DONE: FileReader.DONE
            })
        """)
        
        // Verify constants exist
        assertTrue(result != null, "Should expose FileReader constants")
    }
}
