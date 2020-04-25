//
//  MeasureManager.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import UIKit
import ARKit

class MeasureManager {

    private(set) var scannedObject: ScannedObject
    private var sceneView: ARSCNView
    var centerScreen: CGPoint = CGPoint.zero

    init(_ sceneView: ARSCNView) {
        self.centerScreen = sceneView.center
        self.sceneView = sceneView
        self.scannedObject = ScannedObject(sceneView)
        self.sceneView.scene.rootNode.addChildNode(self.scannedObject)
    }

    deinit {
        self.scannedObject.removeFromParentNode()
    }

    public func updateOnEveryFrame(_ frame: ARFrame) {
        DispatchQueue.main.async {
            self.scannedObject.updateOnEveryFrame(frame: frame, screenCenter: self.centerScreen)
        }
    }

    public func createBoudingBox() {
        self.scannedObject.createBoundingBoxFromGhost()
    }

    public func disPlayBox(isHidden: Bool) {
        self.scannedObject.hiddenBox(isHidden: isHidden)
    }

    public func getExtentBag() -> SIMD3<Float> {
        guard let boundingBox  = self.scannedObject.boundingBox else {
            return SIMD3.init(0, 0, 0)
        }
        return boundingBox.extent
    }

    public func resetMeasure() {
        self.scannedObject.resetScanObject()
    }

    public func showBoundingBox(isHidden: Bool) {
        self.scannedObject.hiddenBox(isHidden: isHidden)
    }

    public func disappearedBoundingbox() {
        self.scannedObject.hiddenBox(isHidden: true)
        self.scannedObject.resetFeatures()
    }
}
