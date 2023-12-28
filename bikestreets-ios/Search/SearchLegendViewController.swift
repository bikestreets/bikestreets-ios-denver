//
//  SearchLegendViewController.swift
//  VAMOS
//
//  Created by Matt Robinson on 12/28/23.
//

import Foundation
import UIKit

/// View controller that serves as the entry point into the initial search experience
/// while displaying a legend for all the Vamos network edge colors.
final class SearchLegendViewController: UIViewController {
  private let stateManager: StateManager

  init(stateManager: StateManager) {
    self.stateManager = stateManager
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    view.backgroundColor = UIColor.systemBackground

    let scrollView = UIScrollView()
    scrollView.disableTranslatesAutoresizingMaskIntoConstraints()
    view.addSubview(scrollView)
    view.matchAutolayoutSize(scrollView)

    let searchBar = UISearchBar()
    searchBar.placeholder = SearchConfiguration.initialDestination.searchBarPlaceholder
    searchBar.barStyle = .default
    searchBar.searchBarStyle = .minimal
    searchBar.disableTranslatesAutoresizingMaskIntoConstraints()
    searchBar.heightAnchor.constraint(equalToConstant: 40).isActive = true
    searchBar.delegate = self

    let legendTitleLabel = UILabel()
    legendTitleLabel.text = "Segment Types"
    legendTitleLabel.font = .preferredFont(forTextStyle: .headline, weight: .bold)

    let bars: [UIView] = MapLayerSpec.allCases.map(createLegendBar(_:))

    let stackView = UIStackView(arrangedSubviews: [searchBar, legendTitleLabel] + bars)
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.disableTranslatesAutoresizingMaskIntoConstraints()
    stackView.setCustomSpacing(20, after: searchBar)

    scrollView.addSubview(stackView)

    [
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
    ].activate()
  }

  private func createLegendBar(_ spec: MapLayerSpec) -> UIView {
    let barView = UIView()
    barView.backgroundColor = spec.color
    barView.disableTranslatesAutoresizingMaskIntoConstraints()
    barView.heightAnchor.constraint(equalToConstant: 5).isActive = true
    barView.layer.cornerRadius = 2.5
    barView.clipsToBounds = true

    let label = UILabel()
    label.text = spec.visualDescription
    label.numberOfLines = 0
    label.font = .preferredFont(forTextStyle: .footnote)

    let stackView = UIStackView(arrangedSubviews: [barView, label])
    stackView.axis = .vertical
    stackView.spacing = 7

    return stackView
  }
}

// MARK: -- UISearchBarDelegate

extension SearchLegendViewController: UISearchBarDelegate {
  func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
    stateManager.state = .searchDestination
    return false
  }
}
