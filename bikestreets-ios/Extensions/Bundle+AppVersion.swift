//
//  Bundle+AppVersion.swift
//  BikeStreets
//
//  Created by Matt Robinson on 12/8/23.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String {
        return infoDictionary!["CFBundleShortVersionString"] as! String
    }
    var buildVersionNumber: String {
        return infoDictionary!["CFBundleVersion"] as! String
    }
}
