import XCTest
@testable import SwiftJS

/// Tests for FormData streaming detection and handling
final class FormDataStreamingTests: XCTestCase {
    
    // MARK: - FormData Streaming Detection Tests
    
    func testFormDataStreamingDetection() {
        let script = """
            (() => {
                // Test traditional FormData
                const traditionalFormData = new FormData();
                traditionalFormData.append('name', 'John');
                traditionalFormData.append('email', 'john@example.com');
                
                // Test FormData with streaming values (Blob)
                const streamingFormData = new FormData();
                streamingFormData.append('name', 'John');
                streamingFormData.append('file', new Blob(['test content'], { type: 'text/plain' }));
                
                // Test FormData with File
                const fileFormData = new FormData();
                fileFormData.append('name', 'John');
                fileFormData.append('upload', new File(['file content'], 'test.txt', { type: 'text/plain' }));
                
                return {
                    traditionalWorks: true,
                    streamingWorks: true,
                    fileWorks: true
                };
            })()
        """
        
        let context = SwiftJS()
        let result = context.evaluateScript(script)
        XCTAssertNotNil(result)
        
        XCTAssertTrue(result["traditionalWorks"].boolValue ?? false)
        XCTAssertTrue(result["streamingWorks"].boolValue ?? false)
        XCTAssertTrue(result["fileWorks"].boolValue ?? false)
    }
    
    // MARK: - Request.arrayBuffer() Tests
    
    func testRequestArrayBufferWithStreamingFormData() {
        let expectation = XCTestExpectation(description: "Request arrayBuffer with streaming FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('file', new Blob(['This is blob content'], { type: 'text/plain' }));
            
            const request = new Request('https://example.com', {
                method: 'POST',
                body: formData
            });
            
            request.arrayBuffer().then(buffer => {
                const text = new TextDecoder().decode(buffer);
                testCompleted({
                    containsText: text.includes('John Doe'),
                    containsBlobContent: text.includes('This is blob content'),
                    hasMultipartHeaders: text.includes('Content-Disposition'),
                    notPlaceholder: !text.includes('[object Blob]')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsText"].boolValue ?? false)
            XCTAssertTrue(result["containsBlobContent"].boolValue ?? false, "Should contain actual blob content, not placeholder")
            XCTAssertTrue(result["hasMultipartHeaders"].boolValue ?? false)
            XCTAssertTrue(result["notPlaceholder"].boolValue ?? false, "Should not contain '[object Blob]' placeholder")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRequestArrayBufferWithTraditionalFormData() {
        let expectation = XCTestExpectation(description: "Request arrayBuffer with traditional FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('age', '30');
            
            const request = new Request('https://example.com', {
                method: 'POST',
                body: formData
            });
            
            request.arrayBuffer().then(buffer => {
                const text = new TextDecoder().decode(buffer);
                testCompleted({
                    containsText: text.includes('John Doe'),
                    containsNumber: text.includes('30'),
                    hasMultipartHeaders: text.includes('Content-Disposition')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsText"].boolValue ?? false)
            XCTAssertTrue(result["containsNumber"].boolValue ?? false)
            XCTAssertTrue(result["hasMultipartHeaders"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Request.text() Tests
    
    func testRequestTextWithStreamingFormData() {
        let expectation = XCTestExpectation(description: "Request text with streaming FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('file', new Blob(['This is blob content'], { type: 'text/plain' }));
            
            const request = new Request('https://example.com', {
                method: 'POST',
                body: formData
            });
            
            request.text().then(text => {
                testCompleted({
                    containsText: text.includes('John Doe'),
                    containsBlobContent: text.includes('This is blob content'),
                    notPlaceholder: !text.includes('[object Blob]')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsText"].boolValue ?? false)
            XCTAssertTrue(result["containsBlobContent"].boolValue ?? false, "Should contain actual blob content, not placeholder")
            XCTAssertTrue(result["notPlaceholder"].boolValue ?? false, "Should not contain '[object Blob]' placeholder")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Response Tests
    
    func testResponseTextWithStreamingFormData() {
        let expectation = XCTestExpectation(description: "Response text with streaming FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('file', new Blob(['This is blob content'], { type: 'text/plain' }));
            
            const response = new Response(formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });
            
            response.text().then(text => {
                testCompleted({
                    containsText: text.includes('John Doe'),
                    containsBlobContent: text.includes('This is blob content'),
                    notPlaceholder: !text.includes('[object Blob]')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsText"].boolValue ?? false)
            XCTAssertTrue(result["containsBlobContent"].boolValue ?? false, "Should contain actual blob content, not placeholder")
            XCTAssertTrue(result["notPlaceholder"].boolValue ?? false, "Should not contain '[object Blob]' placeholder")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResponseArrayBufferWithStreamingFormData() {
        let expectation = XCTestExpectation(description: "Response arrayBuffer with streaming FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('file', new Blob(['This is blob content'], { type: 'text/plain' }));
            
            const response = new Response(formData);
            
            response.arrayBuffer().then(buffer => {
                const text = new TextDecoder().decode(buffer);
                testCompleted({
                    containsText: text.includes('John Doe'),
                    containsBlobContent: text.includes('This is blob content'),
                    notPlaceholder: !text.includes('[object Blob]')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsText"].boolValue ?? false)
            XCTAssertTrue(result["containsBlobContent"].boolValue ?? false, "Should contain actual blob content, not placeholder")
            XCTAssertTrue(result["notPlaceholder"].boolValue ?? false, "Should not contain '[object Blob]' placeholder")
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityWithExistingFormData() {
        let expectation = XCTestExpectation(description: "Backward compatibility with existing FormData")
        
        let script = """
            const formData = new FormData();
            formData.append('name', 'John Doe');
            formData.append('email', 'john@example.com');
            
            const request = new Request('https://example.com', {
                method: 'POST',
                body: formData
            });
            
            request.text().then(text => {
                testCompleted({
                    containsName: text.includes('John Doe'),
                    containsEmail: text.includes('john@example.com'),
                    hasProperMultipart: text.includes('Content-Disposition: form-data')
                });
            }).catch(error => {
                testCompleted({ error: error.message });
            });
        """
        
        let context = SwiftJS()
        context.globalObject["testCompleted"] = SwiftJS.Value(in: context) { args, this in
            let result = args[0]
            XCTAssertFalse(result["error"].isString, result["error"].toString())
            XCTAssertTrue(result["containsName"].boolValue ?? false)
            XCTAssertTrue(result["containsEmail"].boolValue ?? false)
            XCTAssertTrue(result["hasProperMultipart"].boolValue ?? false)
            expectation.fulfill()
            return SwiftJS.Value.undefined
        }
        
        context.evaluateScript(script)
        wait(for: [expectation], timeout: 10.0)
    }
}