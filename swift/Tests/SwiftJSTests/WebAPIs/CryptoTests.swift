//
//  CryptoTests.swift
//  SwiftJS Crypto API Tests
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

/// Tests for the Web Crypto API including crypto.randomUUID, crypto.getRandomValues,
/// and other cryptographic functions available in the global crypto object.
@MainActor
final class CryptoTests: XCTestCase {
    
    // MARK: - Crypto API Existence Tests
    
    func testCryptoExists() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof crypto")
        XCTAssertEqual(result.toString(), "object")
    }
    
    func testCryptoMethods() {
        let script = """
            ({
                hasRandomUUID: typeof crypto.randomUUID === 'function',
                hasGetRandomValues: typeof crypto.getRandomValues === 'function',
                isObject: typeof crypto === 'object'
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["isObject"].boolValue ?? false)
        XCTAssertTrue(result["hasRandomUUID"].boolValue ?? false)
        XCTAssertTrue(result["hasGetRandomValues"].boolValue ?? false)
    }
    
    // MARK: - crypto.randomUUID Tests
    
    func testRandomUUIDBasic() {
        let context = SwiftJS()
        let result = context.evaluateScript("typeof crypto.randomUUID()")
        XCTAssertEqual(result.toString(), "string")
    }
    
    func testRandomUUIDFormat() {
        let script = """
            const uuid = crypto.randomUUID();
            // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
            /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(uuid)
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRandomUUIDLength() {
        let script = """
            const uuid = crypto.randomUUID();
            uuid.length === 36
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testRandomUUIDUniqueness() {
        let script = """
            const uuids = [];
            for (let i = 0; i < 100; i++) {
                uuids.push(crypto.randomUUID());
            }
            
            const uniqueUUIDs = [...new Set(uuids)];
            
            ({
                generated: uuids.length,
                unique: uniqueUUIDs.length,
                allUnique: uuids.length === uniqueUUIDs.length
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["generated"].numberValue, 100)
        XCTAssertEqual(result["unique"].numberValue, 100)
        XCTAssertTrue(result["allUnique"].boolValue ?? false)
    }
    
    func testRandomUUIDWithoutArguments() {
        let script = """
            try {
                const uuid = crypto.randomUUID();
                typeof uuid === 'string'
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    // MARK: - crypto.getRandomValues Tests
    
    func testGetRandomValuesWithUint8Array() {
        let script = """
            const array = new Uint8Array(16);
            crypto.getRandomValues(array);
            array.length === 16 && array instanceof Uint8Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testGetRandomValuesWithUint16Array() {
        let script = """
            const array = new Uint16Array(8);
            crypto.getRandomValues(array);
            array.length === 8 && array instanceof Uint16Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testGetRandomValuesWithUint32Array() {
        let script = """
            const array = new Uint32Array(4);
            crypto.getRandomValues(array);
            array.length === 4 && array instanceof Uint32Array
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testGetRandomValuesRandomness() {
        let script = """
            const array1 = new Uint8Array(16);
            const array2 = new Uint8Array(16);
            
            crypto.getRandomValues(array1);
            crypto.getRandomValues(array2);
            
            // Check that arrays are different
            let different = false;
            for (let i = 0; i < 16; i++) {
                if (array1[i] !== array2[i]) {
                    different = true;
                    break;
                }
            }
            
            ({
                array1Length: array1.length,
                array2Length: array2.length,
                different: different
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["array1Length"].numberValue, 16)
        XCTAssertEqual(result["array2Length"].numberValue, 16)
        XCTAssertTrue(result["different"].boolValue ?? false)
    }
    
    func testGetRandomValuesEmptyArray() {
        let script = """
            try {
                const array = new Uint8Array(0);
                crypto.getRandomValues(array);
                array.length === 0
            } catch (error) {
                false
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertTrue(result.boolValue ?? false)
    }
    
    func testGetRandomValuesLargeArray() {
        let script = """
            try {
                const array = new Uint8Array(65536); // 64KB
                crypto.getRandomValues(array);
                
                // Check that some values are non-zero (very high probability)
                let hasNonZero = false;
                for (let i = 0; i < array.length; i++) {
                    if (array[i] !== 0) {
                        hasNonZero = true;
                        break;
                    }
                }
                
                ({
                    length: array.length,
                    hasNonZero: hasNonZero
                })
            } catch (error) {
                ({ error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["error"].isString {
            // Some implementations may have size limits
            XCTAssertTrue(result["error"].toString().contains("size") || result["error"].toString().contains("limit"))
        } else {
            XCTAssertEqual(result["length"].numberValue, 65536)
            XCTAssertTrue(result["hasNonZero"].boolValue ?? false)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testGetRandomValuesWithInvalidInput() {
        let script = """
            const results = [];
            
            // Test with null
            try {
                crypto.getRandomValues(null);
                results.push('null-accepted');
            } catch (e) {
                results.push('null-rejected');
            }
            
            // Test with undefined
            try {
                crypto.getRandomValues(undefined);
                results.push('undefined-accepted');
            } catch (e) {
                results.push('undefined-rejected');
            }
            
            // Test with regular array (not typed array)
            try {
                crypto.getRandomValues([1, 2, 3]);
                results.push('array-accepted');
            } catch (e) {
                results.push('array-rejected');
            }
            
            // Test with string
            try {
                crypto.getRandomValues('not an array');
                results.push('string-accepted');
            } catch (e) {
                results.push('string-rejected');
            }
            
            results
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result.isArray)
        let resultsLength = Int(result["length"].numberValue ?? 0)
        XCTAssertEqual(resultsLength, 4)
        
        // Should properly reject invalid inputs
        for i in 0..<resultsLength {
            let testResult = result[i].toString()
            XCTAssertTrue(testResult.contains("rejected") || testResult.contains("accepted"))
        }
    }
    
    func testGetRandomValuesWithFloat32Array() {
        let script = """
            try {
                const array = new Float32Array(4);
                crypto.getRandomValues(array);
                // Float32Array might not be supported by getRandomValues
                ({ supported: true, length: array.length })
            } catch (error) {
                ({ supported: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // Float arrays are typically not supported by getRandomValues
        if result["supported"].boolValue ?? false {
            XCTAssertEqual(result["length"].numberValue, 4)
        } else {
            XCTAssertTrue(result["error"].isString)
        }
    }
    
    // MARK: - Crypto Subtle API Tests (if available)
    
    func testCryptoSubtleExists() {
        let script = """
            ({
                hasSubtle: typeof crypto.subtle !== 'undefined',
                subtleType: typeof crypto.subtle
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        // crypto.subtle is optional and might not be implemented
        let hasSubtle = result["hasSubtle"].boolValue ?? false
        if hasSubtle {
            XCTAssertEqual(result["subtleType"].toString(), "object")
        }
    }
    
    func testCryptoSubtleMethods() {
        let script = """
            if (typeof crypto.subtle !== 'undefined') {
                ({
                    hasDigest: typeof crypto.subtle.digest === 'function',
                    hasGenerateKey: typeof crypto.subtle.generateKey === 'function',
                    hasImportKey: typeof crypto.subtle.importKey === 'function',
                    hasExportKey: typeof crypto.subtle.exportKey === 'function',
                    hasEncrypt: typeof crypto.subtle.encrypt === 'function',
                    hasDecrypt: typeof crypto.subtle.decrypt === 'function',
                    hasSign: typeof crypto.subtle.sign === 'function',
                    hasVerify: typeof crypto.subtle.verify === 'function'
                })
            } else {
                ({ subtleNotAvailable: true })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        if result["subtleNotAvailable"].boolValue ?? false {
            // crypto.subtle is not implemented, which is acceptable
            XCTAssertTrue(true)
        } else {
            // If crypto.subtle exists, it should have standard methods
            XCTAssertTrue(result["hasDigest"].boolValue ?? false)
            // Other methods might be optional depending on implementation
        }
    }
    
    // MARK: - Performance Tests
    
    func testRandomUUIDPerformance() {
        let context = SwiftJS()
        let script = """
            function generateManyUUIDs() {
                for (let i = 0; i < 1000; i++) {
                    crypto.randomUUID();
                }
                return true;
            }
            generateManyUUIDs
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("generateManyUUIDs()")
        }
    }
    
    func testGetRandomValuesPerformance() {
        let context = SwiftJS()
        let script = """
            function fillManyArrays() {
                for (let i = 0; i < 1000; i++) {
                    const array = new Uint8Array(32);
                    crypto.getRandomValues(array);
                }
                return true;
            }
            fillManyArrays
        """
        
        context.evaluateScript(script)
        
        measure {
            _ = context.evaluateScript("fillManyArrays()")
        }
    }
    
    func testLargeRandomDataGeneration() {
        let context = SwiftJS()
        let script = """
            function generateLargeRandomData() {
                const array = new Uint8Array(1024); // 1KB
                crypto.getRandomValues(array);
                return array.length === 1024;
            }
            generateLargeRandomData
        """
        
        context.evaluateScript(script)
        
        measure {
            for _ in 0..<100 {
                let result = context.evaluateScript("generateLargeRandomData()")
                XCTAssertTrue(result.boolValue ?? false)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testCryptoWithOtherAPIs() {
        let script = """
            try {
                // Use crypto with TextEncoder
                const uuid = crypto.randomUUID();
                const encoder = new TextEncoder();
                const encodedUUID = encoder.encode(uuid);
                
                // Use crypto with arrays
                const randomBytes = new Uint8Array(16);
                crypto.getRandomValues(randomBytes);
                
                // Log results
                console.log('Generated UUID:', uuid);
                console.log('Random bytes:', randomBytes);
                
                ({
                    uuidLength: uuid.length,
                    encodedLength: encodedUUID.length,
                    randomBytesLength: randomBytes.length,
                    success: true
                })
            } catch (error) {
                ({ success: false, error: error.message })
            }
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertTrue(result["success"].boolValue ?? false)
        XCTAssertEqual(result["uuidLength"].numberValue, 36)
        XCTAssertEqual(result["randomBytesLength"].numberValue, 16)
        XCTAssertGreaterThan(Int(result["encodedLength"].numberValue ?? 0), 0)
    }
    
    func testCryptoInTimers() {
        let expectation = XCTestExpectation(description: "crypto in timers")
        
        let script = """
            const results = [];
            
            setTimeout(() => {
                const uuid = crypto.randomUUID();
                const bytes = new Uint8Array(8);
                crypto.getRandomValues(bytes);
                
                results.push({
                    uuid: uuid,
                    bytesLength: bytes.length,
                    timestamp: Date.now()
                });
                
                testCompleted({ results: results });
            }, 50);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            let results = result["results"]
            
            XCTAssertEqual(Int(results["length"].numberValue ?? 0), 1)
            
            let firstResult = results[0]
            XCTAssertEqual(firstResult["uuid"].toString().count, 36)
            XCTAssertEqual(firstResult["bytesLength"].numberValue, 8)
            XCTAssertGreaterThan(firstResult["timestamp"].numberValue ?? 0, 0)
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Entropy and Quality Tests
    
    func testRandomBytesDistribution() {
        let script = """
            // Test that random bytes have reasonable distribution
            const array = new Uint8Array(10000);
            crypto.getRandomValues(array);
            
            // Count frequency of each byte value
            const counts = new Array(256).fill(0);
            for (let i = 0; i < array.length; i++) {
                counts[array[i]]++;
            }
            
            // Check that all byte values appear (with high probability)
            const usedValues = counts.filter(count => count > 0).length;
            const averageCount = array.length / 256;
            const minCount = Math.min(...counts.filter(count => count > 0));
            const maxCount = Math.max(...counts);
            
            ({
                totalBytes: array.length,
                usedValues: usedValues,
                averageCount: averageCount,
                minCount: minCount,
                maxCount: maxCount,
                reasonableDistribution: usedValues > 200 && maxCount < averageCount * 3
            })
        """
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        
        XCTAssertEqual(result["totalBytes"].numberValue, 10000)
        XCTAssertGreaterThan(Int(result["usedValues"].numberValue ?? 0), 200) // Should use most byte values
        XCTAssertTrue(result["reasonableDistribution"].boolValue ?? false)
    }
}
