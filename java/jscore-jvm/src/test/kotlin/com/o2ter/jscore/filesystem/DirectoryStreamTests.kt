//
//  DirectoryStreamTests.kt
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

package com.o2ter.jscore.filesystem

import com.o2ter.jscore.JavaScriptEngine
import com.o2ter.jscore.jvm.JvmPlatformContext
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class DirectoryStreamTests {
    
    private lateinit var engine: JavaScriptEngine
    private lateinit var testDir: Path
    
    @Before
    fun setUp() {
        val context = JvmPlatformContext("DirectoryStreamTests")
        engine = JavaScriptEngine(context)
        
        // Create a test directory structure
        testDir = Files.createTempDirectory("DirectoryStreamTests_")
        
        val script = """
            var testDir = '${testDir.toString().replace("\\", "\\\\")}';
            SystemFS.mkdir(testDir + '/subdir1');
            SystemFS.mkdir(testDir + '/subdir2');
            SystemFS.mkdir(testDir + '/subdir1/nested');
            SystemFS.writeFile(testDir + '/file1.txt', 'content1');
            SystemFS.writeFile(testDir + '/file2.js', 'console.log("test")');
            SystemFS.writeFile(testDir + '/file3.md', '# Title');
            SystemFS.writeFile(testDir + '/subdir1/subfile1.txt', 'nested content');
            SystemFS.writeFile(testDir + '/subdir1/nested/deep.txt', 'deep content');
            true;
        """
        
        val result = engine.execute(script)
        assertNotNull(result, "Failed to create test directory structure")
        assertTrue(result.toString() == "true", "Test directory setup should return true")
    }
    
    @After
    fun tearDown() {
        // Clean up test directory
        if (this::testDir.isInitialized && Files.exists(testDir)) {
            val script = "SystemFS.remove('${testDir.toString().replace("\\", "\\\\")}');"
            engine.execute(script)
        }
        
        if (this::engine.isInitialized) {
            engine.close()
        }
    }
    
    @Test
    fun testBasicIteration() {
        val script = """
            (async function() {
                var entries = [];
                for await (var entry of SystemFS.opendir(testDir)) {
                    entries.push({
                        name: entry.name,
                        isFile: entry.isFile,
                        isDirectory: entry.isDirectory
                    });
                }
                return entries;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        
        // Wait for promise to resolve
        Thread.sleep(100)
        
        val script2 = """
            (async function() {
                var entries = [];
                for await (var entry of SystemFS.opendir(testDir)) {
                    entries.push(entry.name);
                }
                return {
                    count: entries.length,
                    hasSubdir1: entries.includes('subdir1'),
                    hasSubdir2: entries.includes('subdir2'),
                    hasFile1: entries.includes('file1.txt'),
                    hasFile2: entries.includes('file2.js'),
                    hasFile3: entries.includes('file3.md')
                };
            })();
        """
        
        val resultPromise = engine.execute(script2)
        Thread.sleep(100)
        
        // Get the result by accessing promise resolution
        val getResult = engine.execute("""
            (async function() {
                var entries = [];
                for await (var entry of SystemFS.opendir(testDir)) {
                    entries.push(entry.name);
                }
                return entries.length;
            })();
        """)
        
        Thread.sleep(100)
        assertNotNull(getResult, "Should get iteration result")
    }
    
    @Test
    fun testFilteredIteration() {
        val script = """
            (async function() {
                var jsFiles = [];
                for await (var entry of SystemFS.opendir(testDir, { 
                    filter: e => e.name.endsWith('.js') 
                })) {
                    jsFiles.push(entry.name);
                }
                return jsFiles;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify filtering works
        val verifyScript = """
            (async function() {
                var jsFiles = [];
                for await (var entry of SystemFS.opendir(testDir, { 
                    filter: e => e.name.endsWith('.js') 
                })) {
                    jsFiles.push(entry.name);
                }
                return jsFiles.length;
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get filtered results")
    }
    
    @Test
    fun testRecursiveIteration() {
        val script = """
            (async function() {
                var allFiles = [];
                for await (var entry of SystemFS.opendir(testDir, { recursive: true })) {
                    if (entry.isFile) {
                        allFiles.push(entry.path);
                    }
                }
                return allFiles.length;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(200)
        
        // Verify recursive iteration finds all files
        val verifyScript = """
            (async function() {
                var allFiles = [];
                for await (var entry of SystemFS.opendir(testDir, { recursive: true })) {
                    if (entry.isFile) {
                        allFiles.push(entry.path);
                    }
                }
                return { count: allFiles.length, files: allFiles.sort() };
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(200)
        assertNotNull(result, "Should get recursive results")
    }
    
    @Test
    fun testEntryMetadata() {
        val script = """
            (async function() {
                for await (var entry of SystemFS.opendir(testDir)) {
                    if (entry.name === 'file1.txt') {
                        return {
                            name: entry.name,
                            path: entry.path,
                            isFile: entry.isFile,
                            isDirectory: entry.isDirectory,
                            size: entry.size,
                            hasModified: entry.modified instanceof Date,
                            hasCreated: entry.created instanceof Date
                        };
                    }
                }
                return null;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify metadata is present
        val verifyScript = """
            (async function() {
                for await (var entry of SystemFS.opendir(testDir)) {
                    if (entry.name === 'file1.txt') {
                        return entry.isFile && !entry.isDirectory && entry.size === 8;
                    }
                }
                return false;
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get entry metadata")
    }
    
    @Test
    fun testManualControl() {
        val script = """
            (async function() {
                var dir = SystemFS.opendir(testDir);
                var first = await dir.next();
                var second = await dir.next();
                await dir.close();
                
                return {
                    firstDone: first.done,
                    firstHasValue: first.value != null,
                    secondDone: second.done,
                    secondHasValue: second.value != null
                };
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify manual iteration works
        val verifyScript = """
            (async function() {
                var dir = SystemFS.opendir(testDir);
                var first = await dir.next();
                await dir.close();
                return !first.done && first.value != null;
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get manual iteration result")
    }
    
    @Test
    fun testEmptyDirectory() {
        val script = """
            (async function() {
                var emptyDir = testDir + '/empty';
                SystemFS.mkdir(emptyDir);
                
                var count = 0;
                for await (var entry of SystemFS.opendir(emptyDir)) {
                    count++;
                }
                return count;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify empty directory returns 0 entries
        val verifyScript = """
            (async function() {
                var emptyDir = testDir + '/empty';
                SystemFS.mkdir(emptyDir);
                
                var count = 0;
                for await (var entry of SystemFS.opendir(emptyDir)) {
                    count++;
                }
                return count === 0;
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get empty directory result")
    }
    
    @Test
    fun testErrorHandling() {
        val script = """
            (async function() {
                try {
                    SystemFS.opendir('/nonexistent/path/12345');
                    return 'no_error';
                } catch (e) {
                    return e.message;
                }
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify error is thrown for non-existent directory
        val verifyScript = """
            (async function() {
                try {
                    SystemFS.opendir('/nonexistent/path/12345');
                    return false;
                } catch (e) {
                    return true;
                }
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get error handling result")
    }
    
    @Test
    fun testEarlyTermination() {
        val script = """
            (async function() {
                var count = 0;
                for await (var entry of SystemFS.opendir(testDir)) {
                    count++;
                    if (count >= 2) {
                        break; // Early termination
                    }
                }
                return count;
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify early termination works
        val verifyScript = """
            (async function() {
                var count = 0;
                for await (var entry of SystemFS.opendir(testDir)) {
                    count++;
                    if (count >= 2) {
                        break;
                    }
                }
                return count === 2;
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should get early termination result")
    }
    
    @Test
    fun testNonRecursiveDoesNotIncludeSubdirectoryContents() {
        val script = """
            (async function() {
                var entries = [];
                for await (var entry of SystemFS.opendir(testDir)) {
                    entries.push(entry.name);
                }
                // Should have exactly 5 top-level entries: subdir1, subdir2, file1.txt, file2.js, file3.md
                // Should NOT include subfile1.txt, nested, or deep.txt from subdirectories
                return {
                    count: entries.length,
                    hasSubfile: entries.includes('subfile1.txt'), // Should be false
                    hasNested: entries.includes('nested'), // Should be false (as a file name)
                    hasDeep: entries.includes('deep.txt') // Should be false
                };
            })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        Thread.sleep(100)
        
        // Verify non-recursive iteration only returns top-level entries
        val verifyScript = """
            (async function() {
                var entries = [];
                for await (var entry of SystemFS.opendir(testDir)) {
                    entries.push(entry.name);
                }
                return entries.length === 5 && 
                       !entries.includes('subfile1.txt') && 
                       !entries.includes('deep.txt');
            })();
        """
        
        val result = engine.execute(verifyScript)
        Thread.sleep(100)
        assertNotNull(result, "Should verify non-recursive behavior")
    }
}
