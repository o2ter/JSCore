//
//  ConsoleAPITests.kt
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

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Tests for enhanced Console API including timing, counting, grouping, and formatting
 */
class ConsoleAPITests {
    
    @Test
    fun testConsoleTimeAndTimeEnd() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            console.time('test');
            let sum = 0;
            for (let i = 0; i < 1000; i++) {
                sum += i;
            }
            console.timeEnd('test');
            sum
        """)
        
        assertEquals(499500, (result as? Number)?.toInt(), "Should execute code with timing")
    }
    
    @Test
    fun testConsoleCount() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            let counts = [];
            for (let i = 0; i < 3; i++) {
                console.count('test');
            }
            console.countReset('test');
            console.count('test');
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle count operations")
    }
    
    @Test
    fun testConsoleGroup() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            console.group('outer');
            console.log('outer level');
            console.group('inner');
            console.log('inner level');
            console.groupEnd();
            console.groupEnd();
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle nested groups")
    }
    
    @Test
    fun testConsoleTable() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            const data = [
                { name: 'Alice', age: 30 },
                { name: 'Bob', age: 25 }
            ];
            console.table(data);
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle table output")
    }
    
    @Test
    fun testConsoleAssert() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            console.assert(true, 'This should not print');
            console.assert(false, 'This should print an error');
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle assertions")
    }
    
    @Test
    fun testConsoleClear() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            console.log('Message 1');
            console.clear();
            console.log('Message 2');
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle clear operation")
    }
    
    @Test
    fun testConsoleDir() {
        val context = JvmPlatformContext("TestApp")
        val engine = JavaScriptEngine(context)
        
        val result = engine.execute("""
            const obj = { a: 1, b: { c: 2 } };
            console.dir(obj);
            'success'
        """)
        
        assertEquals("success", result?.toString(), "Should handle dir operation")
    }
}
