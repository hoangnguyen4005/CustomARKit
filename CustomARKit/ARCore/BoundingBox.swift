/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 An interactive visualization of a bounding box in 3D space with movement and resizing controls.
 */

import Foundation
import ARKit

class BoundingBox: SCNNode {
    let maxProgress: Float = 0.99
    static let extentChangedNotification = Notification.Name("BoundingBoxExtentChanged")
    static let positionChangedNotification = Notification.Name("BoundingBoxPositionChanged")

    var extent: SIMD3 = float3(0.1, 0.1, 0.1) {
        didSet {
            extent = max(extent, minSize)
            updateVisualization()
            NotificationCenter.default.post(name: BoundingBox.extentChangedNotification,
                                            object: self)
        }
    }

    override var simdPosition: float3 {
        willSet(newValue) {
            if distance(newValue, simdPosition) > 0.001 {
                NotificationCenter.default.post(name: BoundingBox.positionChangedNotification,
                                                object: self)
            }
        }
    }

    var lastPoints: [float3] = [float3(0, 0, 0)]
    var lastExtent: float3 = float3(0, 0, 0)
    var featuresNode: [SCNNode] = []

    var hasBeenAdjustedByUser = false
    private var maxDistanceToFocusPoint: Float = 0.05
    private var minSize: Float = 0.001
    public var wireframe: Wireframe?
    private var sidesNode = SCNNode()
    private var sides: [BoundingBoxSide.Position: BoundingBoxSide] = [:]
    private var color = UIColor.white
    private var cameraRaysAndHitLocations: [(ray: Ray, hitLocation: float3)] = []
    private var sceneView: ARSCNView

    init(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init()
        updateVisualization()
    }

    func fitOverPointCloud(_ pointCloud: ARPointCloud, focusPoint: float3?) {
        var filteredPoints: [float3] = []
        for point in pointCloud.points {
            if let focus = focusPoint {
                // Skip this point if it is more than maxDistanceToFocusPoint meters away from the focus point.
                let distanceToFocusPoint = length(point - focus)
                if distanceToFocusPoint > maxDistanceToFocusPoint {
                    continue
                }
            }
            // Skip this point if it is an outlier (not at least 3 other points closer than 3 cm)
            var nearbyPoints = 0
            for otherPoint in pointCloud.points {
                if distance(point, otherPoint) < 0.03 {
                    nearbyPoints += 1
                    if nearbyPoints >= 4 {
                        filteredPoints.append(point)
                        break
                    }
                }
            }
        }

        guard !filteredPoints.isEmpty else { return }
        var localMin = -extent / 2
        var localMax = extent / 2
        for point in filteredPoints {
            // The bounding box is in local coordinates, so convert point to local, too.
            let localPoint = self.simdConvertPosition(point, from: nil)
            localMin = min(localMin, localPoint)
            localMax = max(localMax, localPoint)
        }
        // Update the position & extent of the bounding box based on the new min & max values.
        self.simdPosition += (localMax + localMin) / 2
        self.extent = localMax - localMin

        // Draw feature point
        drawFeaturePoint(filteredPoints: filteredPoints, focusPoint: focusPoint)
    }

    /// draw feature point
    func drawFeaturePoint(filteredPoints: [float3], focusPoint: float3?) {
        if self.extent == self.lastExtent {
            return
        }
        self.lastExtent = self.extent
        let randomIndex = Int.random(in: 0..<filteredPoints.count)
        let randomPoint =  filteredPoints[randomIndex]
        let lastPoint = self.lastPoints.last!
        let distanceDt = length(randomPoint - lastPoint)
        let distanceTh = Float(0.05) // Condition 2 points need have distance 5.0 cm can create 1 line

        if distanceDt > distanceTh {
            let constSizeBox: CGFloat = 0.005
            let fpBox = SCNBox(width: constSizeBox, height: constSizeBox, length: constSizeBox, chamferRadius: 0)
            let boxNode = SCNNode(geometry: fpBox)
            boxNode.updateMaterials(color: .white)
            boxNode.simdPosition = randomPoint
            self.sceneView.scene.rootNode.addChildNode(boxNode)
            self.featuresNode.append(boxNode)

            // create connection (create line connect between points)
            for point in self.lastPoints {
                if  point != float3(0, 0, 0) && distanceDt < 0.4 && distanceDt > 0.04 {
                    let line = SCNGeometry.line(from: SCNVector3(point), to: SCNVector3(randomPoint))
                    let lineNode = SCNNode(geometry: line)
                    lineNode.position = SCNVector3Zero
                    self.sceneView.scene.rootNode.addChildNode(lineNode)
                    self.featuresNode.append(lineNode)
                }
            }
            //Update last point
            self.lastPoints.append(randomPoint)
            if self.lastPoints.count > 3 {
                self.lastPoints.removeFirst()
            }
        }
    }

    func getScanningProgress() -> Float {
        let totalPoint = Float(36)
        var progress: Float = Float(self.featuresNode.count)/totalPoint
        progress = progress > maxProgress ? maxProgress : progress
        return Float(progress)
    }

    func resetFeaturePoints() {
        for node in self.featuresNode {
            node.cleanup()
            node.removeFromParentNode()
        }
        self.featuresNode.removeAll()
    }

    private func updateVisualization() {
        self.updateSides()
        self.updateWireframe()
    }

    private func updateWireframe() {
        // When this method is called the first time, create the wireframe and add them as child node.
        guard let wireframe = self.wireframe else {
            let wireframe = Wireframe(extent: self.extent, color: color)
            self.addChildNode(wireframe)
            self.wireframe = wireframe
            return
        }

        // Otherwise just update the wireframe's size and position.
        wireframe.update(extent: self.extent)
    }

    private func updateSides() {
        // When this method is called the first time, create the sides and add them to the sidesNode.
        guard sides.count == 6 else {
            createSides()
            self.addChildNode(sidesNode)
            return
        }

        // Otherwise just update the geometries's size and position.
        sides.forEach { $0.value.update(boundingBoxExtent: self.extent) }
    }

    private func createSides() {
        for position in BoundingBoxSide.Position.allCases {
            self.sides[position] = BoundingBoxSide(position, boundingBoxExtent: self.extent, color: self.color)
            self.sidesNode.addChildNode(self.sides[position]!)
        }
    }

    /// Returns true if the given location differs from all hit locations in the cameraRaysAndHitLocations array
    /// by at least the threshold distance.
    func isHitLocationDifferentFromPreviousRayHitTests(_ location: float3) -> Bool {
        let distThreshold: Float = 0.03
        for hitTest in cameraRaysAndHitLocations.reversed() {
            if distance(hitTest.hitLocation, location) < distThreshold {
                return false
            }
        }
        return true
    }

    private func tile(hitBy ray: Ray) -> (tile: Tile, hitLocation: float3)? {
        // Perform hit test with given ray
        let hitResults = self.sceneView.scene.rootNode.hitTestWithSegment(from: ray.origin, to: ray.endPoint, options: [
            .ignoreHiddenNodes: false,
            .boundingBoxOnly: true,
            .searchMode: SCNHitTestSearchMode.all])

        // We cannot just look at the first result because we might have hits with other than the tile geometries.
        for result in hitResults {
            if let tile = result.node as? Tile {
                if let side = tile.parent as? BoundingBoxSide, side.isBusyUpdatingTiles {
                    continue
                }

                // Each ray should only hit one tile, so we can stop iterating through results if a hit was successful.
                return (tile: tile, hitLocation: float3(result.worldCoordinates))
            }
        }
        return nil
    }

    func updateOnEveryFrame() {
        if let frame = sceneView.session.currentFrame {
            // Check if the bounding box should align its bottom with a nearby plane.
            tryToAlignWithPlanes(frame.anchors)
        }

        sides.forEach { $0.value.updateVisualizationIfNeeded() }
    }

    func tryToAlignWithPlanes(_ anchors: [ARAnchor]) {

        let bottomCenter = float3(simdPosition.x, simdPosition.y - extent.y / 2, simdPosition.z)

        var distanceToNearestPlane = Float.greatestFiniteMagnitude
        var offsetToNearestPlaneOnY: Float = 0
        var planeFound = false

        // Check which plane is nearest to the bounding box.
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else {
                continue
            }
            guard let planeNode = sceneView.node(for: plane) else {
                continue
            }

            // Get the position of the bottom center of this bounding box in the plane's coordinate system.
            let bottomCenterInPlaneCoords = planeNode.simdConvertPosition(bottomCenter, from: parent)

            // Add 10% tolerance to the corners of the plane.
            let tolerance: Float = 0.1
            let minX = plane.center.x - plane.extent.x / 2 - plane.extent.x * tolerance
            let maxX = plane.center.x + plane.extent.x / 2 + plane.extent.x * tolerance
            let minZ = plane.center.z - plane.extent.z / 2 - plane.extent.z * tolerance
            let maxZ = plane.center.z + plane.extent.z / 2 + plane.extent.z * tolerance

            guard (minX...maxX).contains(bottomCenterInPlaneCoords.x) && (minZ...maxZ).contains(bottomCenterInPlaneCoords.z) else {
                continue
            }

            let offsetToPlaneOnY = bottomCenterInPlaneCoords.y
            let distanceToPlane = abs(offsetToPlaneOnY)

            if distanceToPlane < distanceToNearestPlane {
                distanceToNearestPlane = distanceToPlane
                offsetToNearestPlaneOnY = offsetToPlaneOnY
                planeFound = true
            }
        }

        guard planeFound else { return }

        // Check that the object is not already on the nearest plane (closer than 1 mm).
        let epsilon: Float = 0.001
        guard distanceToNearestPlane > epsilon else { return }

        // Check if the nearest plane is close enough to the bounding box to "snap" to that
        // plane. The threshold is half of the bounding box extent on the y axis.
        let maxDistance = extent.y / 2
        if distanceToNearestPlane < maxDistance && offsetToNearestPlaneOnY > 0 {
            // Adjust the bounding box position & extent such that the bottom of the box
            // aligns with the plane.
            simdPosition.y -= offsetToNearestPlaneOnY / 2
            extent.y += offsetToNearestPlaneOnY
        }
    }

    func contains(_ pointInWorld: float3) -> Bool {
        let localMin = -extent / 2
        let localMax = extent / 2

        // The bounding box is in local coordinates, so convert point to local, too.
        let localPoint = self.simdConvertPosition(pointInWorld, from: nil)

        return (localMin.x...localMax.x).contains(localPoint.x) &&
            (localMin.y...localMax.y).contains(localPoint.y) &&
            (localMin.z...localMax.z).contains(localPoint.z)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension SCNNode {
    func updateMaterials(color: UIColor) {
        if let box = self.geometry as? SCNBox {
            box.firstMaterial?.diffuse.contents = color
        }
    }
}
