//
//  POSIXFileTypesTests.swift
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

final class POSIXFileTypesTests: XCTestCase {
    var context: SwiftJS!
    var testDir: String!
    
    override func setUp() {
        super.setUp()
        context = SwiftJS()
        testDir = NSTemporaryDirectory() + "POSIXFileTypesTests_\(UUID().uuidString)"
        
        let script = """
        var testDir = '\(testDir!)';
        SystemFS.mkdir(testDir);
        true;
        """
        
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false, "Failed to create test directory")
    }
    
    override func tearDown() {
        if let testDir = testDir {
            let script = "SystemFS.remove('\(testDir)');"
            context.evaluateScript(script)
        }
        context = nil
        super.tearDown()
    }
    
    func testRegularFileType() {
        let script = """
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
        
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isFile"].boolValue ?? false, "Should be a regular file")
        XCTAssertFalse(result["isDirectory"].boolValue ?? true, "Should not be a directory")
        XCTAssertFalse(result["isSymbolicLink"].boolValue ?? true, "Should not be a symbolic link")
        XCTAssertFalse(result["isCharacterDevice"].boolValue ?? true, "Should not be a character device")
        XCTAssertFalse(result["isBlockDevice"].boolValue ?? true, "Should not be a block device")
        XCTAssertFalse(result["isSocket"].boolValue ?? true, "Should not be a socket")
    }
    
    func testDirectoryType() {
        let script = """
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
        
        let result = context.evaluateScript(script)
        
        XCTAssertFalse(result["isFile"].boolValue ?? true, "Should not be a regular file")
        XCTAssertTrue(result["isDirectory"].boolValue ?? false, "Should be a directory")
        XCTAssertFalse(result["isSymbolicLink"].boolValue ?? true, "Should not be a symbolic link")
        XCTAssertFalse(result["isCharacterDevice"].boolValue ?? true, "Should not be a character device")
        XCTAssertFalse(result["isBlockDevice"].boolValue ?? true, "Should not be a block device")
        XCTAssertFalse(result["isSocket"].boolValue ?? true, "Should not be a socket")
    }
    
    func testCharacterDevice() {
        // Test with /dev/null which is a standard character device
        let script = """
        if (SystemFS.exists('/dev/null')) {
            var stat = SystemFS.stat('/dev/null');
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
        
        let result = context.evaluateScript(script)
        
        if result["exists"].boolValue ?? false {
            XCTAssertFalse(result["isFile"].boolValue ?? true, "/dev/null should not be a regular file")
            XCTAssertFalse(result["isDirectory"].boolValue ?? true, "/dev/null should not be a directory")
            XCTAssertFalse(result["isSymbolicLink"].boolValue ?? true, "/dev/null should not be a symbolic link")
            XCTAssertTrue(result["isCharacterDevice"].boolValue ?? false, "/dev/null should be a character device")
            XCTAssertFalse(result["isBlockDevice"].boolValue ?? true, "/dev/null should not be a block device")
            XCTAssertFalse(result["isSocket"].boolValue ?? true, "/dev/null should not be a socket")
        }
    }
    
  func testSymbolicLink() {
    let script = """
      // Create a target file
      SystemFS.writeFile(testDir + '/target.txt', 'content');

      // Create symbolic link
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

    let result = context.evaluateScript(script)

    let success = result["success"].boolValue ?? false
    if success {
      XCTAssertFalse(result["isFile"].boolValue ?? true, "Symlink should not be a regular file")
      XCTAssertFalse(result["isDirectory"].boolValue ?? true, "Symlink should not be a directory")
      XCTAssertTrue(result["isSymbolicLink"].boolValue ?? false, "Should be a symbolic link")
      XCTAssertFalse(
        result["isCharacterDevice"].boolValue ?? true, "Symlink should not be a character device")
      XCTAssertFalse(
        result["isBlockDevice"].boolValue ?? true, "Symlink should not be a block device")
      XCTAssertFalse(result["isSocket"].boolValue ?? true, "Symlink should not be a socket")

      let target = result["target"].toString()
      XCTAssertTrue(target.contains("target.txt"), "readlink should return target path")
    } else {
      let error = result["error"].toString()
      XCTFail("Symlink test failed: \(error)")
    }
  }

    func testStatVsLstatOnSymlinkToFile() {
        let script = """
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

        let result = context.evaluateScript(script)

        let success = result["success"].boolValue ?? false
        if success {
            // lstat should return symlink properties
            XCTAssertFalse(
                result["lstat"]["isFile"].boolValue ?? true,
                "lstat: Symlink should not be reported as a file")
            XCTAssertFalse(
                result["lstat"]["isDirectory"].boolValue ?? true,
                "lstat: Symlink should not be reported as a directory")
            XCTAssertTrue(
                result["lstat"]["isSymbolicLink"].boolValue ?? false,
                "lstat: Should detect symbolic link")

            // stat should follow the link and return target properties
            XCTAssertTrue(
                result["stat"]["isFile"].boolValue ?? false,
                "stat: Should follow link and detect target as file")
            XCTAssertFalse(
                result["stat"]["isDirectory"].boolValue ?? true,
                "stat: Target should not be a directory")
            XCTAssertFalse(
                result["stat"]["isSymbolicLink"].boolValue ?? true,
                "stat: Should follow link, not report as symlink")
        } else {
            let error = result["error"].toString()
            XCTFail("Symlink test failed: \(error)")
        }
    }

    func testStatVsLstatOnSymlinkToDirectory() {
        let script = """
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

        let result = context.evaluateScript(script)

        let success = result["success"].boolValue ?? false
        if success {
            // lstat should return symlink properties
            XCTAssertFalse(
                result["lstat"]["isFile"].boolValue ?? true,
                "lstat: Symlink should not be reported as a file")
            XCTAssertFalse(
                result["lstat"]["isDirectory"].boolValue ?? true,
                "lstat: Symlink should not be reported as a directory")
            XCTAssertTrue(
                result["lstat"]["isSymbolicLink"].boolValue ?? false,
                "lstat: Should detect symbolic link")

            // stat should follow the link and return target directory properties
            XCTAssertFalse(
                result["stat"]["isFile"].boolValue ?? true, "stat: Target should not be a file")
            XCTAssertTrue(
                result["stat"]["isDirectory"].boolValue ?? false,
                "stat: Should follow link and detect target as directory")
            XCTAssertFalse(
                result["stat"]["isSymbolicLink"].boolValue ?? true,
                "stat: Should follow link, not report as symlink")
        } else {
            let error = result["error"].toString()
            XCTFail("Symlink test failed: \(error)")
        }
    }

    func testStatVsLstatOnRegularFile() {
        let script = """
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

        let result = context.evaluateScript(script)

        // Both should report the same for regular files
        XCTAssertTrue(
            result["lstat"]["isFile"].boolValue ?? false, "lstat: Should detect regular file")
        XCTAssertTrue(
            result["stat"]["isFile"].boolValue ?? false, "stat: Should detect regular file")

        XCTAssertFalse(
            result["lstat"]["isDirectory"].boolValue ?? true, "lstat: Should not be directory")
        XCTAssertFalse(
            result["stat"]["isDirectory"].boolValue ?? true, "stat: Should not be directory")

        XCTAssertFalse(
            result["lstat"]["isSymbolicLink"].boolValue ?? true, "lstat: Should not be symlink")
        XCTAssertFalse(
            result["stat"]["isSymbolicLink"].boolValue ?? true, "stat: Should not be symlink")
    }

  func testDirectoryStreamFileTypes() {
        let script = """
        (async function() {
            SystemFS.writeFile(testDir + '/file.txt', 'content');
            SystemFS.mkdir(testDir + '/dir');
            
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
            return entries;
        })();
        """
        
        let expectation = XCTestExpectation(description: "Directory stream file types")
        
        let promise = context.evaluateScript(script)
        XCTAssertTrue(promise.hasProperty("then"), "Should return a Promise")
        
        promise.invokeMethod("then", withArguments: [SwiftJS.Value(newFunctionIn: context) { args, _ in
            let entries = args[0]
            XCTAssertTrue(entries.isArray, "Should return an array")
            
            let count = Int(entries["length"].numberValue ?? 0)
            XCTAssertEqual(count, 2, "Should have 2 entries")
            
            var foundFile = false
            var foundDir = false
            
            for i in 0..<count {
                let entry = entries[i]
                let name = entry["name"].toString()
                
                if name == "file.txt" {
                    foundFile = true
                    XCTAssertTrue(entry["isFile"].boolValue ?? false, "file.txt should be a regular file")
                    XCTAssertFalse(entry["isDirectory"].boolValue ?? true, "file.txt should not be a directory")
                    XCTAssertFalse(entry["isSymbolicLink"].boolValue ?? true, "file.txt should not be a symbolic link")
                    XCTAssertFalse(entry["isCharacterDevice"].boolValue ?? true, "file.txt should not be a character device")
                    XCTAssertFalse(entry["isBlockDevice"].boolValue ?? true, "file.txt should not be a block device")
                    XCTAssertFalse(entry["isSocket"].boolValue ?? true, "file.txt should not be a socket")
                } else if name == "dir" {
                    foundDir = true
                    XCTAssertFalse(entry["isFile"].boolValue ?? true, "dir should not be a regular file")
                    XCTAssertTrue(entry["isDirectory"].boolValue ?? false, "dir should be a directory")
                    XCTAssertFalse(entry["isSymbolicLink"].boolValue ?? true, "dir should not be a symbolic link")
                    XCTAssertFalse(entry["isCharacterDevice"].boolValue ?? true, "dir should not be a character device")
                    XCTAssertFalse(entry["isBlockDevice"].boolValue ?? true, "dir should not be a block device")
                    XCTAssertFalse(entry["isSocket"].boolValue ?? true, "dir should not be a socket")
                }
            }
            
            XCTAssertTrue(foundFile, "Should find file.txt")
            XCTAssertTrue(foundDir, "Should find dir")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }])
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFileTypeFlagsAreMutuallyExclusive() {
        // Regular files should only have isFile = true
        let fileScript = """
        SystemFS.writeFile(testDir + '/test.txt', 'test');
        var stat = SystemFS.stat(testDir + '/test.txt');
        var trueCount = [stat.isFile, stat.isDirectory, stat.isSymbolicLink, 
                         stat.isCharacterDevice, stat.isBlockDevice, stat.isSocket]
                        .filter(function(x) { return x === true; }).length;
        trueCount;
        """
        
        let fileResult = context.evaluateScript(fileScript)
        XCTAssertEqual(fileResult.numberValue ?? 0, 1, "Regular file should have exactly one file type flag set")
        
        // Directories should only have isDirectory = true
        let dirScript = """
        SystemFS.mkdir(testDir + '/testdir');
        var stat = SystemFS.stat(testDir + '/testdir');
        var trueCount = [stat.isFile, stat.isDirectory, stat.isSymbolicLink,
                         stat.isCharacterDevice, stat.isBlockDevice, stat.isSocket]
                        .filter(function(x) { return x === true; }).length;
        trueCount;
        """
        
        let dirResult = context.evaluateScript(dirScript)
        XCTAssertEqual(dirResult.numberValue ?? 0, 1, "Directory should have exactly one file type flag set")
    }
}
