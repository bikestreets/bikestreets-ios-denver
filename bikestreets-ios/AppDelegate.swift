//
//  AppDelegate.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/3/23.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let mainViewController = DefaultMapsViewController()

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = mainViewController
    window?.makeKeyAndVisible()

    return true
  }
}
