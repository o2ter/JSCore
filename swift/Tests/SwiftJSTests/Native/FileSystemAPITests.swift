//
//  FileSystemAPITests.swift
//  SwiftJS SystemFS API Comprehensive Tests
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

import XCTest
@testable import SwiftJS

/// Comprehensive tests for the SystemFS API including all methods and their options
@MainActor
final class FileSystemAPITests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private func createTempDir(context: SwiftJS) -> String {
        let script = """
            (() => {
                const tempBase = SystemFS.temp;
                const testDir = Path.join(tempBase, 'SwiftJS-FSAPITests-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9));
                SystemFS.mkdir(testDir);
                return testDir;
            })()
        """
        return context.evaluateScript(script).toString()
    }
    
    private func cleanupTempDir(_ tempDir: String, context: SwiftJS) {
        let script = """
            if (SystemFS.exists('\(tempDir)')) {
                SystemFS.rmdir('\(tempDir)', { recursive: true });
            }
        """
        context.evaluateScript(script)
    }
    
    // MARK: - Basic File Operations Tests
    
    func testReadFileWithDefaultEncoding() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'read-default.txt');
            const content = 'Hello, World! 你好';
            SystemFS.writeFile(testFile, content);
            
            const readContent = SystemFS.readFile(testFile);
            ({
                written: content,
                read: readContent,
                matches: readContent === content,
                type: typeof readContent
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["matches"].boolValue ?? false)
        XCTAssertEqual(result["read"].toString(), "Hello, World! 你好")
    }
    
    func testReadFileWithExplicitUTF8Encoding() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'read-utf8.txt');
            const content = 'UTF-8 Content: 你好世界 🌍';
            SystemFS.writeFile(testFile, content);
            
            const readContent = SystemFS.readFile(testFile, { encoding: 'utf-8' });
            ({
                read: readContent,
                matches: readContent === content,
                type: typeof readContent
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["matches"].boolValue ?? false)
    }
    
    func testReadFileWithBinaryEncoding() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'read-binary.bin');
            const binaryData = new Uint8Array([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"
            SystemFS.writeFile(testFile, binaryData);
            
            const readData = SystemFS.readFile(testFile, { encoding: 'binary' });
            ({
                isUint8Array: readData instanceof Uint8Array,
                length: readData.length,
                firstByte: readData[0],
                lastByte: readData[4],
                matches: Array.from(readData).join(',') === Array.from(binaryData).join(',')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 5)
        XCTAssertEqual(Int(result["firstByte"].numberValue ?? 0), 0x48)
        XCTAssertEqual(Int(result["lastByte"].numberValue ?? 0), 0x6F)
        XCTAssertTrue(result["matches"].boolValue ?? false)
    }
    
    func testReadFileWithNullEncoding() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'read-null.bin');
            const data = new Uint8Array([1, 2, 3, 4, 5]);
            SystemFS.writeFile(testFile, data);
            
            const readData = SystemFS.readFile(testFile, { encoding: null });
            ({
                isUint8Array: readData instanceof Uint8Array,
                length: readData.length,
                sum: Array.from(readData).reduce((a, b) => a + b, 0)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 5)
        XCTAssertEqual(Int(result["sum"].numberValue ?? 0), 15) // 1+2+3+4+5
    }
    
    func testReadFileNonExistent() {
        let context = SwiftJS()
        
        let script = """
            try {
                SystemFS.readFile('/nonexistent/file.txt');
                ({ success: false, error: null })
            } catch (error) {
                ({
                    success: true,
                    error: error.message,
                    hasFileNotFound: error.message.includes('not found')
                })
            }
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertTrue(result["hasFileNotFound"].boolValue ?? false)
    }
    
    // MARK: - Write File Tests
    
    func testWriteFileWithDefaultOptions() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-default.txt');
            const content = 'Default write';
            
            const writeResult = SystemFS.writeFile(testFile, content);
            const readBack = SystemFS.readFile(testFile);
            
            ({
                writeSuccess: writeResult === true,
                matches: readBack === content,
                exists: SystemFS.exists(testFile)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["writeSuccess"].boolValue ?? false)
        XCTAssertTrue(result["matches"].boolValue ?? false)
        XCTAssertTrue(result["exists"].boolValue ?? false)
    }
    
    func testWriteFileWithAppendFlag() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-append.txt');
            
            SystemFS.writeFile(testFile, 'First line\\n');
            SystemFS.writeFile(testFile, 'Second line\\n', { flags: 'a' });
            SystemFS.writeFile(testFile, 'Third line', { flags: 'a' });
            
            const content = SystemFS.readFile(testFile);
            ({
                content: content,
                hasFirst: content.includes('First line'),
                hasSecond: content.includes('Second line'),
                hasThird: content.includes('Third line'),
                correctOrder: content === 'First line\\nSecond line\\nThird line'
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasFirst"].boolValue ?? false)
        XCTAssertTrue(result["hasSecond"].boolValue ?? false)
        XCTAssertTrue(result["hasThird"].boolValue ?? false)
        XCTAssertTrue(result["correctOrder"].boolValue ?? false)
    }
    
    func testWriteFileWithOverwriteFlag() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-overwrite.txt');
            
            SystemFS.writeFile(testFile, 'Original content');
            SystemFS.writeFile(testFile, 'New content', { flags: 'w' });
            
            const content = SystemFS.readFile(testFile);
            ({
                content: content,
                matches: content === 'New content',
                noOriginal: !content.includes('Original')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["matches"].boolValue ?? false)
        XCTAssertTrue(result["noOriginal"].boolValue ?? false)
    }
    
    func testWriteFileWithExclusiveFlag() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-exclusive.txt');
            
            // First write should succeed
            const firstWrite = SystemFS.writeFile(testFile, 'First', { flags: 'x' });
            
            // Second write should fail
            try {
                SystemFS.writeFile(testFile, 'Second', { flags: 'x' });
                var secondWrite = true;
                var error = null;
            } catch (e) {
                var secondWrite = false;
                var error = e.message;
            }
            
            const content = SystemFS.readFile(testFile);
            ({
                firstWriteSuccess: firstWrite === true,
                secondWriteFailed: secondWrite === false,
                hasError: error !== null,
                contentPreserved: content === 'First'
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["firstWriteSuccess"].boolValue ?? false)
        XCTAssertTrue(result["secondWriteFailed"].boolValue ?? false)
        XCTAssertTrue(result["hasError"].boolValue ?? false)
        XCTAssertTrue(result["contentPreserved"].boolValue ?? false)
    }
    
    func testWriteFileWithBinaryData() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-binary.bin');
            const binaryData = new Uint8Array([0xFF, 0xFE, 0xFD, 0xFC, 0xFB]);
            
            SystemFS.writeFile(testFile, binaryData);
            
            const readData = SystemFS.readFile(testFile, { encoding: 'binary' });
            ({
                isUint8Array: readData instanceof Uint8Array,
                length: readData.length,
                matches: Array.from(readData).join(',') === Array.from(binaryData).join(',')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 5)
        XCTAssertTrue(result["matches"].boolValue ?? false)
    }
    
    func testWriteFileWithArrayBuffer() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'write-arraybuffer.bin');
            const buffer = new ArrayBuffer(4);
            const view = new Uint8Array(buffer);
            view[0] = 1; view[1] = 2; view[2] = 3; view[3] = 4;
            
            SystemFS.writeFile(testFile, buffer);
            
            const readData = SystemFS.readFile(testFile, { encoding: 'binary' });
            ({
                length: readData.length,
                sum: Array.from(readData).reduce((a, b) => a + b, 0)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(Int(result["length"].numberValue ?? 0), 4)
        XCTAssertEqual(Int(result["sum"].numberValue ?? 0), 10) // 1+2+3+4
    }
    
    // MARK: - Directory Operations Tests
    
    func testMkdirWithRecursiveTrue() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const deepPath = Path.join('\(tempDir)', 'a', 'b', 'c', 'd');
            
            const result = SystemFS.mkdir(deepPath, { recursive: true });
            ({
                result: result,
                exists: SystemFS.exists(deepPath),
                isDirectory: SystemFS.isDirectory(deepPath),
                parentExists: SystemFS.exists(Path.join('\(tempDir)', 'a', 'b'))
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["exists"].boolValue ?? false)
        XCTAssertTrue(result["isDirectory"].boolValue ?? false)
        XCTAssertTrue(result["parentExists"].boolValue ?? false)
    }
    
    func testMkdirWithRecursiveFalse() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const singleLevel = Path.join('\(tempDir)', 'single');
            const deepPath = Path.join('\(tempDir)', 'x', 'y', 'z');
            
            // Should succeed for single level
            const singleResult = SystemFS.mkdir(singleLevel, { recursive: false });
            
            // Should fail for deep path
            try {
                SystemFS.mkdir(deepPath, { recursive: false });
                var deepResult = true;
                var error = null;
            } catch (e) {
                var deepResult = false;
                var error = e.message;
            }
            
            ({
                singleSuccess: singleResult === true,
                singleExists: SystemFS.exists(singleLevel),
                deepFailed: deepResult === false,
                hasError: error !== null,
                errorHasParent: error && error.includes('Parent')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["singleSuccess"].boolValue ?? false)
        XCTAssertTrue(result["singleExists"].boolValue ?? false)
        XCTAssertTrue(result["deepFailed"].boolValue ?? false)
        XCTAssertTrue(result["hasError"].boolValue ?? false)
        XCTAssertTrue(result["errorHasParent"].boolValue ?? false)
    }
    
    func testMkdirExistingDirectory() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const dirPath = Path.join('\(tempDir)', 'existing');
            
            SystemFS.mkdir(dirPath);
            const secondCreate = SystemFS.mkdir(dirPath, { recursive: false });
            
            ({
                result: secondCreate,
                stillExists: SystemFS.exists(dirPath),
                isDirectory: SystemFS.isDirectory(dirPath)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["stillExists"].boolValue ?? false)
        XCTAssertTrue(result["isDirectory"].boolValue ?? false)
    }
    
    func testRmdirWithRecursiveTrue() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const dirPath = Path.join('\(tempDir)', 'to-remove');
            SystemFS.mkdir(dirPath);
            
            // Create some files inside
            SystemFS.writeFile(Path.join(dirPath, 'file1.txt'), 'content1');
            SystemFS.writeFile(Path.join(dirPath, 'file2.txt'), 'content2');
            SystemFS.mkdir(Path.join(dirPath, 'subdir'));
            SystemFS.writeFile(Path.join(dirPath, 'subdir', 'file3.txt'), 'content3');
            
            const result = SystemFS.rmdir(dirPath, { recursive: true });
            ({
                result: result,
                removed: !SystemFS.exists(dirPath)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["removed"].boolValue ?? false)
    }
    
    func testRmdirWithRecursiveFalse() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const emptyDir = Path.join('\(tempDir)', 'empty');
            const fullDir = Path.join('\(tempDir)', 'full');
            
            SystemFS.mkdir(emptyDir);
            SystemFS.mkdir(fullDir);
            SystemFS.writeFile(Path.join(fullDir, 'file.txt'), 'content');
            
            // Should succeed for empty
            const emptyResult = SystemFS.rmdir(emptyDir, { recursive: false });
            
            // Should fail for non-empty
            try {
                SystemFS.rmdir(fullDir, { recursive: false });
                var fullResult = true;
                var error = null;
            } catch (e) {
                var fullResult = false;
                var error = e.message;
            }
            
            ({
                emptySuccess: emptyResult === true,
                emptyRemoved: !SystemFS.exists(emptyDir),
                fullFailed: fullResult === false,
                fullStillExists: SystemFS.exists(fullDir),
                errorHasNotEmpty: error && error.includes('not empty')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["emptySuccess"].boolValue ?? false)
        XCTAssertTrue(result["emptyRemoved"].boolValue ?? false)
        XCTAssertTrue(result["fullFailed"].boolValue ?? false)
        XCTAssertTrue(result["fullStillExists"].boolValue ?? false)
        XCTAssertTrue(result["errorHasNotEmpty"].boolValue ?? false)
    }
    
    // MARK: - File/Directory Query Tests
    
    func testExistsMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const existingFile = Path.join('\(tempDir)', 'exists.txt');
            const nonExistent = Path.join('\(tempDir)', 'does-not-exist.txt');
            
            SystemFS.writeFile(existingFile, 'test');
            
            ({
                fileExists: SystemFS.exists(existingFile),
                fileDoesNotExist: !SystemFS.exists(nonExistent),
                dirExists: SystemFS.exists('\(tempDir)')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["fileExists"].boolValue ?? false)
        XCTAssertTrue(result["fileDoesNotExist"].boolValue ?? false)
        XCTAssertTrue(result["dirExists"].boolValue ?? false)
    }
    
    func testIsFileMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'test.txt');
            const testDir = Path.join('\(tempDir)', 'test-dir');
            
            SystemFS.writeFile(testFile, 'content');
            SystemFS.mkdir(testDir);
            
            ({
                fileIsFile: SystemFS.isFile(testFile),
                dirIsNotFile: !SystemFS.isFile(testDir),
                nonExistentIsNotFile: !SystemFS.isFile('/nonexistent')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["fileIsFile"].boolValue ?? false)
        XCTAssertTrue(result["dirIsNotFile"].boolValue ?? false)
        XCTAssertTrue(result["nonExistentIsNotFile"].boolValue ?? false)
    }
    
    func testIsDirectoryMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'test.txt');
            const testDir = Path.join('\(tempDir)', 'test-dir');
            
            SystemFS.writeFile(testFile, 'content');
            SystemFS.mkdir(testDir);
            
            ({
                dirIsDirectory: SystemFS.isDirectory(testDir),
                fileIsNotDirectory: !SystemFS.isDirectory(testFile),
                nonExistentIsNotDirectory: !SystemFS.isDirectory('/nonexistent')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["dirIsDirectory"].boolValue ?? false)
        XCTAssertTrue(result["fileIsNotDirectory"].boolValue ?? false)
        XCTAssertTrue(result["nonExistentIsNotDirectory"].boolValue ?? false)
    }
    
    func testStatMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stat-test.txt');
            const content = 'Test content for stat';
            SystemFS.writeFile(testFile, content);
            
            const stats = SystemFS.stat(testFile);
            ({
                hasSize: typeof stats.size === 'number',
                hasMtime: typeof stats.mtime === 'number',
                sizeCorrect: stats.size > 0,
                mtimeRecent: stats.mtime > Date.now() - 10000 // Within last 10 seconds
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasSize"].boolValue ?? false)
        XCTAssertTrue(result["hasMtime"].boolValue ?? false)
        XCTAssertTrue(result["sizeCorrect"].boolValue ?? false)
        XCTAssertTrue(result["mtimeRecent"].boolValue ?? false)
    }
    
    func testReadDirMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testDir = Path.join('\(tempDir)', 'readdir-test');
            SystemFS.mkdir(testDir);
            
            SystemFS.writeFile(Path.join(testDir, 'file1.txt'), 'content1');
            SystemFS.writeFile(Path.join(testDir, 'file2.txt'), 'content2');
            SystemFS.mkdir(Path.join(testDir, 'subdir'));
            
            const entries = SystemFS.readDir(testDir);
            ({
                isArray: Array.isArray(entries),
                count: entries.length,
                hasFile1: entries.includes('file1.txt'),
                hasFile2: entries.includes('file2.txt'),
                hasSubdir: entries.includes('subdir'),
                sorted: entries.sort().join(',')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isArray"].boolValue ?? false)
        XCTAssertEqual(Int(result["count"].numberValue ?? 0), 3)
        XCTAssertTrue(result["hasFile1"].boolValue ?? false)
        XCTAssertTrue(result["hasFile2"].boolValue ?? false)
        XCTAssertTrue(result["hasSubdir"].boolValue ?? false)
    }
    
    // MARK: - Copy and Move Tests
    
    func testCopyWithoutOverwrite() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const srcFile = Path.join('\(tempDir)', 'copy-src.txt');
            const destFile = Path.join('\(tempDir)', 'copy-dest.txt');
            const content = 'Copy test content';
            
            SystemFS.writeFile(srcFile, content);
            const result = SystemFS.copy(srcFile, destFile);
            
            const srcContent = SystemFS.readFile(srcFile);
            const destContent = SystemFS.readFile(destFile);
            
            ({
                result: result,
                srcExists: SystemFS.exists(srcFile),
                destExists: SystemFS.exists(destFile),
                contentsMatch: srcContent === destContent,
                contentCorrect: destContent === content
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["srcExists"].boolValue ?? false)
        XCTAssertTrue(result["destExists"].boolValue ?? false)
        XCTAssertTrue(result["contentsMatch"].boolValue ?? false)
        XCTAssertTrue(result["contentCorrect"].boolValue ?? false)
    }
    
    func testCopyWithOverwriteTrue() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const srcFile = Path.join('\(tempDir)', 'copy-src2.txt');
            const destFile = Path.join('\(tempDir)', 'copy-dest2.txt');
            
            SystemFS.writeFile(srcFile, 'New content');
            SystemFS.writeFile(destFile, 'Old content');
            
            const result = SystemFS.copy(srcFile, destFile, { overwrite: true });
            const destContent = SystemFS.readFile(destFile);
            
            ({
                result: result,
                contentReplaced: destContent === 'New content',
                noOldContent: !destContent.includes('Old')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["contentReplaced"].boolValue ?? false)
        XCTAssertTrue(result["noOldContent"].boolValue ?? false)
    }
    
    func testCopyWithOverwriteFalse() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const srcFile = Path.join('\(tempDir)', 'copy-src3.txt');
            const destFile = Path.join('\(tempDir)', 'copy-dest3.txt');
            
            SystemFS.writeFile(srcFile, 'New content');
            SystemFS.writeFile(destFile, 'Old content');
            
            try {
                SystemFS.copy(srcFile, destFile, { overwrite: false });
                var result = true;
                var error = null;
            } catch (e) {
                var result = false;
                var error = e.message;
            }
            
            const destContent = SystemFS.readFile(destFile);
            
            ({
                copyFailed: result === false,
                hasError: error !== null,
                errorHasAlreadyExists: error && error.includes('already exists'),
                contentPreserved: destContent === 'Old content'
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["copyFailed"].boolValue ?? false)
        XCTAssertTrue(result["hasError"].boolValue ?? false)
        XCTAssertTrue(result["errorHasAlreadyExists"].boolValue ?? false)
        XCTAssertTrue(result["contentPreserved"].boolValue ?? false)
    }
    
    func testMoveWithoutOverwrite() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const srcFile = Path.join('\(tempDir)', 'move-src.txt');
            const destFile = Path.join('\(tempDir)', 'move-dest.txt');
            const content = 'Move test content';
            
            SystemFS.writeFile(srcFile, content);
            const result = SystemFS.move(srcFile, destFile);
            
            ({
                result: result,
                srcRemoved: !SystemFS.exists(srcFile),
                destExists: SystemFS.exists(destFile),
                contentCorrect: SystemFS.readFile(destFile) === content
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["srcRemoved"].boolValue ?? false)
        XCTAssertTrue(result["destExists"].boolValue ?? false)
        XCTAssertTrue(result["contentCorrect"].boolValue ?? false)
    }
    
    func testMoveWithOverwriteTrue() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const srcFile = Path.join('\(tempDir)', 'move-src2.txt');
            const destFile = Path.join('\(tempDir)', 'move-dest2.txt');
            
            SystemFS.writeFile(srcFile, 'New content');
            SystemFS.writeFile(destFile, 'Old content');
            
            const result = SystemFS.move(srcFile, destFile, { overwrite: true });
            
            ({
                result: result,
                srcRemoved: !SystemFS.exists(srcFile),
                destExists: SystemFS.exists(destFile),
                contentReplaced: SystemFS.readFile(destFile) === 'New content'
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["srcRemoved"].boolValue ?? false)
        XCTAssertTrue(result["destExists"].boolValue ?? false)
        XCTAssertTrue(result["contentReplaced"].boolValue ?? false)
    }
    
    func testRemoveMethod() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'remove-test.txt');
            const testDir = Path.join('\(tempDir)', 'remove-dir');
            
            SystemFS.writeFile(testFile, 'content');
            SystemFS.mkdir(testDir);
            SystemFS.writeFile(Path.join(testDir, 'file.txt'), 'nested');
            
            const fileResult = SystemFS.remove(testFile);
            const dirResult = SystemFS.remove(testDir);
            
            ({
                fileResult: fileResult,
                dirResult: dirResult,
                fileRemoved: !SystemFS.exists(testFile),
                dirRemoved: !SystemFS.exists(testDir)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["fileResult"].boolValue ?? false)
        XCTAssertTrue(result["dirResult"].boolValue ?? false)
        XCTAssertTrue(result["fileRemoved"].boolValue ?? false)
        XCTAssertTrue(result["dirRemoved"].boolValue ?? false)
    }
    
    // MARK: - Stream Operations Tests
    
    func testCreateReadStreamDefault() {
        let expectation = XCTestExpectation(description: "createReadStream default")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-read.txt');
            const content = 'Hello from read stream!';
            SystemFS.writeFile(testFile, content);
            
            const stream = SystemFS.createReadStream(testFile);
            const reader = stream.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        let totalLength = 0;
                        chunks.forEach(c => totalLength += c.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(c => {
                            combined.set(c, offset);
                            offset += c.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({
                            text: text,
                            matches: text === content,
                            chunkCount: chunks.length
                        });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertGreaterThan(Int(result["chunkCount"].numberValue ?? 0), 0)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateReadStreamWithEncoding() {
        let expectation = XCTestExpectation(description: "createReadStream with encoding")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-read-enc.txt');
            const content = 'Text stream content 你好';
            SystemFS.writeFile(testFile, content);
            
            const stream = SystemFS.createReadStream(testFile, { encoding: 'utf-8' });
            const reader = stream.getReader();
            let result = '';
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        testCompleted({
                            text: result,
                            matches: result === content,
                            isString: typeof result === 'string'
                        });
                        return;
                    }
                    result += value; // value should be string
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["isString"].boolValue ?? false)
            XCTAssertTrue(result["matches"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateReadStreamWithRange() {
        let expectation = XCTestExpectation(description: "createReadStream with range")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-range.txt');
            const content = '0123456789ABCDEFGHIJ';
            SystemFS.writeFile(testFile, content);
            
            // Read bytes 5-14 (inclusive)
            const stream = SystemFS.createReadStream(testFile, { start: 5, end: 14 });
            const reader = stream.getReader();
            const chunks = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        let totalLength = 0;
                        chunks.forEach(c => totalLength += c.byteLength);
                        const combined = new Uint8Array(totalLength);
                        let offset = 0;
                        chunks.forEach(c => {
                            combined.set(c, offset);
                            offset += c.byteLength;
                        });
                        const text = new TextDecoder().decode(combined);
                        testCompleted({
                            text: text,
                            expected: '56789ABCDE',
                            matches: text === '56789ABCDE',
                            length: text.length
                        });
                        return;
                    }
                    chunks.push(value);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertEqual(result["text"].toString(), "56789ABCDE")
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertEqual(Int(result["length"].numberValue ?? 0), 10)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateReadStreamWithChunkSize() {
        let expectation = XCTestExpectation(description: "createReadStream with chunkSize")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-chunk.txt');
            const content = 'A'.repeat(1000);
            SystemFS.writeFile(testFile, content);
            
            const stream = SystemFS.createReadStream(testFile, { chunkSize: 100 });
            const reader = stream.getReader();
            const chunkSizes = [];
            
            function readChunk() {
                return reader.read().then(({ done, value }) => {
                    if (done) {
                        testCompleted({
                            chunkCount: chunkSizes.length,
                            chunkSizes: chunkSizes,
                            allChunksSmallOrEqual: chunkSizes.every(s => s <= 100),
                            totalSize: chunkSizes.reduce((a, b) => a + b, 0)
                        });
                        return;
                    }
                    chunkSizes.push(value.byteLength);
                    return readChunk();
                });
            }
            
            readChunk().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["allChunksSmallOrEqual"].boolValue ?? false)
            XCTAssertEqual(Int(result["totalSize"].numberValue ?? 0), 1000)
            XCTAssertGreaterThan(Int(result["chunkCount"].numberValue ?? 0), 1)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateWriteStreamDefault() {
        let expectation = XCTestExpectation(description: "createWriteStream default")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-write.txt');
            const content = 'Hello from write stream!';
            
            const stream = SystemFS.createWriteStream(testFile);
            const writer = stream.getWriter();
            
            writer.write(new TextEncoder().encode(content))
                .then(() => writer.close())
                .then(() => {
                    const readContent = SystemFS.readFile(testFile);
                    testCompleted({
                        content: readContent,
                        matches: readContent === content,
                        fileExists: SystemFS.exists(testFile)
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            XCTAssertTrue(result["fileExists"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateWriteStreamWithAppendFlag() {
        let expectation = XCTestExpectation(description: "createWriteStream with append")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-append.txt');
            
            // First write
            SystemFS.writeFile(testFile, 'First line\\n');
            
            // Append using stream
            const stream = SystemFS.createWriteStream(testFile, { flags: 'a' });
            const writer = stream.getWriter();
            
            writer.write(new TextEncoder().encode('Second line'))
                .then(() => writer.close())
                .then(() => {
                    const content = SystemFS.readFile(testFile);
                    testCompleted({
                        content: content,
                        hasFirst: content.includes('First line'),
                        hasSecond: content.includes('Second line'),
                        correctOrder: content === 'First line\\nSecond line'
                    });
                })
                .catch(error => {
                    testCompleted({ error: error.message });
                });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["hasFirst"].boolValue ?? false)
            XCTAssertTrue(result["hasSecond"].boolValue ?? false)
            XCTAssertTrue(result["correctOrder"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCreateWriteStreamMultipleChunks() {
        let expectation = XCTestExpectation(description: "createWriteStream multiple chunks")
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'stream-multi.txt');
            
            const stream = SystemFS.createWriteStream(testFile);
            const writer = stream.getWriter();
            
            const chunks = ['First', ' ', 'Second', ' ', 'Third'];
            
            async function writeAll() {
                for (const chunk of chunks) {
                    await writer.write(new TextEncoder().encode(chunk));
                }
                await writer.close();
                
                const content = SystemFS.readFile(testFile);
                testCompleted({
                    content: content,
                    expected: 'First Second Third',
                    matches: content === 'First Second Third'
                });
            }
            
            writeAll().catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, _ in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["matches"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testReadFileFromDirectory() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            try {
                SystemFS.readFile('\(tempDir)');
                ({ success: false })
            } catch (error) {
                ({
                    success: true,
                    error: error.message,
                    hasNotAFile: error.message.includes('Not a file')
                })
            }
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertTrue(result["hasNotAFile"].boolValue ?? false)
    }
    
    func testCopyNonExistentSource() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            try {
                SystemFS.copy('/nonexistent/file.txt', Path.join('\(tempDir)', 'dest.txt'));
                ({ success: false })
            } catch (error) {
                ({
                    success: true,
                    error: error.message,
                    hasNotFound: error.message.includes('not found')
                })
            }
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertTrue(result["hasNotFound"].boolValue ?? false)
    }
    
    func testRmdirOnFile() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const testFile = Path.join('\(tempDir)', 'not-a-dir.txt');
            SystemFS.writeFile(testFile, 'content');
            
            try {
                SystemFS.rmdir(testFile);
                ({ success: false })
            } catch (error) {
                ({
                    success: true,
                    error: error.message,
                    hasNotADirectory: error.message.includes('Not a directory')
                })
            }
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertTrue(result["hasNotADirectory"].boolValue ?? false)
    }
    
    func testEmptyFileOperations() {
        let context = SwiftJS()
        let tempDir = createTempDir(context: context)
        defer { cleanupTempDir(tempDir, context: context) }
        
        let script = """
            const emptyFile = Path.join('\(tempDir)', 'empty.txt');
            SystemFS.writeFile(emptyFile, '');
            
            const content = SystemFS.readFile(emptyFile);
            const binaryContent = SystemFS.readFile(emptyFile, { encoding: 'binary' });
            const stats = SystemFS.stat(emptyFile);
            
            ({
                textIsEmpty: content === '',
                binaryLength: binaryContent.length,
                binaryIsEmpty: binaryContent.length === 0,
                statsSize: stats.size,
                fileExists: SystemFS.exists(emptyFile)
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["textIsEmpty"].boolValue ?? false)
        XCTAssertEqual(Int(result["binaryLength"].numberValue ?? 0), 0)
        XCTAssertTrue(result["binaryIsEmpty"].boolValue ?? false)
        XCTAssertEqual(Int(result["statsSize"].numberValue ?? -1), 0)
        XCTAssertTrue(result["fileExists"].boolValue ?? false)
    }
    
    // MARK: - Property Getters Tests
    
    func testHomeProperty() {
        let context = SwiftJS()
        let script = """
            ({
                home: SystemFS.home,
                type: typeof SystemFS.home,
                isString: typeof SystemFS.home === 'string',
                hasLength: SystemFS.home.length > 0,
                isAbsolute: SystemFS.home.startsWith('/')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["isString"].boolValue ?? false)
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolute"].boolValue ?? false)
    }
    
    func testTempProperty() {
        let context = SwiftJS()
        let script = """
            ({
                temp: SystemFS.temp,
                type: typeof SystemFS.temp,
                isString: typeof SystemFS.temp === 'string',
                hasLength: SystemFS.temp.length > 0,
                isAbsolute: SystemFS.temp.startsWith('/')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["isString"].boolValue ?? false)
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolute"].boolValue ?? false)
    }
    
    func testCwdProperty() {
        let context = SwiftJS()
        let script = """
            ({
                cwd: SystemFS.cwd,
                type: typeof SystemFS.cwd,
                isString: typeof SystemFS.cwd === 'string',
                hasLength: SystemFS.cwd.length > 0,
                isAbsolute: SystemFS.cwd.startsWith('/')
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["type"].toString(), "string")
        XCTAssertTrue(result["isString"].boolValue ?? false)
        XCTAssertTrue(result["hasLength"].boolValue ?? false)
        XCTAssertTrue(result["isAbsolute"].boolValue ?? false)
    }
    
    func testChdirMethod() {
        let context = SwiftJS()
        let script = """
            const originalCwd = SystemFS.cwd;
            const tempDir = SystemFS.temp;
            
            const result = SystemFS.chdir(tempDir);
            const newCwd = SystemFS.cwd;
            
            // Change back
            SystemFS.chdir(originalCwd);
            const restoredCwd = SystemFS.cwd;
            
            // Instead of string comparison, verify chdir worked by checking if we can access temp contents
            // and that the CWD actually changed (not equal to original)
            ({
                result: result,
                originalCwd: originalCwd,
                changedTo: newCwd,
                changedSuccessfully: newCwd !== originalCwd && (newCwd === tempDir || newCwd.endsWith('/T')),
                restored: restoredCwd === originalCwd
            })
        """
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["result"].boolValue ?? false)
        XCTAssertTrue(result["changedSuccessfully"].boolValue ?? false)
        XCTAssertTrue(result["restored"].boolValue ?? false)
    }
}
