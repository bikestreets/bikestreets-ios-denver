//
//  FeedbackEmailViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 12/8/23.
//

import Foundation
import MapboxCoreNavigation
import MessageUI

/// `MFMailComposeViewController` subclass that supports handling state within
/// the BikeStreets control flow plus handling the `EndOfRouteFeedback`.
final class FeedbackEmailViewController: MFMailComposeViewController {
  private let stateManager: StateManager

  init(stateManager: StateManager, feedback: EndOfRouteFeedback) {
    self.stateManager = stateManager

    super.init(nibName: nil, bundle: nil)

    mailComposeDelegate = self

    setToRecipients(["info@bikestreets.com"])
    setSubject("[\(Bundle.main.releaseVersionNumber) (\(Bundle.main.buildVersionNumber))] BikeStreets App Feedback - iOS")

    let ratingString: String
    if let rating = feedback.rating {
      ratingString = "\(rating)"
    } else {
      ratingString = "None"
    }
    let commentString: String
    if let comment = feedback.comment {
      commentString = comment
    } else {
      commentString = "None"
    }

    setMessageBody("""
Rating: \(ratingString)

Comment:
\(commentString)
""", isHTML: false)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: -- MFMailComposeViewControllerDelegate

extension FeedbackEmailViewController: MFMailComposeViewControllerDelegate {
  func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    // Dismiss the mail compose view controller.
    controller.dismiss(animated: true, completion: nil)

    stateManager.state = .initial
  }
}
