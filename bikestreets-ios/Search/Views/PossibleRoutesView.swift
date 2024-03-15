//
//  PossibleRoutesView.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/8/23.
//

import Foundation
import MapboxDirections
import UIKit

protocol RouteSelectable: AnyObject {
  func didSelect(routeIndex: Int)
  func didStart(routeIndex: Int)
}

final class PossibleRoutesView: UIStackView {
  weak var delegate: RouteSelectable?

  private let preview: StateManager.DirectionsPreview?

  private let distanceFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .naturalScale
    formatter.numberFormatter.maximumFractionDigits = 2
    return formatter
  }()
  
  private let expectedTimeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .short
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropLeading, .dropTrailing]
    return formatter
  }()

  init(preview: StateManager.DirectionsPreview?) {
    self.preview = preview

    super.init(frame: .zero)

    configureSubviews()

    axis = .vertical
    spacing = 0
    distribution = .fillEqually
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Helpers

  private func configureSubviews() {
    // Clean up past arranged subviews
    for subview in arrangedSubviews {
      removeArrangedSubview(subview)
    }
    guard let preview else { return }
    
    for (index, route) in preview.routes.enumerated() {
      let expectedTimeLabel = UILabel()
      expectedTimeLabel.text = expectedTimeString(for: route.expectedTravelTime)
      expectedTimeLabel.font = .preferredFont(forTextStyle: .title3, weight: .bold)
      
      let distanceLabel = UILabel()
      distanceLabel.text = distanceString(for: route.distance)
      distanceLabel.font = .preferredFont(forTextStyle: .callout)

      let routeDetailsStack = UIStackView(arrangedSubviews: [
        expectedTimeLabel,
        distanceLabel
      ])
      routeDetailsStack.axis = .vertical
      routeDetailsStack.spacing = 9
      routeDetailsStack.alignment = .leading
      
      let leftInsetView = UIView()
      
      let spacerView = UIView()

      let button = UIButton(type: .roundedRect)
      button.layer.cornerRadius = 8
      button.clipsToBounds = true
      button.setTitle("GO", for: .normal)
      button.setTitleColor(UIColor(named: "RouteGoButtonTintColor"), for: .normal)
      button.titleLabel?.font = .preferredFont(forTextStyle: .body, weight: .bold)
      // Used to identify the tapped on route index.
      button.tag = index
      button.addTarget(self, action: #selector(didTapRouteGo(sender:)), for: .touchUpInside)

      let rightInsetView = UIView()

      [
        routeDetailsStack,
        leftInsetView,
        spacerView,
        button,
        rightInsetView,
      ].disableTranslatesAutoresizingMaskIntoConstraints()

      [
        leftInsetView.widthAnchor.constraint(equalToConstant: 16),

        button.heightAnchor.constraint(equalToConstant: 60),
        button.widthAnchor.constraint(equalToConstant: 60),

        rightInsetView.widthAnchor.constraint(equalToConstant: 16),
      ].activate()

      let routeStack = UIStackView(arrangedSubviews: [
        leftInsetView,
        routeDetailsStack,
        spacerView,
        button,
        rightInsetView
      ])
      routeStack.axis = .horizontal
      routeStack.spacing = 0
      routeStack.alignment = .center
      routeStack.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
      routeStack.isLayoutMarginsRelativeArrangement = true
      // Used to identify the tapped on route index.
      routeStack.tag = index
      // Add support for tapping on the route stack.
      let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapRouteStack(recognizer:)))
      routeStack.addGestureRecognizer(tapGestureRecognizer)
      
      addArrangedSubview(routeStack)
    }
    
    updateRouteStackBackgrounds(routeIndex: preview.selectedRouteIndex)
  }
  
  private func updateRouteStackBackgrounds(routeIndex: Int?) {
    let count = arrangedSubviews.count
    for (index, view) in arrangedSubviews.enumerated() {
      let isSelected = index == routeIndex
      view.backgroundColor = (isSelected && count > 1) ? UIColor(named: "RouteRowSelectedBackgroundColor") : UIColor(named: "RouteRowBackgroundColor")
      if let button = view.subviews.compactMap({ $0 as? UIButton }).first {
        button.backgroundColor = isSelected ? UIColor(named: "RouteGoButtonSelectedBackgroundColor") : UIColor(named: "RouteGoButtonBackgroundColor")
      }
    }
  }

  // MARK: - Data Formatting

  private func distanceString(for distance: Double) -> String {
    let measurement = Measurement(value: distance, unit: UnitLength.meters)
    return distanceFormatter.string(from: measurement)
  }
  
  private func expectedTimeString(for expectedTime: TimeInterval) -> String {
    guard let formattedValue = expectedTimeFormatter.string(from: expectedTime) else { return "" }
    return formattedValue
  }

  // MARK: - Tap Handling

  @objc
  private func didTapRouteStack(recognizer: UITapGestureRecognizer) {
    guard let routeIndex = recognizer.view?.tag else {
      return
    }
    updateRouteStackBackgrounds(routeIndex: routeIndex)
    delegate?.didSelect(routeIndex: routeIndex)
  }

  @objc
  private func didTapRouteGo(sender: UIButton) {
    let routeIndex = sender.tag
    delegate?.didStart(routeIndex: routeIndex)
  }
}
