/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 An interactive visualization of x/y/z coordinate axes for use in placing the origin/anchor point of a scanned object.
 */

import Foundation
import SceneKit
import ARKit

// Instances of this class represent the origin of the scanned 3D object - both
// logically as well as visually (as an SCNNode).
class ObjectOrigin: SCNNode {

    static let movedOutsideBoxNotification = Notification.Name("ObjectOriginMovedOutsideBoundingBox")
    static let positionChangedNotification = Notification.Name("ObjectOriginPositionChanged")
    private let axisLength: Float = 1.0
    private let axisThickness: Float = 6.0 // Axis thickness in percent of length.
    private let axisSizeToObjectSizeRatio: Float = 0.25
    private let minAxisSize: Float = 0.05
    private let maxAxisSize: Float = 0.2
    private var xAxis: ObjectOriginAxis!
    private var yAxis: ObjectOriginAxis!
    private var zAxis: ObjectOriginAxis!
    private var customModel: SCNNode?
    private var sceneView: ARSCNView
    init(extent: float3, _ sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init()

        let length = axisLength
        let thickness = (axisLength / 100.0) * axisThickness
        let radius = CGFloat(axisThickness / 2.0)
        let handleSize = CGFloat(axisLength / 4)

        xAxis = ObjectOriginAxis(axis: .x, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)
        yAxis = ObjectOriginAxis(axis: .y, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)
        zAxis = ObjectOriginAxis(axis: .z, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)

        addChildNode(xAxis)
        addChildNode(yAxis)
        addChildNode(zAxis)
        isHidden = true
    }

    @objc
    func boundingBoxExtentChanged(_ notification: Notification) {
        guard let boundingBox = notification.object as? BoundingBox else { return }
        self.adjustToExtent(boundingBox.extent)
    }

    func adjustToExtent(_ extent: float3?) {
        guard let extent = extent else {
            self.simdScale = float3(repeating: 1.0)
            xAxis.simdScale = float3(repeating: 1.0)
            yAxis.simdScale = float3(repeating: 1.0)
            zAxis.simdScale = float3(repeating: 1.0)
            return
        }

        // By default the origin's scale is 1x.
        self.simdScale = float3(repeating: 1.0)

        // Compute a good scale for the axes based on the extent of the bouning box,
        // but stay within a reasonable range.
        var axesScale = min(extent.x, extent.y, extent.z) * axisSizeToObjectSizeRatio
        axesScale = max(min(axesScale, maxAxisSize), minAxisSize)

        // Adjust the scale of the axes (not the origin itself!)
        xAxis.simdScale = float3(repeating: axesScale)
        yAxis.simdScale = float3(repeating: axesScale)
        zAxis.simdScale = float3(repeating: axesScale)

        if let model = customModel {
            // Scale the origin such that the custom 3D model fits into the given extent.
            let modelExtent = model.boundingSphere.radius * 2
            let originScale = min(extent.x, extent.y, extent.z) / modelExtent

            // Scale the origin itself, so that the scale will be preserved in the *.arobject file.
            self.simdScale = float3(repeating: originScale)

            // Correct the scale of the axes to be the same size as before
            xAxis.simdScale *= (1 / originScale)
            yAxis.simdScale *= (1 / originScale)
            zAxis.simdScale *= (1 / originScale)
        }
    }

    var isOutsideBoundingBox: Bool {
        guard let boundingBox = self.parent as? BoundingBox else { return true }

        let threshold = float3(repeating: 0.002)
        let extent = boundingBox.extent + threshold

        let pos = simdPosition
        return pos.x < -extent.x / 2 || pos.y < -extent.y / 2 || pos.z < -extent.z / 2 ||
            pos.x > extent.x / 2 || pos.y > extent.y / 2 || pos.z > extent.z / 2
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func isPartOfCustomModel(_ node: SCNNode) -> Bool {
        if node == customModel {
            return true
        }

        if let parent = node.parent {
            return isPartOfCustomModel(parent)
        }

        return false
    }

    func getxAxis() -> ObjectOriginAxis {
        return xAxis
    }

    func getyAxis() -> ObjectOriginAxis {
        return yAxis
    }

    func getzAxis() -> ObjectOriginAxis {
        return zAxis
    }

    func getCustomModel() -> SCNNode? {
        return customModel
    }

    func setCustomModel(customModel: SCNNode) {
        self.customModel = customModel
    }
}
