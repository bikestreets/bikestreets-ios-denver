//
//  UISheetPresentationController+Configuration.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/6/23.
//

import Foundation
import UIKit

extension UISheetPresentationController {
  struct ConfigurationOptions {
    let detents: [UISheetPresentationController.Detent]
    let selectedDetentIdentifier: UISheetPresentationController.Detent.Identifier?
    let largestUndimmedDetentIdentifier: UISheetPresentationController.Detent.Identifier?
    let prefersGrabberVisible: Bool

    static var `default`: ConfigurationOptions {
      .init()
    }

    init(
      detents: [UISheetPresentationController.Detent] = [.small(), .medium(), .large()],
      selectedDetentIdentifier: UISheetPresentationController.Detent.Identifier? = .small,
      largestUndimmedDetentIdentifier: UISheetPresentationController.Detent.Identifier? = .medium,
      prefersGrabberVisible: Bool = true
    ) {
      self.detents = detents
      self.selectedDetentIdentifier = selectedDetentIdentifier
      self.largestUndimmedDetentIdentifier = largestUndimmedDetentIdentifier
      self.prefersGrabberVisible = prefersGrabberVisible
    }
  }

  func configure(options: ConfigurationOptions = .default) {
    detents = options.detents
    selectedDetentIdentifier = options.selectedDetentIdentifier
    // Don't let the sheet dim the background content.
    largestUndimmedDetentIdentifier = options.largestUndimmedDetentIdentifier
    // Sheet needs rounded corners.
    preferredCornerRadius = 16
    // Sheet needs to show the top grabber.
    prefersGrabberVisible = options.prefersGrabberVisible
  }
}

// MARK: - Detent Additions

extension UISheetPresentationController.Detent {

  // MARK: -- Tiny

  private static let _tiny: UISheetPresentationController.Detent = custom(identifier: .tiny, resolver: { context in
    110
  })

  static func tiny() -> UISheetPresentationController.Detent {
    return _tiny
  }


  // MARK: -- Small

  private static let _small: UISheetPresentationController.Detent = custom(identifier: .small, resolver: { context in
    220
  })
  
  static func small() -> UISheetPresentationController.Detent {
    return _small
  }
}

extension UISheetPresentationController.Detent.Identifier {
  static let tiny: UISheetPresentationController.Detent.Identifier = .init(rawValue: "tiny")
  static let small: UISheetPresentationController.Detent.Identifier = .init(rawValue: "small")
}
