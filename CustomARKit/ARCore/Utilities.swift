/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Convenience extensions on system types used in this project.
 */
import Foundation
import ARKit

extension UIColor {
    public convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
}

extension UIColor {
    static let appYellow = UIColor.yellow
    static let appLightYellow = UIColor.init(r: 1.0, g: 0.95, b: 0.75, a: 1.0)
    static let appBrown = UIColor.brown
    static let appGreen = UIColor.green
}
enum Axis {
    case x
    case y
    case z

    var normal: float3 {
        switch self {
        case .x:
            return float3(1, 0, 0)
        case .y:
            return float3(0, 1, 0)
        case .z:
            return float3(0, 0, 1)
        }
    }
}

extension simd_quatf {
    init(angle: Float, axis: Axis) {
        self.init(angle: angle, axis: axis.normal)
    }
}

extension float4x4 {
    var position: float3 {
        return columns.3.xyz
    }

    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: float3 {
        get {
            let translation = columns.3
            return float3(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = float4(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }

    /**
     Factors out the orientation component of the transform.
     */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }

    /**
     Creates a transform matrix with a uniform scale factor in all directions.
     */
    init(uniformScale scale: Float) {
        self = matrix_identity_float4x4
        columns.0.x = scale
        columns.1.y = scale
        columns.2.z = scale
    }
}

extension float4 {
    var xyz: float3 {
        return float3(x, y, z)
    }

    init(_ xyz: float3, _ w: Float) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }
}

extension SCNMaterial {

    static func material(withDiffuse diffuse: Any?, respondsToLighting: Bool = false, isDoubleSided: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = diffuse
        material.isDoubleSided = isDoubleSided
        if respondsToLighting {
            material.locksAmbientWithDiffuse = true
        } else {
            material.locksAmbientWithDiffuse = false
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
        }
        return material
    }
}

@available(iOS 12.0, *)
struct Ray {
    let origin: float3
    let direction: float3
    let endPoint: float3

    init(origin: float3, direction: float3) {
        self.origin = origin
        self.direction = direction
        self.endPoint = origin + direction
    }

    init(normalFrom pointOfView: SCNNode, length: Float) {
        let cameraNormal = normalize(pointOfView.simdWorldFront) * length
        self.init(origin: pointOfView.simdWorldPosition, direction: cameraNormal)
    }
}

@available(iOS 12.0, *)
extension ARSCNView {

    func smartHitTest(_ point: CGPoint) -> ARHitTestResult? {
        let hitTestResults = hitTest(point, types: .featurePoint)
        guard !hitTestResults.isEmpty else { return nil }

        for result in hitTestResults {
            // Return the first result which is between 20 cm and 3 m away from the user.
            if result.distance > 0.2 && result.distance < 3 {
                return result
            }
        }
        return nil
    }

}

@available(iOS 12.0, *)
extension SCNNode {

    /// Cleanup sccnode to improve
    func cleanup() {
        for child in childNodes {
            child.cleanup()
        }

        geometry = nil
    }

    /// Wrapper for SceneKit function to use SIMD vectors and a typed dictionary.
    open func hitTestWithSegment(from pointA: float3, to pointB: float3, options: [SCNHitTestOption: Any]? = nil) -> [SCNHitTestResult] {
        if let options = options {
            var rawOptions = [String: Any]()
            for (key, value) in options {
                switch (key, value) {
                case (_, let bool as Bool):
                    rawOptions[key.rawValue] = NSNumber(value: bool)
                case (.searchMode, let searchMode as SCNHitTestSearchMode):
                    rawOptions[key.rawValue] = NSNumber(value: searchMode.rawValue)
                case (.rootNode, let object as AnyObject):
                    rawOptions[key.rawValue] = object
                default:
                    fatalError("unexpected key/value in SCNHitTestOption dictionary")
                }
            }
            return hitTestWithSegment(from: SCNVector3(pointA), to: SCNVector3(pointB), options: rawOptions)
        } else {
            return hitTestWithSegment(from: SCNVector3(pointA), to: SCNVector3(pointB))
        }
    }
}

extension CGPoint {
    /// Extracts the screen space point from a vector returned by SCNView.projectPoint(_:).
    init(_ vector: SCNVector3) {
        self.init(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }

    /// Returns the length of a point when considered as a vector. (Used with gesture recognizers.)
    var length: CGFloat {
        return sqrt(x * x + y * y)
    }

    static func +(left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
}

extension SCNGeometry {
    class func line(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        return SCNGeometry(sources: [source], elements: [element])
    }
}
