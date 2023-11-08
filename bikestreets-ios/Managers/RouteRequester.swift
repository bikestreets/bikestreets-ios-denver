//
//  RouteRequester.swift
//  BikeStreets
//
//  Created by Matt Robinson on 8/4/23.
//

import CoreLocation
import Foundation
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import SimplifySwift

final class RouteRequester {
  enum RequestError: Error {
    case emptyData
    case unableToParse
  }

  static func getOSRMDirections(
    originName: String,
    startPoint: CLLocationCoordinate2D,
    destinationName: String,
    endPoint: CLLocationCoordinate2D,
    completion: @escaping (Result<RouteResponse, Error>) -> Void
  ) {
    // BIKESTREETS DIRECTIONS

    //  206.189.205.9/route/v1/driving/-105.03667831420898,39.745358641453315;-105.04232168197632,39.74052436233521?overview=false&alternatives=true&steps=true&annotations=true
    var components = URLComponents()
    components.scheme = "http"
    components.host = "206.189.205.9"
    components.percentEncodedPath = "/route/v1/bike/\(startPoint.longitude),\(startPoint.latitude);\(endPoint.longitude),\(endPoint.latitude)"

    print("""
    OSRM REQUEST:

    \(components.string ?? "ERROR EMPTY")

    """)

    components.queryItems = [
      URLQueryItem(name: "overview", value: "full"),
      URLQueryItem(name: "geometries", value: "polyline"),
      URLQueryItem(name: "alternatives", value: "true"),
      URLQueryItem(name: "steps", value: "true"),
      URLQueryItem(name: "annotations", value: "true"),

      // URLQueryItem(name: "voice_instructions", value: String(true)),
      // let distanceMeasurementSystem: MeasurementSystem = Locale.current.usesMetricSystem ? .metric : .imperial
      // URLQueryItem(name: "voice_units", value: distanceMeasurementSystem.rawValue),
    ]

    let session = URLSession.shared
    let request = URLRequest(url: components.url!)
    let task = session.dataTask(with: request) { [completion] data, _, error in
      // Handle HTTP request error
      guard error == nil else {
        completion(.failure(error!))
        return
      }

      guard let data else {
        completion(.failure(RequestError.emptyData))
        return
      }

      // Handle HTTP request response
      do {
        // For pretty printing in logging:
        // let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        // let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

        let routeOptions = NavigationRouteOptions(
          coordinates: [startPoint, endPoint],
          profileIdentifier: .cycling
        )
        routeOptions.shapeFormat = .polyline

        let decoder = JSONDecoder()
        decoder.userInfo = [
          .options: routeOptions,
          .credentials: Directions.shared.credentials,
        ]

        let result = try decoder.decode(RouteResponse.self, from: data)

        // Request Mapbox route
        //
        // Copied from: https://docs.mapbox.com/ios/navigation/examples/custom-server/
        let originalRouteCoordinates = result.routes?[0].shape?.coordinates ?? []

        var tolerance: Float = 0.00001
        var simplifiedRouteCoordinates = originalRouteCoordinates
        while simplifiedRouteCoordinates.count > 500 {
          simplifiedRouteCoordinates = Simplify.simplify(originalRouteCoordinates, tolerance: tolerance, highQuality: true)
          tolerance += 0.000005
        }

        print("""

        ROUTE SIMPLIFICATION
        Before: \(originalRouteCoordinates.count)
        After:  \(simplifiedRouteCoordinates.count)


        """)

        //
        // ❗️IMPORTANT❗️
        // Use `Directions.calculateRoutes(matching:completionHandler:)` for navigating on a map matching response.
        //
        let matchOptions = NavigationMatchOptions(coordinates: simplifiedRouteCoordinates, profileIdentifier: .cycling)
        matchOptions.includesSpokenInstructions = true
        matchOptions.includesVisualInstructions = true

        // By default, each waypoint separates two legs, so the user stops at each waypoint.
        // We want the user to navigate from the first coordinate to the last coordinate without any stops in between.
        // You can specify more intermediate waypoints here if you’d like.
        for waypoint in matchOptions.waypoints.dropFirst().dropLast() {
          waypoint.separatesLegs = false
        }

        Directions.shared.calculateRoutes(matching: matchOptions) { _, mapboxResult in
          switch mapboxResult {
          case .failure(let error):
            print(error.localizedDescription)
          case .success(let response):
            // Return parsed response
            completion(.success(response))
          }
        }

      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
}
