//
//  AppDelegate.swift
//  CustomARKit
//
//  Created by Chi Hoang on 25/4/20.
//  Copyright © 2020 Hoang Nguyen Chi. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateViewController(identifier: "MainViewController") as? MainViewController else { return false }
        let viewModel = MainViewModel()
        controller.viewModel = viewModel
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
        return true
    }
    
    
}
