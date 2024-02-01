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

/// Switchable mode for the backend type to use with Mapbox.
enum InternalMapboxAPIMode {
  /// Mapbox Directions API: https://docs.mapbox.com/ios/navigation/guides/turn-by-turn-navigation/route-generation/
  case directions
  /// Mapbox Map Matching API: https://docs.mapbox.com/api/navigation/map-matching/
  case mapMatching

  /// Maximum coordinates allowed by Mapbox in the given request.
  var maximumCoordinates: Int {
    switch self {
    case .directions: return 200
    case .mapMatching: return 500
    }
  }
}

/// Combination of the generated OSRM and Mapbox routes.
struct CombinedRoute {
  let osrm: Route
  let mapbox: Route

  // MARK: -- Coordinates

  var osrmCoordinates: [CLLocationCoordinate2D] {
    osrm.shape?.coordinates ?? []
  }

  var mapboxCoordinates: [CLLocationCoordinate2D] {
    mapbox.shape?.coordinates ?? []
  }
}

/// Representation of the route response from the BikeStreets internal OSRM API
/// and the external Mapbox API.
struct CombinedRouteResponse {
  let osrm: RouteResponse
  let mapbox: RouteResponse

  /// An array of `Route` objects based on the choice to use the OSRM or Mapbox backend.
  public var routes: [Route]? {
    // Intentionally just select the first route, adjust in the
    // future if desired.
    switch GlobalSettings.liveRoutingConfiguration {
    case .mapbox:
      return mapbox.routes?.first.map { [$0] }
    case .custom:
      return osrm.routes?.first.map { [$0] }
    }
  }
}

final class RouteRequester {
  private static let mode = InternalMapboxAPIMode.mapMatching

  enum RequestError: Error {
    case emptyData
    case unableToParse
  }

  static func getOSRMDirections(
    originName: String,
    startPoint: CLLocationCoordinate2D,
    destinationName: String,
    endPoint: CLLocationCoordinate2D,
    completion: @escaping (Result<CombinedRouteResponse, Error>) -> Void
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

        // leaving this in, as it is sometimes useful to load previously created RouteResponse JSON from disk with manual tweaks
        func loadDataFromFile(filePath: String) -> Data? {
          let url = URL(fileURLWithPath: filePath)
          
          do {
              return try Data(contentsOf: url)
          } catch {
              print("Failed to load \(filePath) from bundle:\n\(error)")
              return nil
          }
        }
          
        let decoder = JSONDecoder()
        decoder.userInfo = [
          .options: routeOptions,
          .credentials: Directions.shared.credentials,
        ]

        let rawOSRMResponse = try decoder.decode(RouteResponse.self, from: data)
        let dataWithInstructions = InstructionGenerator.addInstructions(data, routeResponse: rawOSRMResponse)
        let osrmResponse = try decoder.decode(RouteResponse.self, from: dataWithInstructions ?? data)
        print("""
        
        ==== OSRM ====
        
        """)
        //osrmResponse.printVoiceInstructions()
        //osrmResponse.printOSRMTextInstructions()
        //osrmResponse.printJSON()
        
        // Request Mapbox route
        //
        // Copied from: https://docs.mapbox.com/ios/navigation/examples/custom-server/
        let originalRouteCoordinates = osrmResponse.routes?[0].shape?.coordinates ?? []

        var tolerance: Float = 0.000001
        var simplifiedRouteCoordinates = originalRouteCoordinates
        while simplifiedRouteCoordinates.count > mode.maximumCoordinates {
          simplifiedRouteCoordinates = Simplify.simplify(originalRouteCoordinates, tolerance: tolerance, highQuality: true)
          tolerance += 0.0000025
        }

        print("""

        ROUTE SIMPLIFICATION
        Before: \(originalRouteCoordinates.count)
        After:  \(simplifiedRouteCoordinates.count)


        """)

        print("""
        
        ==== MAPBOX ====
        
        """)
        switch mode {
        case .mapMatching:
          //
          // ❗️IMPORTANT❗️
          // Use `Directions.calculateRoutes(matching:completionHandler:)` for navigating on a map matching response.
          //
          let matchOptions = NavigationMatchOptions(
            coordinates: simplifiedRouteCoordinates,
            profileIdentifier: .cycling
          )
          matchOptions.includesSpokenInstructions = true
          matchOptions.includesVisualInstructions = true
          matchOptions.waypoints.disableWaypointLegSeparation()

          Directions.shared.calculateRoutes(matching: matchOptions) { _, mapboxResult in
            switch mapboxResult {
            case .failure(let error):
              print(error.localizedDescription)
            case .success(let mapboxResponse):
              // Return parsed response
              //mapboxResponse.printVoiceInstructions()
              //mapboxResponse.printOSRMTextInstructions()
              //mapboxResponse.printJSON()
              
              completion(.success(.init(osrm: osrmResponse, mapbox: mapboxResponse)))
            }
          }
        case .directions:
          let routeOptions = NavigationRouteOptions(
            coordinates: simplifiedRouteCoordinates,
            profileIdentifier: .cycling
          )
          routeOptions.includesSpokenInstructions = true
          routeOptions.includesVisualInstructions = true
          routeOptions.waypoints.disableWaypointLegSeparation()

          Directions.shared.calculate(routeOptions) { _, mapboxResult in
            switch mapboxResult {
            case .failure(let error):
              print(error.localizedDescription)
            case .success(let mapboxResponse):
              //mapboxResponse.printVoiceInstructions()
              //mapboxResponse.printOSRMTextInstructions()
              //mapboxResponse.printJSON()
              completion(.success(.init(osrm: osrmResponse, mapbox: mapboxResponse)))
            }
          }
        }

      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
}

// MARK: -- Waypoint Mutation

extension RouteResponse {
  func printJSON() {
    // pretty print JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    do {
      let jsonData = try encoder.encode(self)
            
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
      }
    }
    catch {
      print("Error encoding RouteResponse: \(error)")
    }
  }
}

extension Array where Element == Waypoint {
  /// By default, each waypoint separates two legs, so the user stops at each
  /// waypoint. We want the user to navigate from the first coordinate to the
  /// last coordinate without any stops in between. You can specify more
  /// intermediate waypoints here if you’d like.
  func disableWaypointLegSeparation() {
    for waypoint in dropFirst().dropLast() {
      waypoint.separatesLegs = false
    }
  }
}
