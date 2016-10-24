//
//  RecordedDataSet+CoreDataProperties.swift
//  Fliegenfischen2
//
//  Created by Alexandra Kaulfuss on 16.10.16.
//  Copyright © 2016 Alexandra Kaulfuss. All rights reserved.
//

import Foundation
import CoreData

extension RecordedDataSet {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordedDataSet> {
        return NSFetchRequest<RecordedDataSet>(entityName: "RecordedDataSet");
    }

    @NSManaged public var id: Int64
    @NSManaged public var recordingTime: Date?
    @NSManaged public var sensorData: NSSet?

}

// MARK: Generated accessors for sensorData
extension RecordedDataSet {

    @objc(addSensorDataObject:)
    @NSManaged public func addToSensorData(_ value: SensorData)

    @objc(removeSensorDataObject:)
    @NSManaged public func removeFromSensorData(_ value: SensorData)

    @objc(addSensorData:)
    @NSManaged public func addToSensorData(_ values: NSSet)

    @objc(removeSensorData:)
    @NSManaged public func removeFromSensorData(_ values: NSSet)

}
