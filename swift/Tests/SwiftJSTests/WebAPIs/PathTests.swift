//
//  PathTests.swift
//  SwiftJS Tests
//
//  Created by GitHub Copilot on 2025/9/6.
//  Copyright © 2025 o2ter. All rights reserved.
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

/// Tests for the global Path utility class, which provides Node.js-like path manipulation functions.
@MainActor
final class PathTests: XCTestCase {
    
    // MARK: - Path API Existence Tests
    
    func testPathExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof Path")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testPathStaticMethods() {
        let script = """
            ({
                hasJoin: typeof Path.join === 'function',
                hasResolve: typeof Path.resolve === 'function',
                hasNormalize: typeof Path.normalize === 'function',
                hasDirname: typeof Path.dirname === 'function',
                hasBasename: typeof Path.basename === 'function',
                hasExtname: typeof Path.extname === 'function',
                hasIsAbsolute: typeof Path.isAbsolute === 'function',
                hasSep: typeof Path.sep === 'string'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["hasJoin"].boolValue ?? false)
        XCTAssertTrue(result["hasResolve"].boolValue ?? false)
        XCTAssertTrue(result["hasNormalize"].boolValue ?? false)
        XCTAssertTrue(result["hasDirname"].boolValue ?? false)
        XCTAssertTrue(result["hasBasename"].boolValue ?? false)
        XCTAssertTrue(result["hasExtname"].boolValue ?? false)
        XCTAssertTrue(result["hasIsAbsolute"].boolValue ?? false)
        XCTAssertTrue(result["hasSep"].boolValue ?? false)
    }
    
    // MARK: - Path Separator Tests
    
    func testPathSeparator() {
        let script = """
            ({
                sep: Path.sep,
                sepIsString: typeof Path.sep === 'string',
                sepIsSlash: Path.sep === '/'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["sepIsString"].boolValue ?? false)
        XCTAssertEqual(result["sep"].toString(), "/")
        XCTAssertTrue(result["sepIsSlash"].boolValue ?? false)
    }
    
    // MARK: - Path.join() Tests
    
    func testPathJoinBasic() {
        let script = """
            ({
                simple: Path.join('a', 'b', 'c'),
                withSlashes: Path.join('/a/', '/b/', '/c/'),
                empty: Path.join(),
                single: Path.join('test'),
                absolute: Path.join('/usr', 'local', 'bin'),
                relative: Path.join('.', 'src', 'main.js')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["simple"].toString(), "a/b/c")
        XCTAssertEqual(result["withSlashes"].toString(), "/a/b/c")
        XCTAssertEqual(result["empty"].toString(), ".")
        XCTAssertEqual(result["single"].toString(), "test")
        XCTAssertEqual(result["absolute"].toString(), "/usr/local/bin")
        XCTAssertEqual(result["relative"].toString(), "src/main.js")
    }
    
    func testPathJoinEdgeCases() {
        let script = """
            ({
                emptyStrings: Path.join('', 'test', ''),
                nullish: Path.join('a', null, 'c'),
                dotSegments: Path.join('a', '.', 'b'),
                multipleSlashes: Path.join('a//b', 'c///d'),
                onlySlashes: Path.join('/', '//', '///'),
                mixedTypes: Path.join('test', 123, 'end')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["emptyStrings"].toString(), "test")
        XCTAssertEqual(result["dotSegments"].toString(), "a/b")
        XCTAssertEqual(result["multipleSlashes"].toString(), "a/b/c/d")
    }
    
    // MARK: - Path.normalize() Tests
    
    func testPathNormalize() {
        let script = """
            ({
                simple: Path.normalize('/a/b/c'),
                dotSegments: Path.normalize('/a/./b/../c'),
                doubleDots: Path.normalize('/a/b/../c/d'),
                trailingSlash: Path.normalize('/a/b/c/'),
                multipleSlashes: Path.normalize('//a///b//c'),
                relative: Path.normalize('a/b/../c'),
                onlyDots: Path.normalize('././.'),
                empty: Path.normalize(''),
                root: Path.normalize('/'),
                complex: Path.normalize('/a/b/c/../../d/./e/../f')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["simple"].toString(), "/a/b/c")
        XCTAssertEqual(result["dotSegments"].toString(), "/a/c")
        XCTAssertEqual(result["doubleDots"].toString(), "/a/c/d")
        XCTAssertEqual(result["multipleSlashes"].toString(), "/a/b/c")
        XCTAssertEqual(result["relative"].toString(), "a/c")
        XCTAssertEqual(result["onlyDots"].toString(), ".")
        XCTAssertEqual(result["empty"].toString(), ".")
        XCTAssertEqual(result["root"].toString(), "/")
        XCTAssertEqual(result["complex"].toString(), "/a/d/f")
    }
    
    // MARK: - Path.dirname() Tests
    
    func testPathDirname() {
        let script = """
            ({
                simple: Path.dirname('/a/b/c'),
                file: Path.dirname('/path/to/file.txt'),
                root: Path.dirname('/'),
                relative: Path.dirname('a/b/c'),
                noDir: Path.dirname('file.txt'),
                nested: Path.dirname('/very/deep/nested/path/file.js'),
                withDots: Path.dirname('/a/b/../c/file.txt'),
                empty: Path.dirname('')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["simple"].toString(), "/a/b")
        XCTAssertEqual(result["file"].toString(), "/path/to")
        XCTAssertEqual(result["root"].toString(), "/")
        XCTAssertEqual(result["relative"].toString(), "a/b")
        XCTAssertEqual(result["noDir"].toString(), ".")
        XCTAssertEqual(result["nested"].toString(), "/very/deep/nested/path")
        XCTAssertEqual(result["empty"].toString(), ".")
    }
    
    // MARK: - Path.basename() Tests
    
    func testPathBasename() {
        let script = """
            ({
                simple: Path.basename('/a/b/c'),
                file: Path.basename('/path/to/file.txt'),
                withExt: Path.basename('/path/to/file.txt', '.txt'),
                noExt: Path.basename('/path/to/file.txt', '.js'),
                root: Path.basename('/'),
                relative: Path.basename('a/b/file.js'),
                dotfile: Path.basename('/path/.hidden'),
                complex: Path.basename('/path/to/file.min.js', '.js'),
                empty: Path.basename('')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["simple"].toString(), "c")
        XCTAssertEqual(result["file"].toString(), "file.txt")
        XCTAssertEqual(result["withExt"].toString(), "file")
        XCTAssertEqual(result["noExt"].toString(), "file.txt")
        XCTAssertEqual(result["root"].toString(), "")
        XCTAssertEqual(result["relative"].toString(), "file.js")
        XCTAssertEqual(result["dotfile"].toString(), ".hidden")
        XCTAssertEqual(result["complex"].toString(), "file.min")
        XCTAssertEqual(result["empty"].toString(), "")
    }
    
    // MARK: - Path.extname() Tests
    
    func testPathExtname() {
        let script = """
            ({
                simple: Path.extname('file.txt'),
                complex: Path.extname('file.min.js'),
                noExt: Path.extname('README'),
                dotfile: Path.extname('.gitignore'),
                multiDot: Path.extname('archive.tar.gz'),
                pathWithExt: Path.extname('/path/to/file.html'),
                onlyDot: Path.extname('file.'),
                empty: Path.extname(''),
                dotOnly: Path.extname('.'),
                doubleDot: Path.extname('..'),
                leadingDot: Path.extname('.hidden.txt')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["simple"].toString(), ".txt")
        XCTAssertEqual(result["complex"].toString(), ".js")
        XCTAssertEqual(result["noExt"].toString(), "")
        XCTAssertEqual(result["dotfile"].toString(), "")
        XCTAssertEqual(result["multiDot"].toString(), ".gz")
        XCTAssertEqual(result["pathWithExt"].toString(), ".html")
        XCTAssertEqual(result["onlyDot"].toString(), "")
        XCTAssertEqual(result["empty"].toString(), "")
        XCTAssertEqual(result["dotOnly"].toString(), "")
        XCTAssertEqual(result["doubleDot"].toString(), "")
        XCTAssertEqual(result["leadingDot"].toString(), ".txt")
    }
    
    // MARK: - Path.isAbsolute() Tests
    
    func testPathIsAbsolute() {
        let script = """
            ({
                absolute: Path.isAbsolute('/usr/local/bin'),
                relative: Path.isAbsolute('src/main.js'),
                dot: Path.isAbsolute('./file.txt'),
                doubleDot: Path.isAbsolute('../file.txt'),
                root: Path.isAbsolute('/'),
                empty: Path.isAbsolute(''),
                justFile: Path.isAbsolute('file.txt'),
                complex: Path.isAbsolute('/a/b/../c/./d')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["absolute"].boolValue ?? false)
        XCTAssertFalse(result["relative"].boolValue ?? true)
        XCTAssertFalse(result["dot"].boolValue ?? true)
        XCTAssertFalse(result["doubleDot"].boolValue ?? true)
        XCTAssertTrue(result["root"].boolValue ?? false)
        XCTAssertFalse(result["empty"].boolValue ?? true)
        XCTAssertFalse(result["justFile"].boolValue ?? true)
        XCTAssertTrue(result["complex"].boolValue ?? false)
    }
    
    // MARK: - Path Integration Tests
    
    func testPathMethodChaining() {
        let script = """
            var testPath = '/Users/test/projects/myapp/src/components/../utils/helper.js';
            
            ({
                original: testPath,
                normalized: Path.normalize(testPath),
                dirname: Path.dirname(Path.normalize(testPath)),
                basename: Path.basename(Path.normalize(testPath)),
                extname: Path.extname(Path.basename(testPath)),
                reconstructed: Path.join(
                    Path.dirname(Path.normalize(testPath)),
                    Path.basename(Path.normalize(testPath))
                ),
                isAbsolute: Path.isAbsolute(testPath)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["normalized"].toString(), "/Users/test/projects/myapp/src/utils/helper.js")
        XCTAssertEqual(result["dirname"].toString(), "/Users/test/projects/myapp/src/utils")
        XCTAssertEqual(result["basename"].toString(), "helper.js")
        XCTAssertEqual(result["extname"].toString(), ".js")
        XCTAssertEqual(result["reconstructed"].toString(), "/Users/test/projects/myapp/src/utils/helper.js")
        XCTAssertTrue(result["isAbsolute"].boolValue ?? false)
    }
    
    func testPathErrorHandling() {
        let script = """
            ({
                joinWithUndefined: Path.join('a', undefined, 'c'),
                dirnameNull: Path.dirname(null),
                basenameNumber: Path.basename(123),
                extnameObject: Path.extname({}),
                isAbsoluteBoolean: Path.isAbsolute(true)
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // These should handle type coercion gracefully
        XCTAssertEqual(result["joinWithUndefined"].toString(), "a/c")
        XCTAssertNotNil(result["dirnameNull"].toString())
        XCTAssertNotNil(result["basenameNumber"].toString())
        XCTAssertNotNil(result["extnameObject"].toString())
        XCTAssertNotNil(result["isAbsoluteBoolean"].boolValue)
    }
    
    // MARK: - Performance Tests
    
    func testPathPerformance() {
        measure {
            let script = """
                var results = [];
                for (var i = 0; i < 1000; i++) {
                    var testPath = '/path/to/file' + i + '.js';
                    results.push({
                        join: Path.join('/base', 'sub', 'file' + i + '.js'),
                        normalize: Path.normalize(testPath + '/../other.js'),
                        dirname: Path.dirname(testPath),
                        basename: Path.basename(testPath),
                        extname: Path.extname(testPath),
                        isAbsolute: Path.isAbsolute(testPath)
                    });
                }
                results.length
            """
            let context = SwiftJS()
            let result = context.evaluateScript(script)
            XCTAssertEqual(result.numberValue, 1000)
        }
    }
}
