//
//  InstructionGenerator.swift
//  VAMOS
//
//  Created by Jason Keglovitz on 2/1/24.
//

import Foundation
import MapboxDirections
import OSRMTextInstructions

struct StepInfo {
  let step: [String: Any]
  let stepIndex: Int
  let stepInstructions: String?

  var distance: Double {
    return step["distance"] as? Double ?? 0
  }
}

enum InstructionGenerator {
  static func addInstructions(_ jsonData: Data, routeResponse: RouteResponse) -> Data? {
    guard var jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
      print("Error: Cannot create JSON object from string")
      return nil
    }
    
    guard let routes = jsonDict["routes"] as? [[String: Any]] else {
      print("Error: 'routes' not found in JSON")
      return nil
    }
    
    let instructionFormatter = OSRMInstructionFormatter(version: "v5")
    
    var modifiedRoutes = routes
    
    for (routeIndex, route) in routes.enumerated() {
      guard let legs = route["legs"] as? [[String: Any]] else { continue }
      var modifiedLegs = legs
      
      for (legIndex, leg) in legs.enumerated() {
        guard let steps = leg["steps"] as? [[String: Any]] else { continue }
        var modifiedSteps = steps
        
        func getInstructionText(for stepIndex: Int) -> String? {
          instructionFormatter.string(for: routeResponse.routes?[routeIndex].legs[legIndex].steps[stepIndex], legIndex: legIndex, numberOfLegs: legs.count, modifyValueByKey: nil)
        }
        
        for (stepIndex, step) in steps.enumerated() {
          var modifiedStep = step
          
          let currentStepInfo = StepInfo(step: steps[stepIndex], stepIndex: stepIndex, stepInstructions: getInstructionText(for: stepIndex))
          let nextStepInfo: StepInfo? = (stepIndex + 1 < steps.count) ? StepInfo(step: steps[stepIndex + 1], stepIndex: stepIndex + 1, stepInstructions: getInstructionText(for: stepIndex + 1)) : nil
          let nextNextStepInfo: StepInfo? = (stepIndex + 2 < steps.count) ? StepInfo(step: steps[stepIndex + 2], stepIndex: stepIndex + 2, stepInstructions: getInstructionText(for: stepIndex + 2)) : nil
          
          let bannerInstructions = Banner.createInstructions(currentStepInfo: currentStepInfo, nextStepInfo: nextStepInfo, nextNextStepInfo: nextNextStepInfo)
          modifiedStep["bannerInstructions"] = bannerInstructions
          
          let voiceInstructions = Voice.createInstructions(currentStepInfo: currentStepInfo, nextStepInfo: nextStepInfo, nextNextStepInfo: nextNextStepInfo)
          modifiedStep["voiceInstructions"] = voiceInstructions
          
          modifiedSteps[stepIndex] = modifiedStep
        }
        
        modifiedLegs[legIndex]["steps"] = modifiedSteps
      }
      
      modifiedRoutes[routeIndex]["legs"] = modifiedLegs
    }
    
    jsonDict["routes"] = modifiedRoutes
    
    if let modifiedJsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted) {
      return modifiedJsonData
    } else {
      print("Error: Failed to create JSON string from modified dictionary")
      return nil
    }
  }
  
  enum Banner {
    static func createInstructions(currentStepInfo: StepInfo, nextStepInfo: StepInfo?, nextNextStepInfo: StepInfo?) -> [[String: Any]] {
      var bannerInstructions:[[String: Any]] = []
      var bannerInstructionDict: [String: Any] = [:]
      guard let currentStepDistance = currentStepInfo.step["distance"] as? Double, currentStepDistance > 0 else {
        return bannerInstructions
      }
      
      bannerInstructionDict["drivingSide"] = "right"
      bannerInstructionDict["distanceAlongGeometry"] = currentStepDistance
      
      var primaryDict: [String: Any] = [:]
      
      if let nextStepName = nextStepInfo?.step["name"] as? String {
        if nextStepName.isEmpty, let instructionText = nextStepInfo?.stepInstructions {
          primaryDict["text"] = instructionText
        } else {
          primaryDict["text"] = nextStepName
        }
      }
      
      if let nextStepManeuver = nextStepInfo?.step["maneuver"] as? [String: Any] {
        if let nextStepModifier = nextStepManeuver["modifier"] as? String, !nextStepModifier.isEmpty {
          primaryDict["modifier"] = nextStepModifier
        }
        if let nextStepType = nextStepManeuver["type"] as? String, !nextStepType.isEmpty {
          primaryDict["type"] = nextStepType
        }
      }
      
      let components = [
        [
          "type": primaryDict["type"] as? String ?? "",
          "text": primaryDict["text"] as? String ?? ""
        ]
      ]
      primaryDict["components"] = components
      
      bannerInstructionDict["primary"] = primaryDict
      bannerInstructions.append(bannerInstructionDict)
      
      return bannerInstructions
    }
  }
  
  enum Voice {
    struct Instruction {
      let announcement: String?
      let distanceAlongGeometry: Double
      
      var dictionary: [String: Any]? {
        guard let announcement = announcement else { return nil }
        var instructionDict: [String: Any] = [:]
        instructionDict["announcement"] = announcement
        instructionDict["ssmlAnnouncement"] = """
        <speak><amazon:effect name=\"drc\"><prosody rate=\"1.08\">\(announcement)</prosody></amazon:effect></speak>
        """
        instructionDict["distanceAlongGeometry"] = distanceAlongGeometry
        
        return instructionDict
      }
    }
    
    class DepartStep: StandardStep {
      let shortStepThresholdForDeparture: Double = 70

      override func createAdvanceInstructions(currentStepInfo: StepInfo, nextStepInfo: StepInfo, nextNextStepInfo: StepInfo?) -> [Instruction] {
        var instructionList: [Instruction] = []
        let currentStepDistance = currentStepInfo.distance
        
        if currentStepDistance > longStepThreshold {
          instructionList.append(Instruction(announcement: constructDepartAnnouncement(instructions: currentStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: currentStepDistance)), distanceAlongGeometry: currentStepDistance))
          instructionList.append(Instruction(announcement: constructAdvanceAnnouncement(instructions: nextStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: advanceCueDistanceForLongSteps + instructionSpeakingDistance)), distanceAlongGeometry: advanceCueDistanceForLongSteps))
          
        } else if currentStepDistance > advanceStepThreshold {
          instructionList.append(Instruction(announcement: constructDepartAnnouncement(instructions: currentStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: currentStepDistance)), distanceAlongGeometry: currentStepDistance))
          // Mapbox uses something approximate to this to scale the advance distance on the departure step when the departure step is in this intermediate length (between advanceStepThreshold and longStepThreshold).
          let advanceDistance = (currentStepDistance * 0.5) + 50
          instructionList.append(Instruction(announcement: constructAdvanceAnnouncement(instructions: nextStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: advanceDistance + instructionSpeakingDistance)), distanceAlongGeometry: advanceDistance))
          
        } else if currentStepDistance > shortStepThresholdForDeparture {
          instructionList.append(Instruction(announcement: constructLookAheadAnnouncement(firstInstructions: currentStepInfo.stepInstructions, nextInstructions: nextStepInfo.stepInstructions), distanceAlongGeometry: currentStepDistance))
        }
        
        return instructionList
      }
    }
    
    class StandardStep {
      let longStepThreshold: Double = 500
      let advanceStepThreshold: Double = 150
      let shortStepThreshold: Double = 100
      let instructionSpeakingDistance: Double = 20
      let maxCueDistanceForPrimaryInstruction: Double = 50
      let maxCueDistanceForArrival: Double = 5
      let advanceCueDistanceForLongSteps: Double = 283
      
      func createAdvanceInstructions(currentStepInfo: StepInfo, nextStepInfo: StepInfo, nextNextStepInfo: StepInfo?) -> [Instruction] {
        var instructionList: [Instruction] = []
        let currentStepDistance = currentStepInfo.distance
        
        if currentStepDistance > longStepThreshold {
          instructionList.append(Instruction(announcement: constructContinueAnnouncement(currentStepName: currentStepInfo.step["name"] as? String, distanceString: DistanceConverter.convertToEnglishPhrase(from: currentStepDistance - instructionSpeakingDistance)), distanceAlongGeometry: currentStepDistance - instructionSpeakingDistance))
          instructionList.append(Instruction(announcement: constructAdvanceAnnouncement(instructions: nextStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: advanceCueDistanceForLongSteps + instructionSpeakingDistance)), distanceAlongGeometry: advanceCueDistanceForLongSteps))
          
        } else if currentStepDistance > advanceStepThreshold {
          let advanceDistance = currentStepDistance - instructionSpeakingDistance
          instructionList.append(Instruction(announcement: constructAdvanceAnnouncement(instructions: nextStepInfo.stepInstructions, distanceString: DistanceConverter.convertToEnglishPhrase(from: advanceDistance + instructionSpeakingDistance)), distanceAlongGeometry: advanceDistance))
        }
        
        return instructionList
      }
      
      func createPrimaryInstruction(currentStepInfo: StepInfo, nextStepInfo: StepInfo, nextNextStepInfo: StepInfo?) -> Instruction? {
        guard let nextStepInstructions = nextStepInfo.stepInstructions else { return nil }
        let currentStepDistance = currentStepInfo.distance
        let nextStepDistance = nextStepInfo.distance

        let nextStepManeuverType = (nextStepInfo.step["maneuver"] as? [String: Any])?["type"] as? String
        let nextNextStepManeuverType = (nextNextStepInfo?.step["maneuver"] as? [String: Any])?["type"] as? String
        
        let arrival = "arrive"
        let lookAheadArrivalInstruction = "you will arrive at your destination"
        
        let nextNextStepInstructions = (nextNextStepManeuverType == arrival) ? lookAheadArrivalInstruction : nextNextStepInfo?.stepInstructions
        let primaryCueAheadDistance: Double = min(currentStepDistance, (nextStepManeuverType == arrival) ? maxCueDistanceForArrival: maxCueDistanceForPrimaryInstruction)
        
        if nextStepDistance < shortStepThreshold {
          return Instruction(announcement: constructLookAheadAnnouncement(firstInstructions: nextStepInfo.stepInstructions, nextInstructions: nextNextStepInstructions), distanceAlongGeometry: primaryCueAheadDistance)
        } else {
          return Instruction(announcement: nextStepInstructions, distanceAlongGeometry: primaryCueAheadDistance)
        }
      }
    }
    
    static func createInstructions(currentStepInfo: StepInfo, nextStepInfo: StepInfo?, nextNextStepInfo: StepInfo?) -> [[String: Any]] {
      var voiceInstructions: [[String: Any]] = []
      let currentStepDistance = currentStepInfo.distance
      
      guard currentStepDistance > 0, let nextStepInfo else {
        return voiceInstructions
      }
      
      func addVoiceInstruction(_ instruction: Instruction) {
        guard let dictionary = instruction.dictionary else { return }
        voiceInstructions.append(dictionary)
      }
      
      var step: StandardStep
      if currentStepInfo.stepIndex == 0 {
        step = DepartStep()
      } else {
        step = StandardStep()
      }
      let advanceInstructions = step.createAdvanceInstructions(currentStepInfo: currentStepInfo, nextStepInfo: nextStepInfo, nextNextStepInfo: nextNextStepInfo)
      advanceInstructions.forEach({ addVoiceInstruction($0) })
      if let primaryInstruction = step.createPrimaryInstruction(currentStepInfo: currentStepInfo, nextStepInfo: nextStepInfo, nextNextStepInfo: nextNextStepInfo) {
        addVoiceInstruction(primaryInstruction)
      }

      
      return voiceInstructions
    }
    
    private static func constructDepartAnnouncement(instructions: String?, distanceString: String) -> String {
      var departAnnouncement = ""
      if let instructions = instructions {
        departAnnouncement += "\(instructions) for \(distanceString)"
      }
      return departAnnouncement
    }
    
    private static func constructContinueAnnouncement(currentStepName: String?, distanceString: String) -> String {
      var continueAnnouncement = "Continue"
      if let currentStepName = currentStepName {
        continueAnnouncement += " on \(currentStepName) for \(distanceString)"
      }
      return continueAnnouncement
    }
    
    private static func constructAdvanceAnnouncement(instructions: String?, distanceString: String) -> String {
      var announcement = ""
      if let instructions {
        announcement = "In \(distanceString), \(instructions)"
      }
      return announcement
    }
    
    private static func constructLookAheadAnnouncement(firstInstructions: String?, nextInstructions: String?) -> String {
      var announcement = ""
      if let firstInstructions {
        announcement = firstInstructions
        if let nextInstructions {
          announcement += ", then \(nextInstructions)"
        }
      }
      return announcement
    }
  }
}

enum DistanceConverter {
  static func convertToEnglishPhrase(from meters: Double) -> String {
    let metersMeasurement = Measurement(value: meters, unit: UnitLength.meters)
    
    let miles = metersMeasurement.converted(to: UnitLength.miles).value
    let feet = metersMeasurement.converted(to: UnitLength.feet).value

    switch miles {
    case let x where feet >= 1000:
        return englishPhraseForMiles(x)
    case _ where feet >= 600:
        // Round to nearest 200 feet for distances over 600 feet
        let roundedFeet = (feet / 200).rounded() * 200
        return "\(Int(roundedFeet)) feet"
    case _ where feet >= 200:
        // Round to nearest 100 feet for distances over 200 feet
        let roundedFeet = (feet / 100).rounded() * 100
        return "\(Int(roundedFeet)) feet"
    default:
        return "\(Int(feet)) feet"
    }
  }

  private static func englishPhraseForMiles(_ miles: Double) -> String {
    let wholeMiles = Int(miles)
    let fraction = miles - Double(wholeMiles)
    var fractionPhrase = ""
    
    // Adjust these thresholds as needed for accuracy
    let quarterThreshold = 0.125
    let halfThreshold = 0.375
    let threeQuarterThreshold = 0.7
    
    if fraction >= threeQuarterThreshold {
      fractionPhrase = "three-quarters"
    } else if fraction >= halfThreshold {
      fractionPhrase = "a half"
    } else if fraction >= quarterThreshold {
      fractionPhrase = "a quarter"
    }
    
    var phrase = ""
    if wholeMiles > 0 {
      phrase = "\(wholeMiles)"
    }
    
    if !fractionPhrase.isEmpty {
      if !phrase.isEmpty {
        phrase += " and "
      }
      phrase += fractionPhrase
      if wholeMiles == 0 {
        phrase += " mile" // Singular form if only fractional part exists
      } else {
        phrase += " miles" // Plural form if whole miles exist
      }
    } else if wholeMiles > 0 {
      phrase += wholeMiles > 1 ? " miles" : " mile" // Singular/plural form for whole miles
    }
    
    if phrase.isEmpty {
      phrase = "0 miles" // If no miles, then it's 0 miles
    }
    
    return phrase
  }
  
  
  private static func appendOrReplace(_ original: String, with newFragment: String) -> String {
    if original.isEmpty {
      return newFragment
    } else {
      return original + " and " + newFragment
    }
  }
}

extension RouteResponse {
  func printOSRMTextInstructions() {
    // for each RouteStep, print text instruction generated by osrm-text-instructions
    guard let routes = self.routes else { return }
    
    let instructionFormatter = OSRMInstructionFormatter(version: "v5")
    
    for (routeIndex, route) in routes.enumerated() {
      print("Route \(routeIndex)")
      for leg in route.legs {
        for step in leg.steps {
          if let formattedString = instructionFormatter.string(for: step, legIndex: 0, numberOfLegs: 1, modifyValueByKey: nil) {
            print(formattedString as Any)
          }
        }
      }
    }
  }
  
  func printVoiceInstructions() {
    // print voice instructions grouped by RouteStep including distance and distanceAlongStep
    guard let routes = self.routes else { return }
    
    for (routeIndex, route) in routes.enumerated() {
      print("Route \(routeIndex)")
      for leg in route.legs {
        for (stepIndex, step) in leg.steps.enumerated() {
          print(String(format:"%-11d %-10.2f", stepIndex, step.distance))
          if let voiceInstructions = step.instructionsSpokenAlongStep {
            for (voiceInstructionsIndex, voiceInstruction) in voiceInstructions.enumerated() {
              print(String(format:"%-5d %-5d %-10.2f %@", stepIndex, voiceInstructionsIndex, voiceInstruction.distanceAlongStep, voiceInstruction.text))
            }
          }
          print()
        }
      }
    }
  }
  
  func printBannerInstructions() {
    // print banner instructions grouped by RouteStep
    guard let routes = self.routes else { return }
    
    func printBannerInstruction(instructionType: String, instruction: VisualInstruction?) {
      guard let instruction else { return }
      print(String(format: "%@ %@ %@ %@", instructionType, instruction.maneuverType?.rawValue ?? ""
                   , instruction.maneuverDirection?.rawValue ?? "", instruction.text ?? ""))
    }
    
    for (routeIndex, route) in routes.enumerated() {
      print("Route \(routeIndex)")
      for leg in route.legs {
        for (stepIndex, step) in leg.steps.enumerated() {
          print(String(format:"%-11d %-10.2f %-10.2f", stepIndex, step.distance, step.expectedTravelTime))
          if let bannerInstructions = step.instructionsDisplayedAlongStep {
            for (bannerInstructionsIndex, bannerInstruction) in bannerInstructions.enumerated() {
              print(String(format:"%-5d %-5d %-10.2f", stepIndex, bannerInstructionsIndex, bannerInstruction.distanceAlongStep))
              printBannerInstruction(instructionType: "Primary", instruction: bannerInstruction.primaryInstruction)
              printBannerInstruction(instructionType: "Secondary", instruction: bannerInstruction.secondaryInstruction)
              printBannerInstruction(instructionType: "Tertiary", instruction: bannerInstruction.tertiaryInstruction)
              printBannerInstruction(instructionType: "Quaternary", instruction: bannerInstruction.quaternaryInstruction)
            }
          }
          print()
        }
      }
    }
  }
}

