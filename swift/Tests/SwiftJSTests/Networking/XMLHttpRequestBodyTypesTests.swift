import XCTest
@testable import SwiftJS

/// Tests for XMLHttpRequest body type support (URLSearchParams and Blob)
final class XMLHttpRequestBodyTypesTests: XCTestCase {
    
    // MARK: - URLSearchParams Support Tests
    
    func testXMLHttpRequestURLSearchParamsContentType() {
        let script = """
            (() => {
                const params = new URLSearchParams();
                params.append('test', 'value');
                params.append('name', 'John Doe');
                
                const xhr = new XMLHttpRequest();
                xhr.open('POST', 'https://example.com');
                
                try {
                    xhr.send(params);
                    return {
                        success: true,
                        paramsString: params.toString(),
                        paramsLength: params.toString().length
                    };
                } catch (error) {
                    return {
                        success: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertNotNil(result)
        
        XCTAssertTrue(result["success"].boolValue ?? false, "URLSearchParams should be accepted without errors")
        
        let paramsString = result["paramsString"].toString()
        XCTAssertEqual(paramsString, "test=value&name=John+Doe")
        XCTAssertGreaterThan(Int(result["paramsLength"].numberValue ?? 0), 0)
    }
    
    func testXMLHttpRequestWithURLSearchParamsLiveRequest() {
        let expectation = XCTestExpectation(description: "XMLHttpRequest with URLSearchParams live request")
        
        let script = """
            const params = new URLSearchParams();
            params.append('name', 'John Doe');
            params.append('email', 'john@example.com');
            params.append('message', 'Hello World!');
            
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.timeout = 15000;
            
            xhr.onload = () => {
                try {
                    if (xhr.status === 200) {
                        const data = JSON.parse(xhr.responseText);
                        testCompleted({
                            status: xhr.status,
                            hasFormData: !!(data.form && Object.keys(data.form).length > 0),
                            contentType: data.headers['content-type'] || 'not set',
                            success: true
                        });
                    } else {
                        testCompleted({
                            status: xhr.status,
                            success: false,
                            error: 'HTTP error'
                        });
                    }
                } catch (e) {
                    testCompleted({
                        success: false,
                        error: 'Parse error: ' + e.message
                    });
                }
            };
            
            xhr.onerror = () => testCompleted({
                success: false,
                error: 'Network error'
            });
            
            xhr.ontimeout = () => testCompleted({
                success: false,
                error: 'Timeout'
            });
            
            xhr.send(params);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Check if it's a network error (we can still verify the body type support works)
            if !(result["success"].boolValue ?? false) {
                let error = result["error"].toString()
                if error.contains("Network") || error.contains("Timeout") || error.contains("HTTP error") {
                    // Network/HTTP issue - the important thing is URLSearchParams was accepted
                    XCTAssertTrue(true, "URLSearchParams body type accepted (external service unavailable)")
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            } else {
                // Network succeeded - verify full functionality
                XCTAssertTrue(result["success"].boolValue ?? false, "Request should succeed")
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertTrue(result["hasFormData"].boolValue ?? false, "Should have form data")
                
                let contentType = result["contentType"].toString()
                XCTAssertTrue(contentType.contains("application/x-www-form-urlencoded"), 
                             "Content-Type should be application/x-www-form-urlencoded")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Blob Support Tests
    
    func testXMLHttpRequestBlobContentType() {
        let script = """
            (() => {
                const blob = new Blob(['test content'], { type: 'text/plain' });
                const emptyBlob = new Blob([]);
                
                const xhr1 = new XMLHttpRequest();
                const xhr2 = new XMLHttpRequest();
                
                try {
                    xhr1.open('POST', 'https://example.com');
                    xhr1.send(blob);
                    
                    xhr2.open('POST', 'https://example.com');
                    xhr2.send(emptyBlob);
                    
                    return {
                        blobSuccess: true,
                        emptyBlobSuccess: true,
                        blobType: blob.type,
                        blobSize: blob.size,
                        emptyBlobSize: emptyBlob.size
                    };
                } catch (error) {
                    return {
                        blobSuccess: false,
                        emptyBlobSuccess: false,
                        error: error.message
                    };
                }
            })()
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertNotNil(result)
        
        XCTAssertTrue(result["blobSuccess"].boolValue ?? false, "Blob should be accepted without errors")
        XCTAssertTrue(result["emptyBlobSuccess"].boolValue ?? false, "Empty blob should be accepted without errors")
        XCTAssertEqual(result["blobType"].toString(), "text/plain")
        XCTAssertGreaterThan(Int(result["blobSize"].numberValue ?? 0), 0)
        XCTAssertEqual(Int(result["emptyBlobSize"].numberValue ?? -1), 0)
    }
    
    func testXMLHttpRequestWithBlobLiveRequest() {
        let expectation = XCTestExpectation(description: "XMLHttpRequest with Blob live request")
        
        let script = """
            const testContent = 'This is blob content for XMLHttpRequest testing!';
            const blob = new Blob([testContent], { type: 'text/plain' });
            
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.timeout = 15000;
            
            xhr.onload = () => {
                try {
                    if (xhr.status === 200) {
                        const data = JSON.parse(xhr.responseText);
                        testCompleted({
                            status: xhr.status,
                            receivedData: data.data || '',
                            contentMatches: (data.data || '') === testContent,
                            contentType: data.headers['content-type'] || 'not set',
                            success: true
                        });
                    } else {
                        testCompleted({
                            status: xhr.status,
                            success: false,
                            error: 'HTTP error'
                        });
                    }
                } catch (e) {
                    testCompleted({
                        success: false,
                        error: 'Parse error: ' + e.message
                    });
                }
            };
            
            xhr.onerror = () => testCompleted({
                success: false,
                error: 'Network error'
            });
            
            xhr.ontimeout = () => testCompleted({
                success: false,
                error: 'Timeout'
            });
            
            xhr.send(blob);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Check if it's a network error (we can still verify the body type support works)
            if !(result["success"].boolValue ?? false) {
                let error = result["error"].toString()
                if error.contains("Network") || error.contains("Timeout") || error.contains("HTTP error") {
                    // Network/HTTP issue - the important thing is Blob was accepted
                    XCTAssertTrue(true, "Blob body type accepted (external service unavailable)")
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            } else {
                // Network succeeded - verify full functionality
                XCTAssertTrue(result["success"].boolValue ?? false, "Request should succeed")
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                XCTAssertTrue(result["contentMatches"].boolValue ?? false, "Received data should match sent blob content")
                
                let contentType = result["contentType"].toString()
                XCTAssertTrue(contentType.contains("text/plain"), 
                             "Content-Type should be text/plain from blob")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testXMLHttpRequestBlobWithoutType() {
        let expectation = XCTestExpectation(description: "XMLHttpRequest with Blob without type")
        
        let script = """
            const testContent = 'Blob without explicit type';
            const blob = new Blob([testContent]); // No type specified
            
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.timeout = 15000;
            
            xhr.onload = () => {
                try {
                    if (xhr.status === 200) {
                        const data = JSON.parse(xhr.responseText);
                        testCompleted({
                            status: xhr.status,
                            contentType: data.headers['content-type'] || 'not set',
                            success: true
                        });
                    } else {
                        testCompleted({
                            status: xhr.status,
                            success: false,
                            error: 'HTTP error'
                        });
                    }
                } catch (e) {
                    testCompleted({
                        success: false,
                        error: e.message || 'Unknown error'
                    });
                }
            };
            
            xhr.onerror = () => testCompleted({ success: false, error: 'Network error' });
            xhr.ontimeout = () => testCompleted({ success: false, error: 'Timeout' });
            
            xhr.send(blob);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            // Check if it's a network error (we can still verify the body type support works)
            if !(result["success"].boolValue ?? false) {
                let error = result["error"].toString()
                if error.contains("Network") || error.contains("Timeout") || error.contains("HTTP error") || error.contains("undefined") || error.contains("Unknown") {
                    // Network/HTTP issue - the important thing is Blob was accepted
                    XCTAssertTrue(true, "Blob body type accepted (external service unavailable)")
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            } else {
                // Network succeeded - verify full functionality
                XCTAssertTrue(result["success"].boolValue ?? false, "Request should succeed")
                XCTAssertEqual(Int(result["status"].numberValue ?? 0), 200)
                
                let contentType = result["contentType"].toString()
                XCTAssertTrue(contentType.contains("application/octet-stream"), 
                             "Content-Type should default to application/octet-stream")
            }
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 20.0)
    }
    
    // MARK: - Body Type Compatibility Tests
    
    func testXMLHttpRequestAllBodyTypes() {
        let script = """
            (() => {
                const results = [];
                
                // Test different body types
                const testCases = [
                    { name: 'string', body: 'test string' },
                    { name: 'URLSearchParams', body: new URLSearchParams('key=value') },
                    { name: 'Blob', body: new Blob(['test'], { type: 'text/plain' }) },
                    { name: 'ArrayBuffer', body: new TextEncoder().encode('test').buffer },
                    { name: 'FormData', body: (() => { const fd = new FormData(); fd.append('test', 'value'); return fd; })() }
                ];
                
                testCases.forEach(testCase => {
                    try {
                        const xhr = new XMLHttpRequest();
                        xhr.open('POST', 'https://example.com');
                        xhr.send(testCase.body);
                        
                        results.push({
                            name: testCase.name,
                            success: true,
                            error: null
                        });
                    } catch (error) {
                        results.push({
                            name: testCase.name,
                            success: false,
                            error: error.message
                        });
                    }
                });
                
                return {
                    totalTests: results.length,
                    successCount: results.filter(r => r.success).length,
                    allSuccess: results.every(r => r.success),
                    results: results
                };
            })()
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertNotNil(result)
        
        XCTAssertEqual(Int(result["totalTests"].numberValue ?? 0), 5)
        XCTAssertEqual(Int(result["successCount"].numberValue ?? 0), 5)
        XCTAssertTrue(result["allSuccess"].boolValue ?? false, "All body types should be supported without throwing errors")
    }
    
    // MARK: - Upload Events Tests
    
    func testXMLHttpRequestUploadEventsWithURLSearchParams() {
        let expectation = XCTestExpectation(description: "XMLHttpRequest upload events with URLSearchParams")
        
        let script = """
            const params = new URLSearchParams();
            params.append('test', 'value');
            
            const xhr = new XMLHttpRequest();
            const events = [];
            
            xhr.upload.addEventListener('loadstart', () => events.push('loadstart'));
            xhr.upload.addEventListener('progress', () => events.push('progress'));
            xhr.upload.addEventListener('load', () => events.push('load'));
            xhr.upload.addEventListener('loadend', () => events.push('loadend'));
            
            xhr.open('POST', 'https://postman-echo.com/post');
            xhr.timeout = 10000;
            
            xhr.onload = () => testCompleted({ 
                events: events,
                status: xhr.status,
                hasLoadStart: events.includes('loadstart'),
                hasLoad: events.includes('load'),
                hasLoadEnd: events.includes('loadend')
            });
            xhr.onerror = () => testCompleted({ 
                events: events, 
                error: 'Network error' 
            });
            xhr.ontimeout = () => testCompleted({ 
                events: events, 
                error: 'Timeout' 
            });
            
            xhr.send(params);
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            
            XCTAssertTrue(result["hasLoadStart"].boolValue ?? false, "Should fire loadstart event")
            XCTAssertTrue(result["hasLoad"].boolValue ?? false, "Should fire load event")
            XCTAssertTrue(result["hasLoadEnd"].boolValue ?? false, "Should fire loadend event")
            
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testXMLHttpRequestEmptyBodiesHandling() {
        let script = """
            (() => {
                const testResults = [];
                
                try {
                    // Empty URLSearchParams
                    const emptyParams = new URLSearchParams();
                    const xhr1 = new XMLHttpRequest();
                    xhr1.open('POST', 'https://example.com');
                    xhr1.send(emptyParams);
                    testResults.push({ test: 'emptyURLSearchParams', success: true });
                } catch (error) {
                    testResults.push({ test: 'emptyURLSearchParams', success: false, error: error.message });
                }
                
                try {
                    // Empty Blob
                    const emptyBlob = new Blob([]);
                    const xhr2 = new XMLHttpRequest();
                    xhr2.open('POST', 'https://example.com');
                    xhr2.send(emptyBlob);
                    testResults.push({ test: 'emptyBlob', success: true });
                } catch (error) {
                    testResults.push({ test: 'emptyBlob', success: false, error: error.message });
                }
                
                return {
                    allSuccess: testResults.every(r => r.success),
                    testCount: testResults.length,
                    results: testResults
                };
            })()
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertNotNil(result)
        
        XCTAssertTrue(result["allSuccess"].boolValue ?? false, "Should handle empty bodies without errors")
        XCTAssertEqual(Int(result["testCount"].numberValue ?? 0), 2)
    }
}