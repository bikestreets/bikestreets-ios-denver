//
//  SearchViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import Foundation
import MapKit
import UIKit

final class SearchViewController: UIViewController {
  private let configuration: SearchConfiguration
  private let stateManager: StateManager
  private let sheetManager: SheetManager
  private let searchViewController: LocationSearchTableViewController

  weak var delegate: LocationSearchDelegate?

  init(configuration: SearchConfiguration, stateManager: StateManager, sheetManager: SheetManager) {
    self.configuration = configuration
    self.stateManager = stateManager
    self.sheetManager = sheetManager
    self.searchViewController = LocationSearchTableViewController(configuration: configuration)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    searchViewController.delegate = self

    view.backgroundColor = .systemBackground

    let insetView = UIView()

    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8

    searchViewController.willMove(toParent: self)
    addChild(searchViewController)

    let label = UILabel()
    label.text = configuration.sheetTitle
    label.font = .preferredFont(forTextStyle: .title2, weight: .bold)
    label.disableTranslatesAutoresizingMaskIntoConstraints()

    let labelContainer = UIView()
    labelContainer.addSubview(label)
    labelContainer.disableTranslatesAutoresizingMaskIntoConstraints()
    labelContainer.matchAutolayoutSize(label, insets: .init(top: 0, left: 16, bottom: 0, right: -8))
    stackView.addArrangedSubview(labelContainer)

    let searchBarHolder = UIView()
    searchBarHolder.addSubview(searchViewController.searchController.searchBar)
    stackView.addArrangedSubview(searchBarHolder)

    stackView.addArrangedSubview(searchViewController.view)

    searchViewController.didMove(toParent: self)

    view.addSubviews(
      insetView,
      stackView
    )

    [
      insetView,
      stackView,
      searchBarHolder
    ].disableTranslatesAutoresizingMaskIntoConstraints()

    [
      insetView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      insetView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 16),
      insetView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -16),
      insetView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

      insetView.topAnchor.constraint(equalTo: stackView.topAnchor),
      view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
      view.leftAnchor.constraint(equalTo: stackView.leftAnchor),
      view.rightAnchor.constraint(equalTo: stackView.rightAnchor),

      searchBarHolder.topAnchor.constraint(equalTo: searchViewController.searchController.searchBar.topAnchor),
      searchBarHolder.heightAnchor.constraint(equalToConstant: 56),
      searchBarHolder.leftAnchor.constraint(equalTo: searchViewController.searchController.searchBar.leftAnchor),
      searchBarHolder.rightAnchor.constraint(equalTo: searchViewController.searchController.searchBar.rightAnchor),
    ].activate()
  }

  private var hasBeenPresented = false
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !hasBeenPresented {
      hasBeenPresented = true
      // Doing this after this run loop finishes allows it to work.
      DispatchQueue.main.async {
        self.searchViewController.searchController.searchBar.becomeFirstResponder()
      }
    }
  }
}

// MARK: - LocationSearchDelegate

extension SearchViewController: LocationSearchDelegate {
  func mapSearchRegion() -> MKCoordinateRegion? {
    return delegate?.mapSearchRegion()
  }

  func didSelect(configuration: SearchConfiguration, location: SelectedLocation) {
    delegate?.didSelect(configuration: configuration, location: location)

    // Consider searching to be done.
    searchViewController.searchController.searchBar.endEditing(true)
    searchViewController.searchController.isActive = false

    // Dismiss on selection when not in initial state.
    switch configuration {
    case .newDestination, .newOrigin:
      sheetManager.dismiss(viewController: self, animated: true)
    case .initialDestination:
      // Only push direction preview from initial destination selection.
      let directionPreviewViewController = DirectionPreviewViewController(stateManager: stateManager)
      sheetManager.present(
        directionPreviewViewController,
        animated: true,
        sheetOptions: .init(
          selectedDetentIdentifier: .medium
        ),
        options: .init(
          presentationControllerDidDismiss: { [weak self] in
            guard let self else { return }
            self.stateManager.state = .initial
          }
        )
      )
    }
  }
}
