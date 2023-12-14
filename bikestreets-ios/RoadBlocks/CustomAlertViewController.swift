//
//  CustomAlertViewController.swift
//  BikeStreets
//
//  Created by Matt Robinson on 12/7/23.
//

import Foundation
import UIKit
import SafariServices

final class CustomAlertViewController: UIViewController {
  struct Configuration {
    enum ButtonConfiguration {
      case openURL(text: String, url: URL)
      case accept(text: String, callback: (UIViewController) -> Void)
    }

    let body: String
    let buttons: [ButtonConfiguration]
  }

  private let configuration: Configuration

  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)

    // Block dismissal other than using the buttons on the alert.
    isModalInPresentation = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .clear

    let backgroundView = UIView()
    backgroundView.backgroundColor = UIColor.systemBackground
    backgroundView.disableTranslatesAutoresizingMaskIntoConstraints()
    backgroundView.layer.cornerRadius = 14
    backgroundView.clipsToBounds = true
    view.addSubview(backgroundView)
    [
      backgroundView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40),
      backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      // Allow the height to grow organically
    ].activate()

    let image = UIImage(named: "vamos-logo")!
    let imageView = UIImageView(image: image)
    imageView.disableTranslatesAutoresizingMaskIntoConstraints()
    imageView.heightAnchor.constraint(
      equalTo: imageView.widthAnchor,
      multiplier: image.size.height / image.size.width
    ).isActive = true
    imageView.contentMode = .scaleAspectFit

    let labelView = UILabel()
    labelView.text = configuration.body
    labelView.numberOfLines = 0
    labelView.textAlignment = .center

    let learnMoreButton = UIButton(configuration: .bordered())
    learnMoreButton.setTitle("Learn More", for: .normal)
    learnMoreButton.titleLabel?.textAlignment = .center

    let shareLocationButton = UIButton(configuration: .bordered())
    shareLocationButton.setTitle("Share Location", for: .normal)
    shareLocationButton.titleLabel?.textAlignment = .center

    let buttonStackView = UIStackView(arrangedSubviews: createButtonViews(configuration.buttons))
    buttonStackView.axis = .horizontal
    buttonStackView.spacing = 8

    let stackView = UIStackView(arrangedSubviews: [imageView, labelView, buttonStackView])
    stackView.axis = .vertical
    stackView.distribution = .fill
    stackView.spacing = 16
    stackView.disableTranslatesAutoresizingMaskIntoConstraints()
    backgroundView.addSubview(stackView)
    backgroundView.matchAutolayoutSize(stackView, insets: .init(
      top: 20,
      left: 20,
      bottom: -20,
      right: -20
    ))
  }

  private func createButtonViews(_ buttonConfigurations: [Configuration.ButtonConfiguration]) -> [UIView] {
    buttonConfigurations.enumerated().map { index, configuration in
      switch configuration {
      case .accept(let text, _):
        let button = UIButton(configuration: .bordered())
        button.setTitle(text, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.tag = index
        button.addTarget(self, action: #selector(handleButtonSelection(view:)), for: .touchUpInside)
        return button
      case .openURL(let text, _):
        let button = UIButton(configuration: .bordered())
        button.setTitle(text, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.tag = index
        button.addTarget(self, action: #selector(handleURLPresentation(view:)), for: .touchUpInside)
        return button
      }
    }
  }

  @objc
  private func handleButtonSelection(view: UIButton) {
    let button = configuration.buttons[view.tag]
    if case let .accept(_, callback) = button {
      callback(self)
    }
  }

  @objc
  private func handleURLPresentation(view: UIButton) {
    let button = configuration.buttons[view.tag]
    if case let .openURL(_, url) = button {
      let vc = SFSafariViewController(url: url)
      present(vc, animated: true)
    }
  }
}
