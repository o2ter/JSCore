//
//  DirectoryIterationTests.swift
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

final class DirectoryIterationTests: XCTestCase {
    var context: SwiftJS!
    var testDir: String!
    
    override func setUp() {
        super.setUp()
        context = SwiftJS()
        
        // Create a test directory structure
        testDir = NSTemporaryDirectory() + "DirectoryIterationTests_\(UUID().uuidString)"
        
        let script = """
        var testDir = '\(testDir!)';
        SystemFS.mkdir(testDir);
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
        
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false, "Failed to create test directory structure")
    }
    
    override func tearDown() {
        // Clean up test directory
        if let testDir = testDir {
            let script = "SystemFS.remove('\(testDir)');"
            context.evaluateScript(script)
        }
        context = nil
        super.tearDown()
    }
    
    func testBasicIteration() {
        let script = """
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
        
        let expectation = XCTestExpectation(description: "Basic iteration")
        
        let promise = context.evaluateScript(script)
        XCTAssertTrue(promise.hasProperty("then"), "Should return a Promise")
        
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let entries = args[0]
            XCTAssertTrue(entries.isArray, "Should return an array")
            
            let count = entries["length"].numberValue ?? 0
            XCTAssertEqual(count, 5, "Should have 5 entries (2 subdirs + 3 files)")
            
            // Verify we have the expected entries
            let names = (0..<Int(count)).map { i in
                entries[i]["name"].toString()
            }.sorted()
            
            XCTAssertTrue(names.contains("subdir1"), "Should contain subdir1")
            XCTAssertTrue(names.contains("subdir2"), "Should contain subdir2")
            XCTAssertTrue(names.contains("file1.txt"), "Should contain file1.txt")
            XCTAssertTrue(names.contains("file2.js"), "Should contain file2.js")
            XCTAssertTrue(names.contains("file3.md"), "Should contain file3.md")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFilteredIteration() {
        let script = """
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
        
        let expectation = XCTestExpectation(description: "Filtered iteration")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let jsFiles = args[0]
            XCTAssertTrue(jsFiles.isArray, "Should return an array")
            
            let count = jsFiles["length"].numberValue ?? 0
            XCTAssertEqual(count, 1, "Should have 1 .js file")
            
            let fileName = jsFiles[0].toString()
            XCTAssertEqual(fileName, "file2.js", "Should be file2.js")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRecursiveIteration() {
        let script = """
        (async function() {
            var allFiles = [];
            for await (var entry of SystemFS.opendir(testDir, { recursive: true })) {
                if (entry.isFile) {
                    allFiles.push(entry.path);
                }
            }
            return allFiles.sort();
        })();
        """
        
        let expectation = XCTestExpectation(description: "Recursive iteration")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let allFiles = args[0]
            XCTAssertTrue(allFiles.isArray, "Should return an array")
            
            let count = allFiles["length"].numberValue ?? 0
            XCTAssertEqual(count, 5, "Should find all 5 files recursively")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testEntryMetadata() {
        let script = """
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
        
        let expectation = XCTestExpectation(description: "Entry metadata")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let entry = args[0]
            XCTAssertFalse(entry.isNull, "Should find file1.txt")
            
            XCTAssertEqual(entry["name"].toString(), "file1.txt")
            XCTAssertTrue(entry["isFile"].boolValue ?? false)
            XCTAssertFalse(entry["isDirectory"].boolValue ?? true)
            XCTAssertEqual(entry["size"].numberValue, 8) // "content1" = 8 bytes
            XCTAssertTrue(entry["hasModified"].boolValue ?? false)
            XCTAssertTrue(entry["hasCreated"].boolValue ?? false)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testManualControl() {
        let script = """
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
        
        let expectation = XCTestExpectation(description: "Manual control")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let result = args[0]
            
            XCTAssertFalse(result["firstDone"].boolValue ?? true)
            XCTAssertTrue(result["firstHasValue"].boolValue ?? false)
            XCTAssertFalse(result["secondDone"].boolValue ?? true)
            XCTAssertTrue(result["secondHasValue"].boolValue ?? false)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testEmptyDirectory() {
        let script = """
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
        
        let expectation = XCTestExpectation(description: "Empty directory")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let count = args[0].numberValue ?? -1
            XCTAssertEqual(count, 0, "Empty directory should have 0 entries")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testErrorHandling() {
        let script = """
        (async function() {
            try {
                SystemFS.opendir('/nonexistent/path/12345');
                return 'no_error';
            } catch (e) {
                return e.message;
            }
        })();
        """
        
        let expectation = XCTestExpectation(description: "Error handling")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let errorMsg = args[0].toString()
            XCTAssertTrue(errorMsg.contains("not found") || errorMsg.contains("Directory"), 
                         "Should throw error for non-existent directory")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConvenienceMethods() {
        let script = """
        (async function() {
            for await (var entry of SystemFS.opendir(testDir)) {
                if (entry.name === 'file1.txt') {
                    var content = await entry.read();
                    return content;
                }
            }
            return null;
        })();
        """
        
        let expectation = XCTestExpectation(description: "Convenience methods")
        
        let promise = context.evaluateScript(script)
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let content = args[0].toString()
            XCTAssertEqual(content, "content1", "Should read file content via entry.read()")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
}
