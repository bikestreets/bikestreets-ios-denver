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
    view.backgroundColor = UIColor.directionPreviewBackground

    view.addSubview(scrollView)
    view.matchAutolayoutSize(scrollView)

    stateManager.add(listener: self)
    configureDismissButton(action: #selector(dismissButtonClicked))
    configureViews()
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
    placesStackView.backgroundColor = UIColor.placesStackViewBackground
    
    let flipRouteButton = FlipRouteButton()
    flipRouteButton.addTarget(self, action: #selector(flipRouteButtonClicked(_:)), for: .touchUpInside)
    // FlipRouteButton is hidden for release, but leaving it here to be shown, as it can be handy for testing
    flipRouteButton.isHidden = true

    let possibleRoutesView = PossibleRoutesView(preview: preview)
    possibleRoutesView.delegate = self
    possibleRoutesView.layer.cornerRadius = 16
    possibleRoutesView.clipsToBounds = true

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
    scrollView.addSubview(flipRouteButton)

    [
      titleLabel,
      spacerView,
      stackView,
      flipRouteButton
    ].disableTranslatesAutoresizingMaskIntoConstraints()

    [
      spacerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      flipRouteButton.centerYAnchor.constraint(equalTo: placesStackView.centerYAnchor),
      flipRouteButton.heightAnchor.constraint(equalToConstant: 35.0),
      flipRouteButton.widthAnchor.constraint(equalToConstant: 28.0),
      flipRouteButton.centerXAnchor.constraint(equalTo: placesStackView.leadingAnchor)
    ].activate()
  }
  
  @objc func dismissButtonClicked() {
    stateManager.state = .initial
    sheetManager.dismiss(viewController: self, animated: true)
  }

  // MARK: -- Helpers

  private var preview: StateManager.DirectionsPreview? {
    switch stateManager.state {
    case .previewDirections(let preview):
      return preview
    case .requestingRoutes:
      return nil
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
  
  // MARK: Flip Route
  
  @objc private func flipRouteButtonClicked(_ sender: UIButton) {
    switch stateManager.state {
    case .previewDirections(let preview):
      stateManager.state = .requestingRoutes(request: .init(origin: preview.request.destination, destination: preview.request.origin))
    case .updateOrigin, .updateDestination, .requestingRoutes:
      break
    default:
      fatalError("Unexpected state")
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
    case .updateOrigin, .requestingRoutes:
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
    case .updateDestination, .requestingRoutes:
      break
    default:
      fatalError("Unexpected state")
    }
  }
}

// MARK: - RouteSelectable

extension DirectionPreviewViewController: RouteSelectable {
  func didSelect(routeIndex: Int) {
    switch stateManager.state {
    case .previewDirections(let preview):
      guard routeIndex != preview.selectedRouteIndex else { return }
      stateManager.state = .previewDirections(preview: .init(
        request: preview.request, 
        response: preview.response,
        selectedRouteIndex: routeIndex
      ))
    default:
      fatalError("State must be preview directions when route is selected")
    }
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
