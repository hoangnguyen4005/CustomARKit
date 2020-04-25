//
//  ARMeasureEvent.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import Foundation

public enum ARMeasureEvent {
    case complete
    case notSuitable
    case dismissARView
    case goToMeasureView
    case backDisclaimView
}

extension ARMeasureEvent: Equatable {
    public static func == (lhs: ARMeasureEvent, rhs: ARMeasureEvent) -> Bool {
        switch (lhs, rhs) {
        case (.complete, .complete),
             (.notSuitable, .notSuitable),
             (.dismissARView, .dismissARView),
             (.backDisclaimView, .backDisclaimView),
             (.goToMeasureView, .goToMeasureView):
            return true
        default:
            return false
        }
    }
}
