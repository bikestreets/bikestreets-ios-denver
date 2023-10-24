//
//  RoutePlaceRowView.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/7/23.
//

import Foundation
import UIKit

protocol RoutePlaceRowViewDelegate: AnyObject {
  func requestOriginUpdate()
  func requestDestinationUpdate()
}

final class RoutePlaceRowView: UIStackView {
  weak var delegate: RoutePlaceRowViewDelegate?

  init(originName: String, destinationName: String) {
    let fromTitle = UILabel()
    fromTitle.text = "From"
    fromTitle.font = .preferredFont(forTextStyle: .body, weight: .bold)

    let fromName = UILabel()
    fromName.text = originName
    fromName.font = .preferredFont(forTextStyle: .body)

    let toTitle = UILabel()
    toTitle.text = "To"
    toTitle.font = .preferredFont(forTextStyle: .body, weight: .bold)

    let toName = UILabel()
    toName.text = destinationName
    toName.font = .preferredFont(forTextStyle: .body)

    [
      fromTitle,
      fromName,
      toTitle,
      toName,
    ].disableTranslatesAutoresizingMaskIntoConstraints()

    super.init(frame: .zero)

    addArrangedSubviews(
      .init(insetView: fromTitle, insets: .init(top: 0, left: 16, bottom: 0, right: 16)),
      .init(insetView: fromName, insets: .init(top: 0, left: 16, bottom: 0, right: 16)),
      .init(insetView: toTitle, insets: .init(top: 0, left: 16, bottom: 0, right: 16)),
      .init(insetView: toName, insets: .init(top: 0, left: 16, bottom: 0, right: 16))
    )

    axis = .vertical
    spacing = 8

    layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
    isLayoutMarginsRelativeArrangement = true

    // Add selection support
    addTapHandler(to: [fromTitle, fromName], action: #selector(updateOrigin))
    addTapHandler(to: [toTitle, toName], action: #selector(updateDestination))
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: -- Selection

  private func addTapHandler(to views: [UIView], action: Selector) {
    views.forEach {
      let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: action)
      $0.addGestureRecognizer(tapGestureRecognizer)
      $0.isUserInteractionEnabled = true
    }
  }

  @objc
  private func updateOrigin() {
    delegate?.requestOriginUpdate()
  }

  @objc
  private func updateDestination() {
    delegate?.requestDestinationUpdate()
  }
}
