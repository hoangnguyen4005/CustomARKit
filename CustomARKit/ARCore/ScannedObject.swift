/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 A representation of the object being scanned.
 */

import Foundation
import SceneKit
import ARKit

class ScannedObject: SCNNode {

    private var hasWarnedAboutLowLight = false
    private(set) var origin: ObjectOrigin?
    private(set) var boundingBox: BoundingBox?
    private(set) var ghostBoundingBox: BoundingBox?

    static let tooDarkEnvironment = Notification.Name("TooDarkEnvironment")
    static let positionChangedNotification = Notification.Name("ScannedObjectPositionChanged")
    static let boundingBoxCreatedNotification = Notification.Name("BoundingBoxWasCreated")
    static let ghostBoundingBoxCreatedNotification = Notification.Name("GhostBoundingBoxWasCreated")
    static let ghostBoundingBoxRemovedNotification = Notification.Name("GhostBoundingBoxWasRemoved")
    static let boundingBoxScanningProgressNotification = Notification.Name("BoundingBoxScanningProgress")

    private var sceneView: ARSCNView
    override var simdPosition: float3 {
        didSet {
            NotificationCenter.default.post(name: ScannedObject.positionChangedNotification,
                                            object: self)
        }
    }

    var eitherBoundingBox: BoundingBox? {
        return boundingBox != nil ? boundingBox : ghostBoundingBox
    }

    init(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init()
    }

    func setGhostBoundingBox(ghostBox: BoundingBox) {
        self.ghostBoundingBox = ghostBox
    }

    func rotateOnYAxis(by angle: Float) {
        self.simdLocalRotate(by: simd_quatf(angle: angle, axis: .y))
        self.boundingBox?.hasBeenAdjustedByUser = true
    }

    func resetScanObject() {
        self.boundingBox?.resetFeaturePoints()
        self.ghostBoundingBox?.resetFeaturePoints()

        self.boundingBox?.cleanup()
        self.boundingBox?.removeFromParentNode()
        self.boundingBox = nil

        self.ghostBoundingBox?.cleanup()
        self.ghostBoundingBox?.removeFromParentNode()
        self.ghostBoundingBox = nil

        hasWarnedAboutLowLight = false
    }

    func hiddenBox(isHidden: Bool = true) {
        self.boundingBox?.isHidden = isHidden
        self.ghostBoundingBox?.isHidden = isHidden
    }

    func resetFeatures() {
        self.boundingBox?.resetFeaturePoints()
        self.ghostBoundingBox?.resetFeaturePoints()
    }

    func createBoundingBoxFromGhost() {
        if let boundingBox = self.ghostBoundingBox {
            boundingBox.opacity = 1.0
            self.boundingBox = boundingBox
            self.constraints = nil
            self.ghostBoundingBox?.cleanup()
            self.ghostBoundingBox?.removeFromParentNode()
            self.ghostBoundingBox = nil
            self.addChildNode(self.boundingBox!)

            let origin = ObjectOrigin(extent: boundingBox.extent, sceneView)
            boundingBox.addChildNode(origin)
            self.origin = origin

            NotificationCenter.default.post(name: ScannedObject.boundingBoxCreatedNotification, object: nil)
        }
    }

    func fitOverPointCloud(_ pointCloud: ARPointCloud, screenCenter: CGPoint) {
        // Do the automatic adjustment of the bounding box only if the user
        // hasn't adjusted it yet.
        guard let boundingBox = self.boundingBox, !boundingBox.hasBeenAdjustedByUser else { return }

        let hitTestResults = sceneView.hitTest(screenCenter, types: .featurePoint)
        guard !hitTestResults.isEmpty else { return }

        let userFocusPoint = hitTestResults[0].worldTransform.position
        boundingBox.fitOverPointCloud(pointCloud, focusPoint: userFocusPoint)
    }

    func tryToAlignWithPlanes(_ anchors: [ARAnchor]) {
        if let boundingBox = self.boundingBox {
            boundingBox.tryToAlignWithPlanes(anchors)
        }
    }

    private func updateOrCreateGhostBoundingBox(screenCenter: CGPoint) {
        // Perform a hit test against the feature point cloud.
        guard let result = sceneView.smartHitTest(screenCenter) else {
            if let ghostBoundingBox = ghostBoundingBox {
                ghostBoundingBox.cleanup()
                ghostBoundingBox.removeFromParentNode()
                self.ghostBoundingBox = nil
                NotificationCenter.default.post(name: ScannedObject.ghostBoundingBoxRemovedNotification, object: nil)
            }
            return
        }

        let newExtent = Float(result.distance / 4)

        // Set the position of scanned object to a point on the ray which is offset
        // from the hit test result by half of the bounding boxes' extent.
        let cameraToHit = result.worldTransform.position - sceneView.pointOfView!.simdWorldPosition
        let normalizedDirection = normalize(cameraToHit)
        let boundingBoxOffset = normalizedDirection * newExtent / 2
        self.simdWorldPosition = result.worldTransform.position + boundingBoxOffset

        if let boundingBox = ghostBoundingBox {
            boundingBox.extent = float3(newExtent, 0.0, newExtent)
            // Change the orientation of the bounding box to always face the user.
            if let currentFrame = sceneView.session.currentFrame {
                eulerAngles.y = currentFrame.camera.eulerAngles.y
            }
        } else {
            let boundingBox = BoundingBox(sceneView)
            boundingBox.opacity = 0.5
            self.addChildNode(boundingBox)
            boundingBox.extent = float3(repeating: newExtent)

            ghostBoundingBox = boundingBox
            NotificationCenter.default.post(name: ScannedObject.ghostBoundingBoxCreatedNotification, object: nil)
        }
    }

    func updatePosition(_ worldPos: float3) {
        let offset = worldPos - self.simdWorldPosition
        self.simdWorldPosition = worldPos

        if let boundingBox = boundingBox {
            boundingBox.simdWorldPosition -= offset
        }
    }

    func updateOnEveryFrame(frame: ARFrame, screenCenter: CGPoint) {
        if let lightEstimate = frame.lightEstimate, lightEstimate.ambientIntensity < 500, !hasWarnedAboutLowLight {
            hasWarnedAboutLowLight = true
            NotificationCenter.default.post(name: ScannedObject.tooDarkEnvironment, object: nil)
            return
        }

        if let points = frame.rawFeaturePoints {
            self.fitOverPointCloud(points, screenCenter: self.sceneView.center)
        }

        self.updateOnEveryFrame(screenCenter: screenCenter)
    }

    // updateOnEveryFrame
    func updateOnEveryFrame(screenCenter: CGPoint) {
        if let boundingBox = boundingBox {
            boundingBox.updateOnEveryFrame()
            if boundingBox.simdPosition != float3(repeating: 0) {
                updatePosition(boundingBox.simdWorldPosition)
            }

            // update scanning progress
            let progressDataDict: [String: Float] = ["progress": boundingBox.getScanningProgress()]
            NotificationCenter.default.post(name: ScannedObject.boundingBoxScanningProgressNotification, object: nil, userInfo: progressDataDict)

        } else {
            updateOrCreateGhostBoundingBox(screenCenter: screenCenter)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
