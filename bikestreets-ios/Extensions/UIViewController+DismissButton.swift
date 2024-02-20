//
//  UIViewController+DismissButton.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/17/24.
//

import Foundation
import UIKit

extension UIViewController {
  func configureDismissButton(action: Selector) {
    let dismissButton = DismissButton()
    view.addSubview(dismissButton)
    
    dismissButton.disableTranslatesAutoresizingMaskIntoConstraints()
    [
      dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      dismissButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      dismissButton.widthAnchor.constraint(equalToConstant: 30),
      dismissButton.heightAnchor.constraint(equalToConstant: 30)
    ].activate()
    
    dismissButton.addTarget(self, action: action, for: .touchUpInside)
  }
}

final class DismissButton: UIButton {
  init() {
    super.init(frame: .zero)
    configureButton()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func configureButton() {
    setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(weight: .bold)), for: .normal)
    layer.cornerRadius = 15
    frame.size = CGSize(width: 30, height: 3)
    updateColors()
  }
  
  private func updateColors() {
    tintColor = .accessoryButtonTintColor
    backgroundColor = .accessoryButtonBackgroundColor
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
   
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      updateColors()
    }
  }
}
