//
//  SizeTrackingView.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import Foundation
import UIKit

protocol SizeTrackingListener: AnyObject {
  func didChangeFrame(_ view: UIView, frame: CGRect)
}

final class SizeTrackingView: UIView {
  weak var delegate: SizeTrackingListener?

  private(set) var lastFrameBroadcast: CGRect?

  init() {
    super.init(frame: .zero)
    isHidden = true
    disableTranslatesAutoresizingMaskIntoConstraints()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    lastFrameBroadcast = frame

    if let lastFrameBroadcast, lastFrameBroadcast != frame {
      delegate?.didChangeFrame(self, frame: frame)
    } else {
      delegate?.didChangeFrame(self, frame: frame)
    }
  }
}
