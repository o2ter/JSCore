//
//  TextEncodingTests.swift
//  SwiftJS Text Encoding Tests
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

/// Tests for the Web Text Encoding API including TextEncoder and TextDecoder
/// for converting between strings and byte arrays.
@MainActor
final class TextEncodingTests: XCTestCase {
    
    // MARK: - TextEncoder API Tests
    
    func testTextEncoderExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof TextEncoder")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testTextEncoderInstantiation() {
        let script = """
            const encoder = new TextEncoder();
            encoder instanceof TextEncoder
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTextEncoderEncoding() {
        let script = """
            const encoder = new TextEncoder();
            encoder.encoding
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "utf-8")
    }
    
    func testTextEncoderBasicEncoding() {
        let script = """
            const encoder = new TextEncoder();
            const encoded = encoder.encode('Hello, SwiftJS!');
            encoded instanceof Uint8Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTextEncoderASCIIText() {
        let script = """
            const encoder = new TextEncoder();
            const text = 'Hello World';
            const encoded = encoder.encode(text);
            
            ({
                length: encoded.length,
                firstByte: encoded[0],
                lastByte: encoded[encoded.length - 1],
                isUint8Array: encoded instanceof Uint8Array
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["length"].numberValue, 11) // "Hello World" is 11 bytes
        XCTAssertEqual(result["firstByte"].numberValue, 72) // 'H' is 72
        XCTAssertEqual(result["lastByte"].numberValue, 100) // 'd' is 100
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
    }
    
    func testTextEncoderUnicodeText() {
        let script = """
            const encoder = new TextEncoder();
            const text = 'Hello, 世界! 🌍';
            const encoded = encoder.encode(text);
            
            ({
                length: encoded.length,
                isUint8Array: encoded instanceof Uint8Array,
                hasUnicodeBytes: encoded.length > text.length
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
        XCTAssertTrue(result["hasUnicodeBytes"].boolValue ?? false) // UTF-8 encoded should be longer than character count
        let length = Int(result["length"].numberValue ?? 0)
        XCTAssertGreaterThan(length, 10) // Should be more than ASCII length due to Unicode characters
    }
    
    func testTextEncoderEmptyString() {
        let script = """
            const encoder = new TextEncoder();
            const encoded = encoder.encode('');
            
            ({
                length: encoded.length,
                isUint8Array: encoded instanceof Uint8Array
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["length"].numberValue, 0)
        XCTAssertTrue(result["isUint8Array"].boolValue ?? false)
    }
    
    // MARK: - TextDecoder API Tests
    
    func testTextDecoderExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof TextDecoder")
        XCTAssertEqual(result.toString(), "function")
    }
    
    func testTextDecoderInstantiation() {
        let script = """
            const decoder = new TextDecoder();
            decoder instanceof TextDecoder
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testTextDecoderDefaultEncoding() {
        let script = """
            const decoder = new TextDecoder();
            decoder.encoding
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "utf-8")
    }
    
    func testTextDecoderWithSpecifiedEncoding() {
        let script = """
            const decoder = new TextDecoder('utf-8');
            decoder.encoding
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "utf-8")
    }
    
    func testTextDecoderBasicDecoding() {
        let script = """
            const decoder = new TextDecoder();
            const encoder = new TextEncoder();
            const encoded = encoder.encode('Hello, SwiftJS!');
            const decoded = decoder.decode(encoded);
            decoded
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "Hello, SwiftJS!")
    }
    
    // MARK: - Round-trip Encoding Tests
    
    func testEncodingRoundTrip() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            const original = 'Hello, World! 🌍 测试 テスト';
            const encoded = encoder.encode(original);
            const decoded = decoder.decode(encoded);
            decoded === original
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testMultipleEncodingDecoding() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            
            const testStrings = [
                'Simple ASCII text',
                'UTF-8 with émojis 🚀🌟',
                '中文测试',
                'Русский текст',
                'العربية',
                'हिन्दी',
                '日本語のテスト',
                ''
            ];
            
            const results = testStrings.map(text => {
                const encoded = encoder.encode(text);
                const decoded = decoder.decode(encoded);
                return decoded === text;
            });
            
            results.every(result => result === true)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testTextDecoderWithInvalidData() {
        let script = """
            const decoder = new TextDecoder();
            
            try {
                // Create some potentially invalid UTF-8 bytes
                const invalidBytes = new Uint8Array([0xFF, 0xFE, 0xFD]);
                const decoded = decoder.decode(invalidBytes);
                
                ({
                    success: true,
                    result: decoded,
                    type: typeof decoded
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message,
                    type: 'error'
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Should handle invalid data gracefully, either by decoding with replacement characters
        // or by providing a meaningful error
        XCTAssertEqual(result["type"].toString(), "string")
        if result["success"].boolValue ?? false {
            XCTAssertTrue(result["result"].isString)
        }
    }
    
    func testTextEncoderWithNonString() {
        let script = """
            const encoder = new TextEncoder();
            
            const testValues = [
                null,
                undefined,
                42,
                true,
                { toString: () => 'object' },
                [1, 2, 3]
            ];
            
            const results = testValues.map(value => {
                try {
                    const encoded = encoder.encode(value);
                    return {
                        success: true,
                        type: typeof value,
                        encoded: encoded instanceof Uint8Array
                    };
                } catch (error) {
                    return {
                        success: false,
                        type: typeof value,
                        error: error.message
                    };
                }
            });
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(resultsLength, 6)
        
        // All should either succeed (by converting to string) or fail gracefully
        for i in 0..<resultsLength {
            let testResult = result[i]
            XCTAssertTrue(testResult["success"].boolValue ?? testResult["error"].isString)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeTextEncoding() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            
            // Create a large text string
            const largeText = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '.repeat(1000);
            
            const start = Date.now();
            const encoded = encoder.encode(largeText);
            const decoded = decoder.decode(encoded);
            const end = Date.now();
            
            ({
                originalLength: largeText.length,
                encodedLength: encoded.length,
                roundTripSuccess: decoded === largeText,
                timeElapsed: end - start,
                isPerformant: (end - start) < 100
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["roundTripSuccess"].boolValue ?? false)
        XCTAssertTrue(result["isPerformant"].boolValue ?? false)
        let originalLength = Int(result["originalLength"].numberValue ?? 0)
        let encodedLength = Int(result["encodedLength"].numberValue ?? 0)
        XCTAssertGreaterThan(originalLength, 50000) // Should be a substantial amount of text
        XCTAssertGreaterThanOrEqual(encodedLength, originalLength) // UTF-8 should be at least as long
    }
    
    func testEncodingPerformance() {
        let context = SwiftJS()
        let script = """
            const encoder = new TextEncoder();
            const testText = 'Hello, World! This is a test string with émojis 🚀🌟 and unicode 测试';
            
            function encodeMany() {
                for (let i = 0; i < 1000; i++) {
                    encoder.encode(testText);
                }
                return true;
            }
            encodeMany
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("encodeMany()")
        }
    }
    
    func testDecodingPerformance() {
        let context = SwiftJS()
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            const testText = 'Hello, World! This is a test string with émojis 🚀🌟 and unicode 测试';
            const encodedData = encoder.encode(testText);
            
            function decodeMany() {
                for (let i = 0; i < 1000; i++) {
                    decoder.decode(encodedData);
                }
                return true;
            }
            decodeMany
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("decodeMany()")
        }
    }
    
    // MARK: - Edge Cases
    
    func testEncodingSpecialCharacters() {
        let script = """
            const encoder = new TextEncoder();
            const decoder = new TextDecoder();
            
            const specialChars = [
                '\\n\\r\\t',           // Control characters
                '\\u0000',            // Null character
                '\\uFEFF',            // BOM
                '\\uD83D\\uDE00',     // Emoji (surrogate pair)
                '\\u{1F600}',         // Emoji (ES6 unicode escape)
                String.fromCharCode(0xFFFF), // Maximum BMP character
            ];
            
            const results = specialChars.map(char => {
                try {
                    const encoded = encoder.encode(char);
                    const decoded = decoder.decode(encoded);
                    return {
                        success: true,
                        roundTrip: decoded === char,
                        encoded: encoded.length > 0
                    };
                } catch (error) {
                    return {
                        success: false,
                        error: error.message
                    };
                }
            });
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        
        // Most special characters should encode/decode successfully
        var successCount = 0
        for i in 0..<resultsLength {
            let testResult = result[i]
            if testResult["success"].boolValue ?? false {
                successCount += 1
            }
        }
        
        XCTAssertGreaterThan(successCount, resultsLength / 2) // At least half should succeed
    }
    
    func testTextEncoderStream() {
        let script = """
            // Test if TextEncoderStream exists (it might not be implemented)
            const hasTextEncoderStream = typeof TextEncoderStream !== 'undefined';
            
            if (hasTextEncoderStream) {
                try {
                    const stream = new TextEncoderStream();
                    ({
                        exists: true,
                        isStream: stream instanceof TextEncoderStream,
                        hasWritable: typeof stream.writable !== 'undefined',
                        hasReadable: typeof stream.readable !== 'undefined'
                    })
                } catch (error) {
                    ({
                        exists: true,
                        error: error.message
                    })
                }
            } else {
                ({
                    exists: false,
                    message: 'TextEncoderStream not implemented'
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // TextEncoderStream is optional in many implementations
        if result["exists"].boolValue ?? false {
            XCTAssertTrue(result["isStream"].boolValue ?? result["error"].isString)
        }
    }
    
    // MARK: - Base64 Encoding Tests

    func testBtoaExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof btoa")
        XCTAssertEqual(result.toString(), "function")
    }

    func testAtobExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof atob")
        XCTAssertEqual(result.toString(), "function")
    }

    func testBtoaBasicEncoding() {
        let script = """
                btoa('hello')
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "aGVsbG8=")
    }

    func testAtobBasicDecoding() {
        let script = """
                atob('aGVsbG8=')
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "hello")
    }

    func testBtoaAtobRoundTrip() {
        let script = """
                // Test with Latin1 characters only (btoa standard behavior)
                const original = 'Hello, World!';
                const encoded = btoa(original);
                const decoded = atob(encoded);
                ({
                    original: original,
                    encoded: encoded,
                    decoded: decoded,
                    matches: original === decoded
                })
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)

        XCTAssertEqual(result["original"].toString(), "Hello, World!")
        XCTAssertTrue(result["encoded"].toString().count > 0)
        XCTAssertEqual(result["decoded"].toString(), "Hello, World!")
        XCTAssertTrue(result["matches"].boolValue ?? false)
    }

    func testBtoaUnicodeError() {
        let script = """
                try {
                    btoa('Hello, World! 🌍');  // Contains Unicode character
                    ({ success: true, error: null })
                } catch (error) {
                    ({ success: false, error: error.message })
                }
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)

        // btoa should throw an error for Unicode characters outside Latin1 range
        XCTAssertFalse(result["success"].boolValue ?? true)
        XCTAssertTrue(result["error"].toString().contains("Latin1"))
    }

    func testBtoaEmptyString() {
        let script = """
                btoa('')
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "")
    }

    func testAtobEmptyString() {
        let script = """
                atob('')
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertEqual(result.toString(), "")
    }

    func testBtoaSpecialCharacters() {
        let script = """
                const testCases = [
                    { input: 'A', expected: 'QQ==' },
                    { input: 'AB', expected: 'QUI=' },
                    { input: 'ABC', expected: 'QUJD' },
                    { input: 'Man', expected: 'TWFu' },
                    { input: 'sure.', expected: 'c3VyZS4=' }
                ];
                
                testCases.map(test => ({
                    input: test.input,
                    actual: btoa(test.input),
                    expected: test.expected,
                    matches: btoa(test.input) === test.expected
                }))
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)

        for i in 0..<5 {
            let testCase = result[i]
            let input = testCase["input"].toString()
            let actual = testCase["actual"].toString()
            let expected = testCase["expected"].toString()
            let matches = testCase["matches"].boolValue ?? false

            XCTAssertTrue(matches, "btoa('\(input)') should be '\(expected)' but got '\(actual)'")
        }
    }

    func testAtobSpecialCharacters() {
        let script = """
                const testCases = [
                    { input: 'QQ==', expected: 'A' },
                    { input: 'QUI=', expected: 'AB' },
                    { input: 'QUJD', expected: 'ABC' },
                    { input: 'TWFu', expected: 'Man' },
                    { input: 'c3VyZS4=', expected: 'sure.' }
                ];
                
                testCases.map(test => ({
                    input: test.input,
                    actual: atob(test.input),
                    expected: test.expected,
                    matches: atob(test.input) === test.expected
                }))
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)

        for i in 0..<5 {
            let testCase = result[i]
            let input = testCase["input"].toString()
            let actual = testCase["actual"].toString()
            let expected = testCase["expected"].toString()
            let matches = testCase["matches"].boolValue ?? false

            XCTAssertTrue(matches, "atob('\(input)') should be '\(expected)' but got '\(actual)'")
        }
    }

    func testBase64DataURLUsage() {
        let script = """
                // Test btoa for creating data URLs (common use case)
                const text = 'Hello, Data URL!';  // Latin1 characters only
                const base64 = btoa(text);
                const dataURL = 'data:text/plain;base64,' + base64;
                const decoded = atob(base64);
                
                ({
                    original: text,
                    base64: base64,
                    dataURL: dataURL,
                    decoded: decoded,
                    roundTripSuccess: text === decoded
                })
            """
        let context = SwiftJS()
        let result = context.evaluateScript(script)

        XCTAssertEqual(result["original"].toString(), "Hello, Data URL!")
        XCTAssertTrue(result["base64"].toString().count > 0)
        XCTAssertTrue(result["dataURL"].toString().hasPrefix("data:text/plain;base64,"))
        XCTAssertEqual(result["decoded"].toString(), "Hello, Data URL!")
        XCTAssertTrue(result["roundTripSuccess"].boolValue ?? false)
    }
}
