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

    // Header
    let headerLabel = UILabel()
    headerLabel.text = SearchConfiguration.initialDestination.sheetTitle
    headerLabel.font = .preferredFont(forTextStyle: .title2, weight: .bold)
    
    view.addSubview(headerLabel)
    headerLabel.disableTranslatesAutoresizingMaskIntoConstraints()
    [
      headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      headerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      headerLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
    ].activate()
    
    let searchBar = UISearchBar()
    searchBar.placeholder = SearchConfiguration.initialDestination.searchBarPlaceholder
    searchBar.barStyle = .default
    searchBar.searchBarStyle = .minimal
    searchBar.disableTranslatesAutoresizingMaskIntoConstraints()
    searchBar.heightAnchor.constraint(equalToConstant: 40).isActive = true
    searchBar.delegate = self

    let legendTitleLabel = UILabel()
    legendTitleLabel.text = "Legend"
    legendTitleLabel.font = .preferredFont(forTextStyle: .headline, weight: .bold)

    let bars: [UIView] = MapLayerSpec.allCases.map(createLegendBar(_:))

    /*
     Align internal UISearchBarTextField left/right with rest of legend content:

     |------ Sheet
     |                |----------- UIStackView (internal overall stack)
     |            |--------------- _UISearchBarSearchContainerView (UIKit)
     |                    |------- UISearchBarTextField (UIKit)
     |                    ^ default inset of UISearchBar within itself (8 pt)
     |
     |            |--------------- UIStackView (internal legend stack)
     |                    |------- UILabel (internal legend label)
     |                    ^ mimic default inset of UISearchBar
     |------
     */

    let legendStackView = UIStackView(arrangedSubviews: [legendTitleLabel] + bars)
    legendStackView.axis = .vertical
    legendStackView.spacing = 16
    legendStackView.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    legendStackView.isLayoutMarginsRelativeArrangement = true

    let stackView = UIStackView(arrangedSubviews: [searchBar, legendStackView])
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.disableTranslatesAutoresizingMaskIntoConstraints()
    stackView.setCustomSpacing(12, after: searchBar)
    stackView.layoutMargins = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: -4)
    stackView.isLayoutMarginsRelativeArrangement = true

    scrollView.addSubview(stackView)

    [
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stackView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
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
