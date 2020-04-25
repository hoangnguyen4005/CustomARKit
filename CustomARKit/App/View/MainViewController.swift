//
//  MainViewController.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import UIKit
import ARKit

class MainViewController: UIViewController {
    var viewModel: MainViewModel!
    
    public lazy var sceneView: ARSCNView = {
        let view = ARSCNView()
        return view
    }()
    
    private lazy var configuration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        return configuration
    }()
    
    private lazy var screenCenter: CGPoint = {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }()
    
    private lazy var session: ARSession = {
        return self.sceneView.session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initSceneView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.requestPermissionCamera()
    }
    
    public func requestPermissionCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            self.runARScene()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [unowned self] (granted: Bool) in
                if granted {
                    DispatchQueue.main.async {
                        self.runARScene()
                    }
                }
            })
        } else {
            self.goToSettings()
        }
    }
    
    private func goToSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, completionHandler: nil)
    }
    
}

extension MainViewController :ARSCNViewDelegate {
    
    private func initSceneView() {
        self.view.addSubview(self.sceneView)
        self.sceneView.translatesAutoresizingMaskIntoConstraints = false
        self.sceneView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.sceneView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.sceneView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.sceneView.delegate = self
        self.view.sendSubviewToBack(self.sceneView)
    }
    
    private func runARScene() {
        self.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors])
        self.viewModel.setupSceneView(sceneView: self.sceneView)
    }
    
    private func cleanARScene() {
        self.configuration.planeDetection = []
        self.sceneView.session.run(configuration)
        self.viewModel.setStateMeasure(isRunningMeasure: false)
        self.sceneView.session.pause()
        for node in self.sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        self.sceneView.scene.rootNode.cleanup()
    }
    
    private func reScanMeasure() {
        self.viewModel.resetMeasure()
        self.viewModel.setStateMeasure(isRunningMeasure: true)
        self.viewModel.stateMeasure.onNext(.notReadyMeasure)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame,
            let viewModel = self.viewModel,
            self.viewModel.getStateMeasure()  else { return }
        viewModel.frames.onNext(frame)
    }
}
