//
//  Sysctl.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/18/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Foundation

// MARK: - Sysctl
struct Sysctl {
    enum Error: Swift.Error {
        case unknown
        case malformedUTF8
        case invalidSize
        case posixError(POSIXErrorCode)
    }
    
    static func dataForKeys(_ keys: [Int32]) throws -> [Int8] {
        return try keys.withUnsafeBufferPointer() { keysPointer throws -> [Int8] in
            var requiredSize = 0
            let preFlightResult = Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), nil, &requiredSize, nil, 0)
            
            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map {
                    print($0.rawValue)
                    return Error.posixError($0)
                    } ?? Error.unknown
            }
            
            let data = Array<Int8>(repeating: 0, count: requiredSize)
            let result = data.withUnsafeBufferPointer() { dataBuffer -> Int32 in
                return Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress), &requiredSize, nil, 0)
            }
            
            if result != 0 {
                throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
            }
            
            return data
        }
    }
    
    static func keysForName(_ name: String) throws -> [Int32] {
        var keysBufferSize = Int(CTL_MAXNAME)
        var keysBuffer = Array<Int32>(repeating: 0, count: keysBufferSize)
        
        try keysBuffer.withUnsafeMutableBufferPointer { (lbp: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString { (nbp: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nbp, lbp.baseAddress, &keysBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
                }
            }
        }
        
        if keysBuffer.count > keysBufferSize {
            keysBuffer.removeSubrange(keysBufferSize..<keysBuffer.count)
        }
        
        return keysBuffer
    }
    
    static func valueOfType<T>(_ type: T.Type, forKeys keys: [Int32]) throws -> T {
        let buffer = try dataForKeys(keys)
        if buffer.count != MemoryLayout<T>.size {
            throw Error.invalidSize
        }
        return try buffer.withUnsafeBufferPointer() { bufferPtr throws -> T in
            guard let baseAddress = bufferPtr.baseAddress else { throw Error.unknown }
            return baseAddress.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
        }
    }
    
    static func valueOfType<T>(_ type: T.Type, forKeys keys: Int32...) throws -> T {
        return try valueOfType(type, forKeys: keys)
    }
    
    static func valueOfType<T>(_ type: T.Type, forName name: String) throws -> T {
        return try valueOfType(type, forKeys: keysForName(name))
    }
    
    static func stringForKeys(_ keys: [Int32]) throws -> String {
        let optionalString = try dataForKeys(keys).withUnsafeBufferPointer() { dataPointer -> String? in
            dataPointer.baseAddress.flatMap { String(validatingUTF8: $0) }
        }
        guard let s = optionalString else {
            throw Error.malformedUTF8
        }
        return s
    }
    
    static func stringForKeys(_ keys: Int32...) throws -> String {
        return try stringForKeys(keys)
    }
    
    static func stringForName(_ name: String) throws -> String {
        return try stringForKeys(keysForName(name))
    }
    
    static var hostName: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_HOSTNAME]) }
    
    static var machine: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return try! Sysctl.stringForKeys([CTL_HW, HW_MODEL])
        #else
        return try! Sysctl.stringForKeys([CTL_HW, HW_MACHINE])
        #endif
    }
    
    static var model: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return try! Sysctl.stringForKeys([CTL_HW, HW_MACHINE])
        #else
        return try! Sysctl.stringForKeys([CTL_HW, HW_MODEL])
        #endif
    }
    
    static var activeCPUs: Int32 { return try! Sysctl.valueOfType(Int32.self, forKeys: [CTL_HW, HW_AVAILCPU]) }
    
    static var osRelease: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSRELEASE]) }
    
    static var osType: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSTYPE]) }
    
    static var osVersion: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSVERSION]) }
    
    static var version: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_VERSION]) }
    
    #if os(macOS)
    static var osRev: Int32 { return try! Sysctl.valueOfType(Int32.self, forKeys: [CTL_KERN, KERN_OSREV]) }
    
    static var cpuFreq: Int64 { return try! Sysctl.valueOfType(Int64.self, forName: "hw.cpufrequency") }
    
    static var memSize: UInt64 { return try! Sysctl.valueOfType(UInt64.self, forKeys: [CTL_HW, HW_MEMSIZE]) }
    #endif
}
