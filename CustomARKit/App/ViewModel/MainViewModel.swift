//
//  MainViewModel.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import UIKit
import ARKit
import RxSwift

class MainViewModel: NSObject {
    private var measureManager: MeasureManager!
    private var sceneView: ARSCNView!
    private var extentBox: SIMD3<Float> = SIMD3.init(0, 0, 0)
    
    private var isReadyToRelease: Bool = false
    private var isRunningMeasure: Bool = false
    
    let frames = PublishSubject<ARFrame>()
    let scanningProgess = PublishSubject<Float>()
    let events = PublishSubject<ARMeasureEvent>()
    let stateMeasure = PublishSubject<ARStateDetect>()
    let actionMeasure =  PublishSubject<ARViewModelAction>()
    var currentProgress: Float = 0.0
    
    private let disposeBag = DisposeBag()
    
    
    public override init() {
        super.init()
        self.registerMeasureAction()
    }
    
    private func registerMeasureAction() {
        self.actionMeasure
            .subscribe(onNext: { [unowned self] action in
                switch action {
                case .defineObject:
                    self.measureManager.createBoudingBox()
                case .completeMeasure:
                    self.isRunningMeasure = false
                    self.extentBox = self.measureManager.getExtentBag()
                case .rescanObject:
                    //                    self.hiddenModel()
                    break
                }
            })
            .disposed(by: disposeBag)
    }
    
    public func showWhiteBox(isHidden: Bool) {
        self.measureManager.showBoundingBox(isHidden: isHidden)
    }
    
    public func setupSceneView(sceneView: ARSCNView) {
        self.isRunningMeasure = true
        self.sceneView = sceneView
        self.measureManager = MeasureManager(sceneView)
        self.frames
            .asObserver()
            .subscribe( onNext: { [unowned self] frame in
                self.measureManager.updateOnEveryFrame(frame)
            })
            .disposed(by: disposeBag)
        self.registerNotificationBox()
    }
    
    public func resetMeasure() {
        self.currentProgress = 0.0
        self.isReadyToRelease = false
        self.measureManager?.resetMeasure()
    }
    
    
    public func getStateMeasure() -> Bool {
        return self.isRunningMeasure
    }
    
    public func setStateMeasure(isRunningMeasure: Bool) {
        self.isRunningMeasure = isRunningMeasure
    }
}

//MARK: Notification
extension MainViewModel {
    private func registerNotificationBox() {
        if isRunningMeasure {
            NotificationCenter.default.addObserver(self, selector: #selector(ghostBoundingBoxWasCreated),
                                                   name: ScannedObject.ghostBoundingBoxCreatedNotification,
                                                   object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(ghostBoundingBoxWasRemoved),
                                                   name: ScannedObject.ghostBoundingBoxRemovedNotification,
                                                   object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(boundingBoxWasCreated),
                                                   name: ScannedObject.boundingBoxCreatedNotification,
                                                   object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(boundingBoxUpdateScanning),
                                                   name: ScannedObject.boundingBoxScanningProgressNotification,
                                                   object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(eventReadyToRelease),
                                                   name: BoundingBox.extentChangedNotification,
                                                   object: nil)
        }
    }
    
    @objc func eventReadyToRelease(_ notification: Notification) {
        guard let measureManager = self.measureManager,
            measureManager.scannedObject.boundingBox != nil  else { return }
        if !self.isReadyToRelease && currentProgress == Float(1.0) {
            self.stateMeasure.onNext(.readyToRelease)
            self.isReadyToRelease = true
        }
    }
    
    @objc func ghostBoundingBoxWasRemoved(_ notification: Notification) {
        self.stateMeasure.onNext(.notReadyMeasure)
    }
    
    @objc func ghostBoundingBoxWasCreated(_ notification: Notification) {
        self.stateMeasure.onNext(.readyMeasure)
    }
    
    @objc func boundingBoxWasCreated(_ notification: Notification) {
        self.stateMeasure.onNext(.scanToMeasure)
    }
    
    @objc func boundingBoxUpdateScanning(_ notification: Notification) {
        if !self.isReadyToRelease {
            if let progress = notification.userInfo?["progress"] as? Float {
                self.currentProgress = progress
                self.scanningProgess.onNext(progress)
            }
        }
    }
    
}
