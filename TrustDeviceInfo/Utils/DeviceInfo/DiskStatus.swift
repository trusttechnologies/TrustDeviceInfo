//
//  DiskStatus.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/18/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Foundation

// MARK: - DiskStatus
class DiskStatus {
    class func MBFormatter(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        
        formatter.allowedUnits = .useMB
        formatter.countStyle = .decimal
        formatter.includesUnit = false
        
        return formatter.string(fromByteCount: bytes) as String
    }
    
    class var totalDiskSpace: String {
        get {
            
            let formatter = ByteCountFormatter()
            
            formatter.allowedUnits = .useGB
            formatter.countStyle = .decimal
            formatter.includesUnit = false
            
            let totalDiskSpace = formatter.string(fromByteCount: totalDiskSpaceInBytes).replacingOccurrences(of: ",", with: ".")
            
            guard let totalDiskSpaceAsDouble = Double(totalDiskSpace) else {
                return ""
            }
            
            var totalDiskSpaceAsString = String(format: "%.f", totalDiskSpaceAsDouble)
            
            switch totalDiskSpaceAsDouble {
            case 0...33:
                totalDiskSpaceAsString = "32"
            case 34...65:
                totalDiskSpaceAsString = "64"
            case 66...129:
                totalDiskSpaceAsString = "128"
            case 130...257:
                totalDiskSpaceAsString = "256"
            case 258...513:
                totalDiskSpaceAsString = "512"
            default: break
            }
            
            return totalDiskSpaceAsString
        }
    }
    
    class var freeDiskSpace: String {
        get {
            return ByteCountFormatter.string(fromByteCount: freeDiskSpaceInBytes, countStyle: .binary)
        }
    }
    
    class var usedDiskSpace: String {
        get {
            return ByteCountFormatter.string(fromByteCount: usedDiskSpaceInBytes, countStyle: .binary)
        }
    }
    
    class var totalDiskSpaceInBytes: Int64 {
        get {
            do {
                let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
                return space!
            } catch {
                return 0
            }
        }
    }
    
    class var freeDiskSpaceInBytes: Int64 {
        get {
            do {
                let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
                return freeSpace!
            } catch {
                return 0
            }
        }
    }
    
    class var usedDiskSpaceInBytes: Int64 {
        get {
            let usedSpace = totalDiskSpaceInBytes - freeDiskSpaceInBytes
            return usedSpace
        }
    }
}
