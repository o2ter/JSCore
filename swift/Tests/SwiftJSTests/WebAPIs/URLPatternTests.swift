//
// URLPatternTests.swift
// SwiftJS
//
// MIT License
//
// Copyright (c) 2025 o2ter
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest

@testable import SwiftJS

@MainActor
final class URLPatternTests: XCTestCase {

    func testURLPatternExactMatch() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/123');
            ({
                match1: pattern.test('/users/123'),
                match2: pattern.test('/users/456'),
                match3: pattern.test('/posts/123')
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["match1"].boolValue, "Should match exact path")
        XCTAssertFalse(result["match2"].boolValue, "Should not match different ID")
        XCTAssertFalse(result["match3"].boolValue, "Should not match different path")
    }

    func testURLPatternNamedParameters() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/users/123');
            ({
                matched: result !== null,
                hasParams: result && result.params !== undefined,
                id: result && result.params.id
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["matched"].boolValue, "Should match pattern")
        XCTAssertTrue(result["hasParams"].boolValue, "Should have params object")
        XCTAssertEqual(result["id"].stringValue, "123", "Should extract ID parameter")
    }

    func testURLPatternMultipleNamedParameters() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/:userId/posts/:postId');
            var result = pattern.exec('/users/42/posts/99');
            ({
                userId: result && result.params.userId,
                postId: result && result.params.postId
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertEqual(result["userId"].stringValue, "42", "Should extract userId")
        XCTAssertEqual(result["postId"].stringValue, "99", "Should extract postId")
    }

    func testURLPatternWildcard() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/static/*');
            ({
                match1: pattern.test('/static/css/style.css'),
                match2: pattern.test('/static/js/app.js'),
                match3: pattern.test('/api/data'),
                exec: pattern.exec('/static/images/logo.png')
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["match1"].boolValue, "Should match /static/css/style.css")
        XCTAssertTrue(result["match2"].boolValue, "Should match /static/js/app.js")
        XCTAssertFalse(result["match3"].boolValue, "Should not match /api/data")

        let exec = result["exec"]
        XCTAssertFalse(exec.isNull, "Should match and return result")
    }

    func testURLPatternDoubleWildcard() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/files/**');
            ({
                match1: pattern.test('/files/docs/report.pdf'),
                match2: pattern.test('/files/images/2024/photo.jpg'),
                match3: pattern.test('/api/files')
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["match1"].boolValue, "Should match nested path")
        XCTAssertTrue(result["match2"].boolValue, "Should match deeply nested path")
        XCTAssertFalse(result["match3"].boolValue, "Should not match different base path")
    }

    func testURLPatternMixedParameters() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/api/:version/users/:id/*');
            var result = pattern.exec('/api/v1/users/123/profile/avatar');
            ({
                matched: result !== null,
                version: result && result.params.version,
                id: result && result.params.id
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["matched"].boolValue, "Should match complex pattern")
        XCTAssertEqual(result["version"].stringValue, "v1", "Should extract version")
        XCTAssertEqual(result["id"].stringValue, "123", "Should extract id")
    }

    func testURLPatternNoMatch() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/posts/123');
            result === null
            """

        let isNull = context.evaluateScript(script).boolValue
        XCTAssertTrue(isNull, "Should return null for non-matching path")
    }

    func testURLPatternTrailingSlash() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/:id');
            ({
                withoutSlash: pattern.test('/users/123'),
                withSlash: pattern.test('/users/123/')
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["withoutSlash"].boolValue, "Should match without trailing slash")
        // Note: Behavior for trailing slash may vary by implementation
    }

    func testURLPatternEmptyPath() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/');
            ({
                root: pattern.test('/'),
                other: pattern.test('/users')
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["root"].boolValue, "Should match root path")
        XCTAssertFalse(result["other"].boolValue, "Should not match non-root path")
    }

    func testURLPatternSpecialCharacters() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/users/:id');
            var result = pattern.exec('/users/abc-123_xyz');
            ({
                matched: result !== null,
                id: result && result.params.id
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["matched"].boolValue, "Should match ID with special chars")
        XCTAssertEqual(
            result["id"].stringValue, "abc-123_xyz", "Should extract full ID with special chars")
    }

    func testURLPatternConstructor() {
        let context = SwiftJS()

        let script = """
            var pattern = new URLPattern('/test');
            ({
                hasTest: typeof pattern.test === 'function',
                hasExec: typeof pattern.exec === 'function',
                isURLPattern: pattern.constructor.name === 'URLPattern'
            })
            """

        let result = context.evaluateScript(script)
        XCTAssertTrue(result["hasTest"].boolValue ?? false, "Should have test method")
        XCTAssertTrue(result["hasExec"].boolValue ?? false, "Should have exec method")
        XCTAssertTrue(
            result["isURLPattern"].boolValue ?? false, "Constructor name should be URLPattern")
    }
}
