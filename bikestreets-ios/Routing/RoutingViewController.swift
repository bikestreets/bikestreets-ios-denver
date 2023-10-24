//
//  RoutingViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/6/23.
//

import Foundation
import UIKit

final class RoutingViewController: UIViewController {
  private let stateManager: StateManager

  init(stateManager: StateManager) {
    self.stateManager = stateManager
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground

    let stopRoutingButton = UIButton()
    stopRoutingButton.backgroundColor = .red
    stopRoutingButton.setTitle("End Route", for: .normal)
    stopRoutingButton.setTitleColor(.white, for: .normal)
    stopRoutingButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
    stopRoutingButton.layer.cornerRadius = 10
    stopRoutingButton.clipsToBounds = true
    stopRoutingButton.addTarget(self, action: #selector(endRoute), for: .touchUpInside)

    let stackView = UIStackView(arrangedSubviews: [stopRoutingButton])
    stackView.disableTranslatesAutoresizingMaskIntoConstraints()
    view.addSubview(stackView)
    [
      view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: stackView.topAnchor, constant: -16),
      view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: -16),
      view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 16),
      view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
    ].activate()
  }

  @objc
  private func endRoute() {
    stateManager.state = .initial
  }
}
