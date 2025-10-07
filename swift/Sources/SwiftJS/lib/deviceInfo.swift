//
//  deviceInfo.swift
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

import JavaScriptCore

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import IOKit
import Crypto

#elseif canImport(UIKit)

import UIKit

#endif

@objc protocol JSDeviceInfoExport: JSExport {
    
    func identifierForVendor() -> JSValue
}

@objc final class JSDeviceInfo: NSObject, JSDeviceInfoExport {
}

extension JSDeviceInfo {
    
    func identifierForVendor() -> JSValue {
        
        let context = JSContext.current()!
        
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
        
        guard let address = copy_mac_address() else {
            return JSValue(undefinedIn: context)
        }
        var hasher = Insecure.MD5()
        hasher.update(data: address)
            let hashString = hasher.finalize().map { String(format: "%02hhx", $0) }.joined()

            // Convert MD5 hash to UUID format (8-4-4-4-12)
            let uuidString =
                "\(hashString.prefix(8))-\(hashString.dropFirst(8).prefix(4))-\(hashString.dropFirst(12).prefix(4))-\(hashString.dropFirst(16).prefix(4))-\(hashString.dropFirst(20))"

            return JSValue(
                object: uuidString,
            in: context
        )
        
#elseif canImport(UIKit)
        
        return JSValue(newPromiseIn: context) {
            while (true) {
                if let identifier = await UIDevice.current.identifierForVendor {
                    return JSValue(object: identifier.uuidString, in: context)
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
#endif
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

// Returns an object with a +1 retain count; the caller needs to release.
func io_service(named name: String, wantBuiltIn: Bool) -> io_service_t? {
    let default_port = kIOMainPortDefault
    var iterator = io_iterator_t()
    defer {
        if iterator != IO_OBJECT_NULL {
            IOObjectRelease(iterator)
        }
    }
    
    guard let matchingDict = IOBSDNameMatching(default_port, 0, name),
          IOServiceGetMatchingServices(
            default_port,
            matchingDict as CFDictionary,
            &iterator
          ) == KERN_SUCCESS,
          iterator != IO_OBJECT_NULL
    else {
        return nil
    }
    
    var candidate = IOIteratorNext(iterator)
    while candidate != IO_OBJECT_NULL {
        if let cftype = IORegistryEntryCreateCFProperty(
            candidate,
            "IOBuiltin" as CFString,
            kCFAllocatorDefault,
            0
        ) {
            let isBuiltIn = cftype.takeRetainedValue() as! CFBoolean
            if wantBuiltIn == CFBooleanGetValue(isBuiltIn) {
                return candidate
            }
        }
        
        IOObjectRelease(candidate)
        candidate = IOIteratorNext(iterator)
    }
    
    return nil
}

func copy_mac_address() -> Data? {
    // Prefer built-in network interfaces.
    // For example, an external Ethernet adaptor can displace
    // the built-in Wi-Fi as en0.
    guard let service = io_service(named: "en0", wantBuiltIn: true)
            ?? io_service(named: "en1", wantBuiltIn: true)
            ?? io_service(named: "en0", wantBuiltIn: false)
    else { return nil }
    defer { IOObjectRelease(service) }
    
    guard let cftype = IORegistryEntrySearchCFProperty(
        service,
        kIOServicePlane,
        "IOMACAddress" as CFString,
        kCFAllocatorDefault,
        IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
    else { return nil }
    
    return (cftype as! CFData) as Data
}

#endif
