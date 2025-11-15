//
//  Base64Tests.swift
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

/// Tests for the global btoa() and atob() Base64 encoding/decoding functions.
@MainActor
final class Base64Tests: XCTestCase {
    
    // MARK: - API Existence Tests
    
    func testBase64FunctionsExist() {
        let context = SwiftJS()
        let result = context.evaluateScript("""
            ({
                btoaExists: typeof btoa === 'function',
                atobExists: typeof atob === 'function'
            })
        """)
        
        XCTAssertTrue(result["btoaExists"].boolValue ?? false)
        XCTAssertTrue(result["atobExists"].boolValue ?? false)
    }
    
    // MARK: - btoa() Tests
    
    func testBtoaBasic() {
        let script = """
            ({
                hello: btoa('Hello'),
                world: btoa('World'),
                empty: btoa(''),
                simple: btoa('a'),
                longer: btoa('Hello, World!')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["hello"].toString(), "SGVsbG8=")
        XCTAssertEqual(result["world"].toString(), "V29ybGQ=")
        XCTAssertEqual(result["empty"].toString(), "")
        XCTAssertEqual(result["simple"].toString(), "YQ==")
        XCTAssertEqual(result["longer"].toString(), "SGVsbG8sIFdvcmxkIQ==")
    }
    
    func testBtoaSpecialCharacters() {
        let script = """
            ({
                newline: btoa('\\n'),
                tab: btoa('\\t'),
                space: btoa(' '),
                symbols: btoa('!@#$%^&*()'),
                numbers: btoa('1234567890')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["newline"].toString(), "Cg==")
        XCTAssertEqual(result["tab"].toString(), "CQ==")
        XCTAssertEqual(result["space"].toString(), "IA==")
        XCTAssertEqual(result["symbols"].toString(), "IUAjJCVeJiooKQ==")
        XCTAssertEqual(result["numbers"].toString(), "MTIzNDU2Nzg5MA==")
    }
    
    func testBtoaLatin1Range() {
        let script = """
            const latin1 = btoa('àáâãäå');
            ({
                latin1: latin1,
                hasValue: latin1.length > 0
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(
            result["hasValue"].boolValue ?? false, "btoa should encode Latin-1 characters")
        XCTAssertNotEqual(result["latin1"].toString(), "", "btoa should return non-empty string")
    }
    
    func testBtoaUnicodeError() {
        let script = """
            try {
                btoa('🚀'); // Unicode emoji should cause an error
                ({ error: false, message: 'Should have thrown' })
            } catch (error) {
                ({ error: true, message: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["error"].boolValue ?? false)
        XCTAssertTrue(result["message"].toString().contains("Latin1"))
    }
    
    func testBtoaTypeCoercion() {
        let script = """
            ({
                number: btoa(123),
                boolean: btoa(true),
                object: btoa({}),
                array: btoa([1, 2, 3])
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["number"].toString(), "MTIz") // "123" base64
        XCTAssertEqual(result["boolean"].toString(), "dHJ1ZQ==") // "true" base64
        XCTAssertEqual(result["object"].toString(), "W29iamVjdCBPYmplY3Rd") // "[object Object]" base64
        XCTAssertEqual(result["array"].toString(), "MSwyLDM=") // "1,2,3" base64
    }
    
    func testBtoaErrorHandling() {
        let script = """
            try {
                btoa(); // No arguments
                ({ error: false, message: 'Should have thrown' })
            } catch (error) {
                ({ error: true, message: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["error"].boolValue ?? false)
        XCTAssertTrue(result["message"].toString().contains("argument"))
    }
    
    // MARK: - atob() Tests
    
    func testAtobBasic() {
        let script = """
            ({
                hello: atob('SGVsbG8='),
                world: atob('V29ybGQ='),
                empty: atob(''),
                simple: atob('YQ=='),
                longer: atob('SGVsbG8sIFdvcmxkIQ==')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["hello"].toString(), "Hello")
        XCTAssertEqual(result["world"].toString(), "World")
        XCTAssertEqual(result["empty"].toString(), "")
        XCTAssertEqual(result["simple"].toString(), "a")
        XCTAssertEqual(result["longer"].toString(), "Hello, World!")
    }
    
    func testAtobPadding() {
        let script = """
            function safeAtob(str) {
                try {
                    return atob(str);
                } catch (e) {
                    return 'ERROR: ' + e.message;
                }
            }
            
            ({
                noPadding: safeAtob('SGVsbG8'),
                onePad: safeAtob('SGVsbG8='),
                valid1: safeAtob('SGVsbG8A'),
                invalid1: safeAtob('SGVsbG8AA='),
                valid2: safeAtob('SGVsbG8AAA=='),
                noPaddingCheck: safeAtob('SGVsbG8') === 'Hello'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Valid cases should decode correctly
        XCTAssertEqual(result["noPadding"].toString(), "Hello")
        XCTAssertEqual(result["onePad"].toString(), "Hello")
        XCTAssertTrue(result["noPaddingCheck"].boolValue ?? false)
        
        // Invalid case should produce error
        XCTAssertTrue(result["invalid1"].toString().contains("ERROR"))
    }
    
    func testAtobWhitespace() {
        let script = """
            ({
                withSpaces: atob('SGVs bG8='),
                withTabs: atob('SGVs\\tbG8='),
                withNewlines: atob('SGVs\\nbG8='),
                mixed: atob(' SGVs bG8= \\n\\t')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Whitespace should be ignored
        XCTAssertEqual(result["withSpaces"].toString(), "Hello")
        XCTAssertEqual(result["withTabs"].toString(), "Hello")
        XCTAssertEqual(result["withNewlines"].toString(), "Hello")
        XCTAssertEqual(result["mixed"].toString(), "Hello")
    }
    
    func testAtobInvalidCharacters() {
        let script = """
            try {
                atob('SGVsbG8@'); // @ is not a valid base64 character
                ({ error: false, message: 'Should have thrown' })
            } catch (error) {
                ({ error: true, message: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["error"].boolValue ?? false)
        XCTAssertTrue(result["message"].toString().contains("encoded"))
    }
    
    func testAtobErrorHandling() {
        let script = """
            var errors = [];
            
            // No arguments
            try {
                atob();
                errors.push({ test: 'no_args', error: false });
            } catch (error) {
                errors.push({ test: 'no_args', error: true, message: error.message });
            }
            
            // Invalid length
            try {
                atob('SGVsbG');
                errors.push({ test: 'invalid_length', error: false });
            } catch (error) {
                errors.push({ test: 'invalid_length', error: true, message: error.message });
            }
            
            errors
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let errors = result
        let errorCount = Int(errors["length"].numberValue ?? 0)
        XCTAssertEqual(errorCount, 2)
        
        // Check no arguments error
        XCTAssertTrue(errors[0]["error"].boolValue ?? false)
        XCTAssertTrue(errors[0]["message"].toString().contains("argument"))
    }
    
    // MARK: - Round-trip Tests
    
    func testBase64RoundTrip() {
        let script = """
            var testStrings = [
                'Hello, World!',
                'The quick brown fox jumps over the lazy dog',
                '1234567890',
                '!@#$%^&*()',
                'a',
                '',
                'Multi\\nLine\\nText\\nWith\\nBreaks'
            ];
            
            var results = [];
            for (var i = 0; i < testStrings.length; i++) {
                var original = testStrings[i];
                var encoded = btoa(original);
                var decoded = atob(encoded);
                results.push({
                    original: original,
                    encoded: encoded,
                    decoded: decoded,
                    matches: original === decoded
                });
            }
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        let resultsCount = Int(result["length"].numberValue ?? 0)
        for i in 0..<resultsCount {
            let test = result[i]
            XCTAssertTrue(test["matches"].boolValue ?? false,
                         "Round trip failed for: '\(test["original"].toString())'")
        }
    }
    
    func testBase64BinaryData() {
        let script = """
            // Test with binary-like data (all possible byte values 0-255)
            var binaryString = '';
            for (var i = 0; i < 256; i++) {
                binaryString += String.fromCharCode(i);
            }
            
            try {
                var encoded = btoa(binaryString);
                var decoded = atob(encoded);
                var matches = true;
                
                // Check if all bytes match
                if (decoded.length !== binaryString.length) {
                    matches = false;
                } else {
                    for (var i = 0; i < decoded.length; i++) {
                        if (decoded.charCodeAt(i) !== binaryString.charCodeAt(i)) {
                            matches = false;
                            break;
                        }
                    }
                }
                
                ({
                    success: true,
                    originalLength: binaryString.length,
                    encodedLength: encoded.length,
                    decodedLength: decoded.length,
                    matches: matches
                })
            } catch (error) {
                ({
                    success: false,
                    error: error.message
                })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(
            result["success"].boolValue ?? false, "btoa/atob should handle all byte values")
        XCTAssertEqual(
            result["originalLength"].numberValue, 256, "Should encode all 256 byte values")
        XCTAssertEqual(result["decodedLength"].numberValue, 256, "Should decode back to 256 bytes")
        XCTAssertTrue(result["matches"].boolValue ?? false, "Round-trip should preserve all values")
        XCTAssertGreaterThan(
            result["encodedLength"].numberValue ?? 0, 256, "Base64 encoding should be longer")
    }
    
    // MARK: - Edge Cases
    
    func testBase64EdgeCases() {
        let script = """
            ({
                // Test various padding scenarios
                padding0: atob('YW55IGNhcm5hbCBwbGVhc3VyZS4'),
                padding1: atob('YW55IGNhcm5hbCBwbGVhc3VyZQ=='),
                padding2: atob('YW55IGNhcm5hbCBwbGVhc3Vy'),
                
                // Test URL-safe characters
                urlSafe: btoa('?>?'),
                
                // Test long strings
                longString: btoa('a'.repeat(1000)).length > 1000
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["padding0"].toString(), "any carnal pleasure.")
        XCTAssertEqual(result["padding1"].toString(), "any carnal pleasure")
        XCTAssertEqual(result["padding2"].toString(), "any carnal pleasur")
        XCTAssertNotEqual(result["urlSafe"].toString(), "")
        XCTAssertTrue(result["longString"].boolValue ?? false)
    }
    
    // MARK: - Performance Tests
    
    func testBase64Performance() {
        measure {
            let script = """
                var testData = 'The quick brown fox jumps over the lazy dog '.repeat(100);
                var encoded, decoded;
                
                for (var i = 0; i < 100; i++) {
                    encoded = btoa(testData);
                    decoded = atob(encoded);
                }
                
                decoded === testData
            """
            let context = SwiftJS()
            let result = context.evaluateScript(script)
            XCTAssertTrue(result.boolValue ?? false)
        }
    }
    
    // MARK: - Integration Tests
    
    func testBase64WithDataURLs() {
        let script = """
            // Test creating a data URL
            var text = 'Hello, Base64!';
            var encoded = btoa(text);
            var dataUrl = 'data:text/plain;base64,' + encoded;
            
            // Extract and decode
            var base64Part = dataUrl.split(',')[1];
            var decoded = atob(base64Part);
            
            ({
                original: text,
                dataUrl: dataUrl,
                decoded: decoded,
                matches: text === decoded,
                isValidDataUrl: dataUrl.startsWith('data:')
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["original"].toString(), "Hello, Base64!")
        XCTAssertEqual(result["decoded"].toString(), "Hello, Base64!")
        XCTAssertTrue(result["matches"].boolValue ?? false)
        XCTAssertTrue(result["isValidDataUrl"].boolValue ?? false)
        XCTAssertTrue(result["dataUrl"].toString().hasPrefix("data:text/plain;base64,"))
    }
}
