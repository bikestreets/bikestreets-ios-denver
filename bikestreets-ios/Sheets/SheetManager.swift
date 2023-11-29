//
//  SheetManager.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/28/23.
//

import Foundation
import UIKit

protocol SheetManagerDelegate: AnyObject {
  func didUpdatePresentedViewController(_ presentedViewController: UIViewController)
}

final class SheetManager: NSObject, UISheetPresentationControllerDelegate {
  weak var delegate: SheetManagerDelegate?

  private let rootViewController: UIViewController
  private var presentedViewControllers: [InternalOptions] = []

  init(rootViewController: UIViewController) {
    self.rootViewController = rootViewController
  }

  // MARK: -- Options

  struct Options {
    let shouldDismiss: Bool
    let presentationControllerDidDismiss: (() -> Void)?

    static var `default`: Options {
      Options(shouldDismiss: true)
    }

    init(
      shouldDismiss: Bool = true,
      presentationControllerDidDismiss: (() -> Void)? = nil
    ) {
      self.shouldDismiss = shouldDismiss
      self.presentationControllerDidDismiss = presentationControllerDidDismiss
    }
  }

  private class InternalOptions {
    let options: Options
    weak var viewController: UIViewController?

    init(options: Options, viewController: UIViewController?) {
      self.options = options
      self.viewController = viewController
    }
  }

  // MARK: -- Garbage Collection

  private func cleanUpMemory() {
    presentedViewControllers = presentedViewControllers.filter { $0.viewController != nil }
  }

  // MARK: -- Presentation

  /// The last-presented `UIViewController`, if exists
  private var previousViewController: UIViewController? {
    cleanUpMemory()

    return presentedViewControllers.reversed().first {
      $0.viewController != nil
    }?.viewController
  }

  /// The last-presented `UIViewController` or the root view controller if nothing
  /// is currently presented on it.
  private var previousOrRootViewController: UIViewController {
    return previousViewController ?? rootViewController
  }

  func present(
    _ viewControllerToPresent: UIViewController,
    animated isAnimated: Bool,
    sheetOptions: UISheetPresentationController.ConfigurationOptions = .default,
    options: Options = .default,
    completion: (() -> Void)? = nil
  ) {
    let presentingViewController = previousOrRootViewController

    // Configure and store sheet presentation controller
    viewControllerToPresent.sheetPresentationController?.configure(options: sheetOptions)

    guard let sheetPresentationController = viewControllerToPresent.sheetPresentationController else {
      fatalError("Unable to create sheetPresentationController")
    }

    sheetPresentationController.delegate = self
    presentedViewControllers.append(
      .init(options: options, viewController: viewControllerToPresent)
    )

    // Present on stack
    presentingViewController.present(viewControllerToPresent, animated: isAnimated)

    // Send update to listeners
    delegate?.didUpdatePresentedViewController(viewControllerToPresent)
  }

  func dismiss(viewController: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    var nowPresentedViewController: UIViewController?
    var foundDismissedViewController = false
    presentedViewControllers = presentedViewControllers.filter {
      if foundDismissedViewController {
        return false
      } else if $0.viewController === viewController {
        foundDismissedViewController = true
        return false
      } else {
        if let presentedViewController = $0.viewController {
          nowPresentedViewController = presentedViewController
        }
        return true
      }
    }

    viewController.dismiss(animated: true, completion: completion)

    // Send update to listeners
    if let nowPresentedViewController {
      delegate?.didUpdatePresentedViewController(nowPresentedViewController)
    }
  }

  /// Remove all presented sheets. Equivalent to calling `dismiss(animated:)` on the root VC.
  func dismissAllSheets(animated flag: Bool, completion: (() -> Void)? = nil) {
    // Clear out entire backstack of view controllers.
    presentedViewControllers = []

    rootViewController.dismiss(animated: flag, completion: completion)
  }

  // MARK: -- UISheetPresentationControllerDelegate

  private func findPresentationControllerOptions(_ presentationController: UIPresentationController) -> Options? {
    return presentedViewControllers.first {
      return $0.viewController === presentationController.presentedViewController
    }?.options
  }

  func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
    return findPresentationControllerOptions(presentationController)?.shouldDismiss ?? true
  }

  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    /*
     no-op, this is fired when a dismissal isn't necessarily going to happen
     */
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    findPresentationControllerOptions(presentationController)?.presentationControllerDidDismiss?()
    
    delegate?.didUpdatePresentedViewController(presentationController.presentingViewController)

    presentedViewControllers = presentedViewControllers.filter {
      return $0.viewController?.sheetPresentationController !== presentationController
    }
  }
}
