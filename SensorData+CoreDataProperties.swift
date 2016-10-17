//
//  SensorData+CoreDataProperties.swift
//  Fliegenfischen2
//
//  Created by Alexandra Kaulfuss on 16.10.16.
//  Copyright © 2016 Alexandra Kaulfuss. All rights reserved.
//

import Foundation
import CoreData

extension SensorData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SensorData> {
        return NSFetchRequest<SensorData>(entityName: "SensorData");
    }

    @NSManaged public var accelerationX: Double
    @NSManaged public var accelerationY: Double
    @NSManaged public var accelerationZ: Double
    @NSManaged public var loggingTime: Date
    @NSManaged public var motionPitch: Double
    @NSManaged public var motionRoll: Double
    @NSManaged public var motionYaw: Double
    @NSManaged public var rotationX: Double
    @NSManaged public var rotationY: Double
    @NSManaged public var rotationZ: Double
    @NSManaged public var recordedDataSet: RecordedDataSet?

}
