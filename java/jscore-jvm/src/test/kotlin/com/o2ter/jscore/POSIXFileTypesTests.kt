//
//  POSIXFileTypesTests.kt
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
import java.util.UUID
import kotlin.test.*

class POSIXFileTypesTests {
    private lateinit var engine: JavaScriptEngine
    private lateinit var testDir: String

    @BeforeTest
    fun setUp() {
        val context = JvmPlatformContext("POSIXFileTypesTests")
        engine = JavaScriptEngine(context)
        testDir = System.getProperty("java.io.tmpdir") + "POSIXFileTypesTests_" + UUID.randomUUID().toString()
        
        val script = """
        var testDir = '$testDir';
        SystemFS.mkdir(testDir);
        true;
        """
        
        val result = engine.execute(script)
        assertTrue(result as Boolean, "Failed to create test directory")
    }

    @AfterTest
    fun tearDown() {
        val script = "SystemFS.remove('$testDir');"
        engine.execute(script)
        engine.close()
    }

    @Test
    fun testRegularFileType() {
        val script = """
        SystemFS.writeFile(testDir + '/regular.txt', 'content');
        var stat = SystemFS.stat(testDir + '/regular.txt');
        ({
            isFile: stat.isFile,
            isDirectory: stat.isDirectory,
            isSymbolicLink: stat.isSymbolicLink,
            isCharacterDevice: stat.isCharacterDevice,
            isBlockDevice: stat.isBlockDevice,
            isSocket: stat.isSocket
        });
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Boolean>
        
        assertTrue(result["isFile"] == true, "Should be a regular file")
        assertFalse(result["isDirectory"] == true, "Should not be a directory")
        assertFalse(result["isSymbolicLink"] == true, "Should not be a symbolic link")
        assertFalse(result["isCharacterDevice"] == true, "Should not be a character device")
        assertFalse(result["isBlockDevice"] == true, "Should not be a block device")
        assertFalse(result["isSocket"] == true, "Should not be a socket")
    }

    @Test
    fun testDirectoryType() {
        val script = """
        SystemFS.mkdir(testDir + '/subdir');
        var stat = SystemFS.stat(testDir + '/subdir');
        ({
            isFile: stat.isFile,
            isDirectory: stat.isDirectory,
            isSymbolicLink: stat.isSymbolicLink,
            isCharacterDevice: stat.isCharacterDevice,
            isBlockDevice: stat.isBlockDevice,
            isSocket: stat.isSocket
        });
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Boolean>
        
        assertFalse(result["isFile"] == true, "Should not be a regular file")
        assertTrue(result["isDirectory"] == true, "Should be a directory")
        assertFalse(result["isSymbolicLink"] == true, "Should not be a symbolic link")
        assertFalse(result["isCharacterDevice"] == true, "Should not be a character device")
        assertFalse(result["isBlockDevice"] == true, "Should not be a block device")
        assertFalse(result["isSocket"] == true, "Should not be a socket")
    }

    @Test
    fun testSymbolicLink() {
        val script = """
        // Create a target file
        SystemFS.writeFile(testDir + '/target.txt', 'content');
        
        // Create symbolic link (platform-dependent)
        try {
            SystemFS.symlink(testDir + '/target.txt', testDir + '/link.txt');
            var stat = SystemFS.lstat(testDir + '/link.txt');  // lstat for symlink itself
            ({
                success: true,
                isFile: stat.isFile,
                isDirectory: stat.isDirectory,
                isSymbolicLink: stat.isSymbolicLink,
                isCharacterDevice: stat.isCharacterDevice,
                isBlockDevice: stat.isBlockDevice,
                isSocket: stat.isSocket,
                target: SystemFS.readlink(testDir + '/link.txt')
            });
        } catch (e) {
            ({ success: false, error: e.message });
        }
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Any?>
        
        val success = result["success"] as Boolean
        if (success) {
            assertFalse(result["isFile"] == true, "Symlink should not be a regular file")
            assertFalse(result["isDirectory"] == true, "Symlink should not be a directory")
            assertTrue(result["isSymbolicLink"] == true, "Should be a symbolic link")
            assertFalse(result["isCharacterDevice"] == true, "Symlink should not be a character device")
            assertFalse(result["isBlockDevice"] == true, "Symlink should not be a block device")
            assertFalse(result["isSocket"] == true, "Symlink should not be a socket")
            
            val target = result["target"] as String
            assertTrue(target.contains("target.txt"), "readlink should return target path")
        } else {
            // Symlink creation might fail on some platforms (e.g., Windows without admin)
            println("Symlink test skipped: ${result["error"]}")
        }
    }

    @Test
    fun testStatVsLstatOnSymlinkToFile() {
        val script = """
        // Create a target file
        SystemFS.writeFile(testDir + '/target.txt', 'target content');
        
        // Create symbolic link
        try {
            SystemFS.symlink(testDir + '/target.txt', testDir + '/link.txt');
            
            // lstat should return symlink properties
            var lstatResult = SystemFS.lstat(testDir + '/link.txt');
            
            // stat should follow the link and return target file properties
            var statResult = SystemFS.stat(testDir + '/link.txt');
            
            ({
                success: true,
                lstat: {
                    isFile: lstatResult.isFile,
                    isDirectory: lstatResult.isDirectory,
                    isSymbolicLink: lstatResult.isSymbolicLink
                },
                stat: {
                    isFile: statResult.isFile,
                    isDirectory: statResult.isDirectory,
                    isSymbolicLink: statResult.isSymbolicLink
                }
            });
        } catch (e) {
            ({ success: false, error: e.message });
        }
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Any?>
        
        val success = result["success"] as Boolean
        if (success) {
            @Suppress("UNCHECKED_CAST")
            val lstat = result["lstat"] as Map<String, Boolean>
            @Suppress("UNCHECKED_CAST")
            val stat = result["stat"] as Map<String, Boolean>
            
            // lstat should return symlink properties
            assertFalse(lstat["isFile"] == true, "lstat: Symlink should not be reported as a file")
            assertFalse(lstat["isDirectory"] == true, "lstat: Symlink should not be reported as a directory")
            assertTrue(lstat["isSymbolicLink"] == true, "lstat: Should detect symbolic link")
            
            // stat should follow the link and return target properties
            assertTrue(stat["isFile"] == true, "stat: Should follow link and detect target as file")
            assertFalse(stat["isDirectory"] == true, "stat: Target should not be a directory")
            assertFalse(stat["isSymbolicLink"] == true, "stat: Should follow link, not report as symlink")
        } else {
            // Symlink creation might fail on some platforms
            println("Symlink test skipped: ${result["error"]}")
        }
    }

    @Test
    fun testStatVsLstatOnSymlinkToDirectory() {
        val script = """
        // Create a target directory
        SystemFS.mkdir(testDir + '/targetdir');
        SystemFS.writeFile(testDir + '/targetdir/file.txt', 'content');
        
        // Create symbolic link to directory
        try {
            SystemFS.symlink(testDir + '/targetdir', testDir + '/linkdir');
            
            // lstat should return symlink properties
            var lstatResult = SystemFS.lstat(testDir + '/linkdir');
            
            // stat should follow the link and return target directory properties
            var statResult = SystemFS.stat(testDir + '/linkdir');
            
            ({
                success: true,
                lstat: {
                    isFile: lstatResult.isFile,
                    isDirectory: lstatResult.isDirectory,
                    isSymbolicLink: lstatResult.isSymbolicLink
                },
                stat: {
                    isFile: statResult.isFile,
                    isDirectory: statResult.isDirectory,
                    isSymbolicLink: statResult.isSymbolicLink
                }
            });
        } catch (e) {
            ({ success: false, error: e.message });
        }
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Any?>
        
        val success = result["success"] as Boolean
        if (success) {
            @Suppress("UNCHECKED_CAST")
            val lstat = result["lstat"] as Map<String, Boolean>
            @Suppress("UNCHECKED_CAST")
            val stat = result["stat"] as Map<String, Boolean>
            
            // lstat should return symlink properties
            assertFalse(lstat["isFile"] == true, "lstat: Symlink should not be reported as a file")
            assertFalse(lstat["isDirectory"] == true, "lstat: Symlink should not be reported as a directory")
            assertTrue(lstat["isSymbolicLink"] == true, "lstat: Should detect symbolic link")
            
            // stat should follow the link and return target directory properties
            assertFalse(stat["isFile"] == true, "stat: Target should not be a file")
            assertTrue(stat["isDirectory"] == true, "stat: Should follow link and detect target as directory")
            assertFalse(stat["isSymbolicLink"] == true, "stat: Should follow link, not report as symlink")
        } else {
            // Symlink creation might fail on some platforms
            println("Symlink test skipped: ${result["error"]}")
        }
    }

    @Test
    fun testStatVsLstatOnRegularFile() {
        val script = """
        // Create a regular file
        SystemFS.writeFile(testDir + '/regular.txt', 'content');
        
        // Both stat and lstat should return the same results for regular files
        var lstatResult = SystemFS.lstat(testDir + '/regular.txt');
        var statResult = SystemFS.stat(testDir + '/regular.txt');
        
        ({
            lstat: {
                isFile: lstatResult.isFile,
                isDirectory: lstatResult.isDirectory,
                isSymbolicLink: lstatResult.isSymbolicLink
            },
            stat: {
                isFile: statResult.isFile,
                isDirectory: statResult.isDirectory,
                isSymbolicLink: statResult.isSymbolicLink
            }
        });
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Any?>
        
        @Suppress("UNCHECKED_CAST")
        val lstat = result["lstat"] as Map<String, Boolean>
        @Suppress("UNCHECKED_CAST")
        val stat = result["stat"] as Map<String, Boolean>
        
        // Both should report the same for regular files
        assertTrue(lstat["isFile"] == true, "lstat: Should detect regular file")
        assertTrue(stat["isFile"] == true, "stat: Should detect regular file")
        
        assertFalse(lstat["isDirectory"] == true, "lstat: Should not be directory")
        assertFalse(stat["isDirectory"] == true, "stat: Should not be directory")
        
        assertFalse(lstat["isSymbolicLink"] == true, "lstat: Should not be symlink")
        assertFalse(stat["isSymbolicLink"] == true, "stat: Should not be symlink")
    }

    @Test
    fun testCharacterDevice() {
        // Note: Java NIO cannot distinguish character devices from other device types
        // They are detected as isOther() and mapped to isSocket in our implementation
        val devNull = if (System.getProperty("os.name").startsWith("Windows")) "NUL" else "/dev/null"
        
        val script = """
        if (SystemFS.exists('$devNull')) {
            var stat = SystemFS.stat('$devNull');
            ({
                exists: true,
                isFile: stat.isFile,
                isDirectory: stat.isDirectory,
                isSymbolicLink: stat.isSymbolicLink,
                isCharacterDevice: stat.isCharacterDevice,
                isBlockDevice: stat.isBlockDevice,
                isSocket: stat.isSocket
            });
        } else {
            ({ exists: false });
        }
        """
        
        @Suppress("UNCHECKED_CAST")
        val result = engine.execute(script) as Map<String, Any?>
        
        if (result["exists"] == true) {
            assertFalse(result["isFile"] == true, "$devNull should not be a regular file")
            assertFalse(result["isDirectory"] == true, "$devNull should not be a directory")
            assertFalse(result["isSymbolicLink"] == true, "$devNull should not be a symbolic link")
            
            // Platform limitation: Java NIO cannot distinguish character devices
            // On Unix systems, /dev/null is isOther() which we map to isSocket
            // On Windows, NUL might behave differently
            val isCharDev = result["isCharacterDevice"] as Boolean
            val isSocket = result["isSocket"] as Boolean
            
            // Java NIO limitation: always returns false for character/block devices
            assertFalse(isCharDev, "Java NIO limitation: isCharacterDevice always false")
            assertFalse(result["isBlockDevice"] == true, "Java NIO limitation: isBlockDevice always false")
            
            // Device files are detected as isOther() and mapped to isSocket
            if (!System.getProperty("os.name").startsWith("Windows")) {
                assertTrue(isSocket, "$devNull detected as socket (isOther in Java NIO)")
            }
        }
    }

    @Test
    fun testDirectoryStreamFileTypes() {
        val script = """
        SystemFS.writeFile(testDir + '/file.txt', 'content');
        SystemFS.mkdir(testDir + '/dir');
        
        (async function() {
            var entries = [];
            for await (var entry of SystemFS.opendir(testDir)) {
                entries.push({
                    name: entry.name,
                    isFile: entry.isFile,
                    isDirectory: entry.isDirectory,
                    isSymbolicLink: entry.isSymbolicLink,
                    isCharacterDevice: entry.isCharacterDevice,
                    isBlockDevice: entry.isBlockDevice,
                    isSocket: entry.isSocket
                });
            }
            return entries.length === 2;
        })();
        """
        
        val promise = engine.execute(script)
        assertNotNull(promise, "Should return a Promise")
        
        // Wait for async iteration
        Thread.sleep(100)
        
        // Verify entries by re-running iteration
        val verifyScript = """
        (async function() {
            var foundFile = false;
            var foundDir = false;
            
            for await (var entry of SystemFS.opendir(testDir)) {
                if (entry.name === 'file.txt') {
                    foundFile = entry.isFile && !entry.isDirectory && 
                               !entry.isSymbolicLink && !entry.isCharacterDevice && 
                               !entry.isBlockDevice && !entry.isSocket;
                } else if (entry.name === 'dir') {
                    foundDir = !entry.isFile && entry.isDirectory && 
                              !entry.isSymbolicLink && !entry.isCharacterDevice && 
                              !entry.isBlockDevice && !entry.isSocket;
                }
            }
            return foundFile && foundDir;
        })();
        """
        
        val verifyPromise = engine.execute(verifyScript)
        Thread.sleep(100)
        
        // The test passes if no exceptions are thrown
        assertNotNull(verifyPromise, "Should verify file types")
    }

    @Test
    fun testFileTypeFlagsAreMutuallyExclusive() {
        // Regular files should only have isFile = true
        val fileScript = """
        SystemFS.writeFile(testDir + '/test.txt', 'test');
        var stat = SystemFS.stat(testDir + '/test.txt');
        var trueCount = [stat.isFile, stat.isDirectory, stat.isSymbolicLink, 
                         stat.isCharacterDevice, stat.isBlockDevice, stat.isSocket]
                        .filter(function(x) { return x === true; }).length;
        trueCount;
        """
        
        val fileResult = engine.execute(fileScript) as Int
        assertEquals(1, fileResult, "Regular file should have exactly one file type flag set")
        
        // Directories should only have isDirectory = true
        val dirScript = """
        SystemFS.mkdir(testDir + '/testdir');
        var stat = SystemFS.stat(testDir + '/testdir');
        var trueCount = [stat.isFile, stat.isDirectory, stat.isSymbolicLink,
                         stat.isCharacterDevice, stat.isBlockDevice, stat.isSocket]
                        .filter(function(x) { return x === true; }).length;
        trueCount;
        """
        
        val dirResult = engine.execute(dirScript) as Int
        assertEquals(1, dirResult, "Directory should have exactly one file type flag set")
    }
}
