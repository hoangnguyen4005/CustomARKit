//
//  ARStateDetect.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import Foundation

public enum ARStateDetect {
    case notReadyMeasure
    case readyMeasure
    case scanToMeasure
    case readyToRelease
}

extension ARStateDetect: Equatable {
    public static func == (lhs: ARStateDetect, rhs: ARStateDetect) -> Bool {
        switch (lhs, rhs) {
        case (.notReadyMeasure, .notReadyMeasure),
             (.readyMeasure, .readyMeasure),
             (.scanToMeasure, .scanToMeasure),
             (.readyToRelease, .readyToRelease):
            return true
        default:
            return false
        }
    }
}
