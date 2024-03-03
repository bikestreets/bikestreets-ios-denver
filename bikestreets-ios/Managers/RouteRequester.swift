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

extension Route {
  var coordinates: [CLLocationCoordinate2D] {
    return shape?.coordinates ?? []
  }
}

/// Representation of the route response from the BikeStreets internal OSRM API
/// Wrapping RouteResponse so that we can control which routes are available to preview
struct CustomRouteResponse {
  let osrm: RouteResponse

  public var routes: [Route]? {
    return osrm.routes
  }
}

final class RouteRequester {
  private static let mapboxAPIMode = InternalMapboxAPIMode.mapMatching

  enum RequestError: Error {
    case emptyData
    case unableToParse
  }

  private static func getOSRMPath(startPoint: CLLocationCoordinate2D, endPoint: CLLocationCoordinate2D) -> String {
    var startLatitude = startPoint.latitude
    var startLongitude = startPoint.longitude
    var endLatitude = endPoint.latitude
    var endLongitude = endPoint.longitude
    
    // for ease of pasting in fixed coordinates when testing
    let startOverrideString = "39.7092943, -104.9757300"
    let endOverrideString = "39.7201333, -104.9752361"
    let overrideCoordinates = false
    
    func parseCoordinates(from string: String) -> (CLLocationDegrees, CLLocationDegrees)? {
      let components = string.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      
      guard components.count == 2 else { return nil }
      guard let latitude = Double(components[0]), let longitude = Double(components[1]) else { return nil }

      return (latitude, longitude)
    }
    
    if overrideCoordinates,
        let startOverride = parseCoordinates(from: startOverrideString),
        let endOverride = parseCoordinates(from: endOverrideString) {
      
      startLatitude = startOverride.0
      startLongitude = startOverride.1
      endLatitude = endOverride.0
      endLongitude = endOverride.1
    }
    
    return "/route/v1/bike/\(startLongitude),\(startLatitude);\(endLongitude),\(endLatitude)"
  }
  
  static func getOSRMDirections(
    startPoint: CLLocationCoordinate2D,
    endPoint: CLLocationCoordinate2D,
    bearing: CLLocationDirection? = nil,
    completion: @escaping (Result<CustomRouteResponse, Error>) -> Void
  ) {
    // BIKESTREETS DIRECTIONS

    //  206.189.205.9/route/v1/driving/-105.03667831420898,39.745358641453315;-105.04232168197632,39.74052436233521?overview=false&alternatives=true&steps=true&annotations=true
    var components = URLComponents()
    components.scheme = "http"
    components.host = "206.189.205.9"
    components.percentEncodedPath = getOSRMPath(startPoint: startPoint, endPoint: endPoint)

    components.queryItems = [
      URLQueryItem(name: "overview", value: "full"),
      URLQueryItem(name: "geometries", value: "polyline"),
      URLQueryItem(name: "steps", value: "true"),
      URLQueryItem(name: "annotations", value: "true")
    ]
    if let bearing {
      // if bearing is passed, we are rerouting: use bearing and don't request alternative routes
      let bearingInteger = Int(bearing)
      let searchRadius = 5
      let bearingTolerance = 15
      // if bearing is 90 with bearingTolerance of 15 and radius 10, then segments with bearings of 75-115 within 10 meters will be matched
      components.queryItems?.append(contentsOf: [
        URLQueryItem(name: "radiuses", value: "\(searchRadius);"),
        URLQueryItem(name: "bearings", value: "\(bearingInteger),\(bearingTolerance);")
      ])
    } else {
      // initial route request - find alternatives
      components.queryItems?.append(contentsOf: [
        URLQueryItem(name: "alternatives", value: "true")
      ])
    }
    print("""
    OSRM REQUEST:

    \(components.string ?? "ERROR EMPTY")
    
    """)

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

        // Check if start/end points yield a FixedResponse
        var dataWithInstructions: Data?
        if let fixedData = FixedRouteResponse.getData(startPoint: startPoint, endPoint: endPoint) {
          dataWithInstructions = fixedData
        } else {
          let rawOSRMResponse = try decoder.decode(RouteResponse.self, from: data)
          dataWithInstructions = InstructionGenerator.addInstructions(data, routeResponse: rawOSRMResponse)
        }
        
        let osrmResponse = try decoder.decode(RouteResponse.self, from: dataWithInstructions ?? data)
        print("""
        
        ==== OSRM ====
        
        """)
        //osrmResponse.printVoiceInstructions()
        //osrmResponse.printOSRMTextInstructions()
        //osrmResponse.printJSON()
        
        completion(.success(.init(osrm: osrmResponse)))
        
        // For comparing Mapbox route/instructions to OSRM route/instructions
        // requestMapboxDirections(osrmResponse: osrmResponse)
      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
  
  static func requestMapboxDirections(osrmResponse: RouteResponse) -> Void {
    // Request Mapbox route
    //
    // Copied from: https://docs.mapbox.com/ios/navigation/examples/custom-server/
    let originalRouteCoordinates = osrmResponse.routes?[0].shape?.coordinates ?? []

    var tolerance: Float = 0.000001
    var simplifiedRouteCoordinates = originalRouteCoordinates
    while simplifiedRouteCoordinates.count > mapboxAPIMode.maximumCoordinates {
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
    
    switch mapboxAPIMode {
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
          mapboxResponse.printVoiceInstructions()
          mapboxResponse.printOSRMTextInstructions()
          mapboxResponse.printJSON()
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
          mapboxResponse.printVoiceInstructions()
          mapboxResponse.printOSRMTextInstructions()
          mapboxResponse.printJSON()
        }
      }
    }
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

final class FixedRouteResponse {
  // Hard-coded routes that can be loaded from disk based on proximity to requested start/end locations
  // Easter egg instruction testing
  enum FixedRouteSpec: String, CaseIterable {
    case dakotaMarion =  "dakota-marion"
    
    var startLocation: CLLocation {
      switch self {
      case .dakotaMarion:
        return CLLocation(latitude: 39.70929, longitude: -104.97573)
      }
    }
    
    var endLocation: CLLocation {
      switch self {
      case .dakotaMarion:
        return CLLocation(latitude: 39.72013, longitude: -104.97523)
      }
    }
  }
  
  static func getData(startPoint: CLLocationCoordinate2D, endPoint: CLLocationCoordinate2D) -> Data? {
    let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
    let endLocation = CLLocation(latitude: endPoint.latitude, longitude: endPoint.longitude)
    let tolerance: Double = 10.0
    
    for fixedRoute in FixedRouteSpec.allCases {
      if fixedRoute.startLocation.distance(from: startLocation) < tolerance,
          fixedRoute.endLocation.distance(from: endLocation) < tolerance
        {
        if let routeData = fromFile(named: fixedRoute.rawValue) {
          return routeData
        }
      }
    }
    return nil
  }
  
  private static func fromFile(named fileName: String) -> Data? {
    let fileExtension = "txt"
    
    guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
      print("File \(fileName).txt not found")
      return nil
    }
    do {
      let data = try Data(contentsOf: url)
      return data
    } catch {
      print("Error reading \(fileName).\(fileExtension): \(error)")
      return nil
    }
  }
}
