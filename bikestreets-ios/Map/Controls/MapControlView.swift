//
//  MapControlView.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/28/23.
//

import Foundation
import UIKit

private final class MapControlButton: UIButton {

  var imageSystemName: String? = nil {
    didSet {
      let image: UIImage?
      if let imageSystemName {
        image = UIImage(systemName: imageSystemName)
      } else {
        image = nil
      }
      setImage(image, for: .normal)
    }
  }

  /// - Parameters:
  ///     - imageSystemName: The name of the system symbol image
  init() {
    super.init(frame: .zero)

    imageView?.tintColor = .white

    disableTranslatesAutoresizingMaskIntoConstraints()
    [
      heightAnchor.constraint(equalToConstant: 40),
      widthAnchor.constraint(equalToConstant: 40),
    ].activate()

    backgroundColor = .vamosBlue
    clipsToBounds = true
    layer.cornerRadius = 20
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class MapControlView: UIStackView {
  private let mapCameraManager: MapCameraManager

  private let infoButton = MapControlButton()
  private let locationButton = MapControlButton()

  init(mapCameraManager: MapCameraManager) {
    self.mapCameraManager = mapCameraManager

    super.init(frame: .zero)

    mapCameraManager.add(listener: self)

    disableTranslatesAutoresizingMaskIntoConstraints()
    [
      widthAnchor.constraint(equalToConstant: 40)
    ].activate()

    axis = .vertical
    spacing = 8

    [
      infoButton,
      locationButton
    ].forEach {
      addArrangedSubview($0)
    }

    infoButton.imageSystemName = "info"

    locationButton.addTarget(self, action: #selector(fromIdle), for: .touchUpInside)
    syncLocationButtonImage()
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: -- Actions

  @objc
  private func fromIdle() {
    mapCameraManager.fromIdle()
  }

  private func syncLocationButtonImage() {
    locationButton.imageSystemName = mapCameraManager.imageSystemName
  }
}

// MARK: -- MapCameraStateListener

extension MapControlView: MapCameraStateListener {
  func didUpdate(from oldState: MapCameraManager.State, to newState: MapCameraManager.State) {
    syncLocationButtonImage()
  }
}
