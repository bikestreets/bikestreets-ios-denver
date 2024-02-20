//
//  DirectionPreviewViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import Foundation
import MapboxDirections
import UIKit

final class DirectionPreviewViewController: UIViewController {
  private let stateManager: StateManager
  private let sheetManager: SheetManager
  private let stackView = UIStackView()
  private let scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.disableTranslatesAutoresizingMaskIntoConstraints()
    return scrollView
  }()

  init(stateManager: StateManager, sheetManager: SheetManager) {
    self.stateManager = stateManager
    self.sheetManager = sheetManager
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    
    isModalInPresentation = true
    updateColors()

    view.addSubview(scrollView)
    view.matchAutolayoutSize(scrollView)

    stateManager.add(listener: self)
    configureDismissButton(action: #selector(dismissButtonClicked))
    configureViews()
  }
  
  private func updateColors() {
    view.backgroundColor = .directionsPreviewBackgroundColor
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  /// Remove any past views and then re-add all the views based on the current state.
  private func configureViews() {
    // Clean up past state.
    scrollView.subviews.forEach {
      $0.removeFromSuperview()
    }

    let titleLabel = UILabel()
    titleLabel.text = "Directions"
    titleLabel.font = .preferredFont(forTextStyle: .title1, weight: .bold)

    let titleContainer = UIView()
    titleContainer.addSubview(titleLabel)
    titleContainer.matchAutolayoutSize(titleLabel, insets: .init(top: 0, left: 8, bottom: 0, right: 0))

    let placesStackView = RoutePlaceRowView(originName: originName, destinationName: destinationName)
    placesStackView.delegate = self
    placesStackView.layer.cornerRadius = 16
    placesStackView.clipsToBounds = true
    placesStackView.backgroundColor = .tertiarySystemBackground

    let possibleRoutesView = PossibleRoutesView(routes: routes)
    possibleRoutesView.delegate = self
    possibleRoutesView.layer.cornerRadius = 16
    possibleRoutesView.clipsToBounds = true
    possibleRoutesView.backgroundColor = .tertiarySystemBackground

    let spacerView = UIView()
    let stackView = UIStackView(arrangedSubviews: [
      titleContainer,
      placesStackView,
      possibleRoutesView,
      spacerView
    ])
    stackView.axis = .vertical
    stackView.spacing = 16

    scrollView.addSubview(stackView)

    [
      titleLabel,
      spacerView,
      stackView,
    ].disableTranslatesAutoresizingMaskIntoConstraints()

    [
      spacerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
    ].activate()
  }
  
  @objc func dismissButtonClicked() {
    stateManager.state = .initial
    sheetManager.dismiss(viewController: self, animated: true)
  }

  // MARK: -- Helpers

  private var routes: [MapboxDirections.Route] {
    switch stateManager.state {
    case .previewDirections(let preview):
      return preview.response.routes ?? []
    case .requestingRoutes:
      return []
    default:
      fatalError("Unsupported state")
    }
  }

  private var originName: String {
    switch stateManager.state {
    case .previewDirections(let preview):
      return preview.request.origin.name
    case .requestingRoutes(let request):
      return request.origin.name
    default:
      fatalError("Unsupported state")
    }
  }

  private var destinationName: String {
    switch stateManager.state {
    case .previewDirections(let preview):
      return preview.request.destination.name
    case .requestingRoutes(let request):
      return request.destination.name
    default:
      fatalError("Unsupported state")
    }
  }
}

// MARK: - StateListener

extension DirectionPreviewViewController: StateListener {
  func didUpdate(from oldState: StateManager.State, to newState: StateManager.State) {
    switch newState {
    case .requestingRoutes, .previewDirections:
      configureViews()
    default:
      break
    }
  }
}

// MARK: - RoutePlaceRowViewDelegate

extension DirectionPreviewViewController: RoutePlaceRowViewDelegate {
  func requestOriginUpdate() {
    animateSelectedDetentIdentifier(to: .medium)
    switch stateManager.state {
    case .previewDirections(let preview):
      stateManager.state = .updateOrigin(preview: preview)
    case .updateOrigin:
      break
    default:
      fatalError("Unexpected state")
    }
  }

  func requestDestinationUpdate() {
    animateSelectedDetentIdentifier(to: .medium)
    switch stateManager.state {
    case .previewDirections(let preview):
      stateManager.state = .updateDestination(preview: preview)
    case .updateDestination:
      break
    default:
      fatalError("Unexpected state")
    }
  }
}

// MARK: - RouteSelectable

extension DirectionPreviewViewController: RouteSelectable {
  func didSelect(routeIndex: Int) {
    // TODO: Add route selection support.
  }

  func didStart(routeIndex: Int) {
    switch stateManager.state {
    case .previewDirections(let preview):
      guard let routes = preview.response.routes else {
        fatalError("Unable to determine initial OSRM routes")
      }
      stateManager.state = .routing(routing: .init(
        request: preview.request,
        response: preview.response,
        selectedRoute: routes[routeIndex],
        selectedRouteIndex: routeIndex
      ))
    default:
      fatalError("State must be preview directions when route is selected")
    }
  }
}
