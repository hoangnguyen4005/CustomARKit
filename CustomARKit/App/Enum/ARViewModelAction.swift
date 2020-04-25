//
//  ARViewModelAction.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import Foundation

public enum ARViewModelAction {
    case defineObject
    case completeMeasure
    case rescanObject
}

extension ARViewModelAction: Equatable {
    public static func == (lhs: ARViewModelAction, rhs: ARViewModelAction) -> Bool {
        switch (lhs, rhs) {
        case (.defineObject, .defineObject),
             (.completeMeasure, .completeMeasure),
             (.rescanObject, .rescanObject):
            return true
        default:
            return false
        }
    }
}
