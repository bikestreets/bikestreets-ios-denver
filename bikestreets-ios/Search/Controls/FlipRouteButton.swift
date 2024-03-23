//
//  FlipRouteButton.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 3/17/24.
//

import Foundation
import UIKit

final class FlipRouteButton: UIButton {
  init() {
    super.init(frame: .zero)
    
    let image = UIImage(systemName: "arrow.triangle.swap", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24.0, weight: .light, scale: .small))
    setImage(image, for: .normal)
    backgroundColor = UIColor.flipRouteButtonBackground
    tintColor = UIColor.flipRouteButtonTint
    layer.cornerRadius = 8
    layer.borderWidth = 1
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    // Border colors use CALayer and do not pick up UIKit traitCollectionChanges using Assets.ColorSet automatically
    layer.borderColor = UIColor.flipRouteButtonBorder.cgColor
  }
}
