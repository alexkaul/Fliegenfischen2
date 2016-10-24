//
//  ViewController.swift
//  Fliegenfischen2
//
//  Created by Alexandra Kaulfuss on 02.10.16.
//  Copyright © 2016 Alexandra Kaulfuss. All rights reserved.
//

//Die Daten des Experten kommen aus einer JSON Datei, sie werden nicht von CoreData verwaltet, deshalb werden sie in diesen structures vorgehalten
struct RecordedDataSetStruct {
    var id: Int64   //zur Zeit ohne Bedeutung
    var recordingTime: Date
    var sensorDataStruct: [SensorDataStruct]
}

struct SensorDataStruct {
    var loggingTime: Date
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var motionPitch: Double
    var motionRoll: Double
    var motionYaw: Double
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
}

import UIKit
import Charts
import CoreMotion
import CoreData
import SwiftyJSON

class ViewController: UIViewController, ChartViewDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate {
    
    let cmMotionManager = CMMotionManager()
    var nsOperationQueue = OperationQueue()
    var countdownSeconds = 0
    var timer: Timer!
    var timestampArray: [NSDate] = []
    var accXArray: [Double] = []
    var dataSets: [LineChartDataSet] = [LineChartDataSet]()
    
    //Für die TableView
    var recordedDataSets: [RecordedDataSet] = []

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timeLabel: UILabel!
    
  
    @IBAction func startRecording(_ sender: AnyObject) {
        
        //Wieviele Sekunden aufgenommen werden soll
        countdownSeconds = 12
        
        //Es soll (vorerst) nur ein aufgenommener Datensatz angezeigt werden
        if (dataSets.count > 1) {
            dataSets.removeLast()
        }
        
        timestampArray = []
        accXArray = []
        
        //Wenn die App im Simulator läuft, ist test = false => kein DeviceMotion available
        //var test = cmMotionManager.isDeviceMotionAvailable
        
        self.cmMotionManager.startAccelerometerUpdates(to: nsOperationQueue, withHandler: {
            
            (accelSensor, error) -> Void in
            if(error != nil) {
                NSLog("\(error)")
            } else {
                //Werte aufnehmen
                let timestamp:NSDate = NSDate()
               
                let accel = accelSensor!.acceleration
                let accX = accel.x

//                let accY = accel.y
//                let accZ = accel.z
                
                //Die folgenden Werte müssen vom MotionSensor ausgelesen werden, nicht vom AccelerationSensor
//                let rotX = 0.0
//                let rotY = 0.0
//                let rotZ = 0.0
//                
//                let yaw = 0.0
//                let roll = 0.0
//                let pitch = 0.0

                self.timestampArray.append(timestamp)
                self.accXArray.append(accX)
            }
        })
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        //Device MotionManager für andere Sensordaten als Accelaration benutzen
        //self.cmMotionManager.deviceMotionUpdateInterval = 0.05
        self.cmMotionManager.accelerometerUpdateInterval = 0.01
        
        self.lineChartView.delegate = self
        self.lineChartView.chartDescription?.text = "x Beschleunigung"
        self.lineChartView.noDataText = "keine Daten vorhanden"
        
        
        self.lineChartView.leftAxis.drawAxisLineEnabled = false
        self.lineChartView.leftAxis.drawGridLinesEnabled = false
        
        
        self.lineChartView.rightAxis.drawAxisLineEnabled = false
        self.lineChartView.rightAxis.drawGridLinesEnabled = false
        
        self.lineChartView.xAxis.drawAxisLineEnabled = false
        self.lineChartView.xAxis.drawGridLinesEnabled = false
        
        let expertData = loadExpertData()
        
        printChart(recordedDataSet: expertData, sensor: 8, person: "expert")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //Daten aus CoreData laden
        getData()
        
        //TableView neu laden
        tableView.reloadData()
    }
    
    func coreDataToStruct(recordedDataSet: RecordedDataSet) -> RecordedDataSetStruct {
        let date = Date()
        let sensorDataStruct: [SensorDataStruct] = []
        var recordedDataSetStruct = RecordedDataSetStruct(id: 0, recordingTime: date, sensorDataStruct: sensorDataStruct)
        
        var sensorDataCoreDataArray: [SensorData] = []
        let sensorDataFromCoreDataSet = recordedDataSet.sensorData
        for sensorData in sensorDataFromCoreDataSet! {
            sensorDataCoreDataArray.append(sensorData as! SensorData)
        }
        
        //SensorDaten werden als unsortiertes Set geladen, hier nach Zeit sortieren:
        sensorDataCoreDataArray.sort{$0.loggingTime < $1.loggingTime}

        if !sensorDataCoreDataArray.isEmpty {
            
            recordedDataSetStruct.recordingTime = sensorDataCoreDataArray[0].loggingTime
            
            for i in 0 ..< sensorDataCoreDataArray.count {
                var sensorDataStruct = SensorDataStruct(loggingTime: date, accelerationX: 0, accelerationY: 0, accelerationZ: 0, motionPitch: 0, motionRoll: 0, motionYaw: 0, rotationX: 0, rotationY: 0, rotationZ: 0)
                sensorDataStruct.loggingTime = sensorDataCoreDataArray[i].loggingTime
                sensorDataStruct.accelerationX = sensorDataCoreDataArray[i].accelerationX
                sensorDataStruct.accelerationY = sensorDataCoreDataArray[i].accelerationY
                sensorDataStruct.accelerationZ = sensorDataCoreDataArray[i].accelerationZ
                sensorDataStruct.rotationX = sensorDataCoreDataArray[i].rotationX
                sensorDataStruct.rotationY = sensorDataCoreDataArray[i].rotationY
                sensorDataStruct.rotationZ = sensorDataCoreDataArray[i].rotationZ
                sensorDataStruct.motionYaw = sensorDataCoreDataArray[i].motionYaw
                sensorDataStruct.motionRoll = sensorDataCoreDataArray[i].motionRoll
                sensorDataStruct.motionPitch = sensorDataCoreDataArray[i].motionPitch
                recordedDataSetStruct.sensorDataStruct.append(sensorDataStruct)
            }
        }
        
        return recordedDataSetStruct
        
    }
    
    func loadExpertData() -> RecordedDataSetStruct {
        var logTime: [Date] = []
        var accelerationX: [Double] = []
        var accelerationY: [Double] = []
        var accelerationZ: [Double] = []
        var rotationX: [Double] = []
        var rotationY: [Double] = []
        var rotationZ: [Double] = []
        var motionYaw: [Double] = []
        var motionRoll: [Double] = []
        var motionPitch: [Double] = []
        
        if let path = Bundle.main.path(forResource: "expertData", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let jsonObj = JSON(data: data)
                
                if jsonObj != JSON.null {
                    
                    if let jsonArray =  jsonObj["loggingTime"].array {
                        for item in jsonArray {
                            if let temp = item.string {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                                let date = dateFormatter.date(from: temp)
                                logTime.append(date!)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["accelerometerAccelerationX"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                accelerationX.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["accelerometerAccelerationY"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                accelerationY.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["accelerometerAccelerationZ"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                accelerationZ.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["gyroRotationX"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                rotationX.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["gyroRotationY"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                rotationY.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["gyroRotationZ"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                rotationZ.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["motionYaw"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                motionYaw.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["motionRoll"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                motionRoll.append(temp)
                            }
                        }
                    }
                    if let jsonArray =  jsonObj["motionPitch"].array {
                        for item in jsonArray {
                            if let temp = item.double {
                                motionPitch.append(temp)
                            }
                        }
                    }
                } else {
                    print("Could not get json from file, make sure that file contains valid json.")
                }
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Could not find file for given filename/path")
        }
        
        let date = Date()
        let sensorDataStruct: [SensorDataStruct] = []
        var expertRecordedDataSet = RecordedDataSetStruct(id: 0, recordingTime: date, sensorDataStruct: sensorDataStruct)
        
        if !logTime.isEmpty {
            expertRecordedDataSet.recordingTime = logTime[0] as Date
        }
        if logTime.count == accelerationX.count &&
        logTime.count == accelerationY.count &&
        logTime.count == accelerationZ.count &&
        logTime.count == rotationX.count &&
        logTime.count == rotationY.count &&
        logTime.count == rotationZ.count &&
        logTime.count == motionYaw.count &&
        logTime.count == motionRoll.count &&
        logTime.count == motionPitch.count {
            for i in 0 ..< logTime.count {
                var sensorDataStruct = SensorDataStruct(loggingTime: date, accelerationX: 0, accelerationY: 0, accelerationZ: 0, motionPitch: 0, motionRoll: 0, motionYaw: 0, rotationX: 0, rotationY: 0, rotationZ: 0)
                sensorDataStruct.loggingTime = logTime[i]
                sensorDataStruct.accelerationX = accelerationX[i]
                sensorDataStruct.accelerationY = accelerationY[i]
                sensorDataStruct.accelerationZ = accelerationZ[i]
                sensorDataStruct.rotationX = rotationX[i]
                sensorDataStruct.rotationY = rotationY[i]
                sensorDataStruct.rotationZ = rotationZ[i]
                sensorDataStruct.motionYaw = motionYaw[i]
                sensorDataStruct.motionRoll = motionRoll[i]
                sensorDataStruct.motionPitch = motionPitch[i]
                expertRecordedDataSet.sensorDataStruct.append(sensorDataStruct)
            }
        }
        return expertRecordedDataSet
    }
    
    func printChart(recordedDataSet: RecordedDataSetStruct, sensor: Int, person: String) {
        
        //Den letzten angezeigten Datensatz entfernen, Expertendaten da lassen
        if (dataSets.count > 1) {
            dataSets.removeLast()
        }
        
        //var sensorDataArray: [SensorDataStruct] = []
        var sensorValuesArray: [Double] = []
        //let sensorDataFromRecordedDataSet = recordedDataSet.sensorDataStruct
        
        //for sensorData in sensorDataFromRecordedDataSet! {
        //    sensorDataArray.append(sensorData as! SensorDataStruct)
        //}
        
        //SensorDaten werden als unsortiertes Set geladen, hier nach Zeit sortieren:
        //sensorDataArray.sort{$0.loggingTime < $1.loggingTime}
        
        for i in 0..<recordedDataSet.sensorDataStruct.count {
            switch sensor {
            case 0:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].accelerationX)
            case 1:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].accelerationY)
            case 2:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].accelerationZ)
            case 3:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].rotationX)
            case 4:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].rotationY)
            case 5:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].rotationZ)
            case 6:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].motionYaw)
            case 7:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].motionRoll)
            case 8:
                sensorValuesArray.append(recordedDataSet.sensorDataStruct[i].motionPitch)
            default:
                sensorValuesArray.append(0.0)
            }
        }
        
        var chartValues:[ChartDataEntry] = [ChartDataEntry]()
        for i in 0 ..< sensorValuesArray.count {
            chartValues.append(ChartDataEntry(x: Double(i), y: sensorValuesArray[i]))
        }
        
        var chartLabelText: String
        var color: [UIColor]
        
        switch person {
        case "expert":
            chartLabelText = "Experte"
            color = [UIColor.cyan]
        case "user":
            //Die Beschriftung für den Graph erstellen:
            let timestamp = recordedDataSet.recordingTime
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd.MM.yyyy"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            var dateString = ""
            var timeString = ""
            dateString = dateFormatter.string(from: timestamp)
            timeString = timeFormatter.string(from: timestamp)
            chartLabelText = "\(dateString) - \(timeString)"
            color = [UIColor.red]
        default:
            chartLabelText = ""
            color = [UIColor.cyan]
        }
        
        let set:LineChartDataSet = LineChartDataSet(values: chartValues, label: chartLabelText)
        set.axisDependency = .left
        set.mode = .cubicBezier
        set.drawCirclesEnabled = false
        set.colors = color
        dataSets.append(set)
        let data:LineChartData = LineChartData(dataSets: dataSets)
        self.lineChartView.data = data
    }
    
    //läuft 12 Sekunden lang, dann werden die Daten aus Array in CoreData gespeichert
    func update() {
        if(countdownSeconds >= 0) {
            timeLabel.text = String(countdownSeconds) + " Sekunden"
            countdownSeconds -= 1
        } else {
            timeLabel.text = "Verbleibende Zeit"
            //cmMotionManager.stopDeviceMotionUpdates()
            cmMotionManager.stopAccelerometerUpdates()
            timer.invalidate()
            saveDataToCoreData()
        }
    }
    
    func saveDataToCoreData() {
        
        
        //Neuen Context (Verknüpfung zu CoreData) erstellen
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        
        //Neuen Datensatz erstellen
        let recordedDataSet = RecordedDataSet(context: context)
        recordedDataSet.recordingTime = timestampArray[0] as Date
        
        
        for i in 0..<timestampArray.count {
            
            //Die aufgenommenen Daten in ein SensorData Objekt speichern
            let sensorData = SensorData(context: context)
            
            sensorData.loggingTime = timestampArray[i] as Date
            sensorData.accelerationX = accXArray[i]
            sensorData.accelerationY = 0.0
            sensorData.accelerationZ = 0.0
            
            sensorData.rotationX = 0.0
            sensorData.rotationY = 0.0
            sensorData.rotationZ = 0.0
            
            sensorData.motionYaw = 0.0
            sensorData.motionRoll = 0.0
            sensorData.motionPitch = 0.0
            
            //Die gerade aufgenommenen Werte dem Datensatz hinzufügen
            recordedDataSet.addToSensorData(sensorData)
        }
        
        //Daten in CoreData speichern
        (UIApplication.shared.delegate as! AppDelegate).saveContext()
        
        //Daten aus CoreData laden
        getData()
        
        //TableView neu laden
        tableView.reloadData()
        
    }

    
    
    /**
     Gibt die Anzahl der aufgenommenen Datensätze = Anzahl der Tabellenzeilen zurück
     */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordedDataSets.count
    }
    
    
    /**
     Schreibt die aufgenommenen Datensätze in die Tabellenzeilen
     */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        let recordedDataSet = recordedDataSets[indexPath.row]

            let timestamp = recordedDataSet.recordingTime
        
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd.MM.yyyy"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            var dateString = ""
            var timeString = ""
        
            if timestamp != nil {
                dateString = dateFormatter.string(from: timestamp!)
                timeString = timeFormatter.string(from: timestamp!)
        
        cell.textLabel?.text = "\(dateString) - \(timeString) Uhr"
        }
        
        return cell
    }
    
    
    func getData() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        do {
            recordedDataSets = try context.fetch(RecordedDataSet.fetchRequest())
        } catch {
            print("Fetching failed")
        }
        
    }
    
    /**
     Die Funktion löscht einen Datensatz aus der Tabelle, wenn geswiped wird
    */
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        if editingStyle == .delete {
            let recordedDataSet = recordedDataSets[indexPath.row]
            context.delete(recordedDataSet)
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            
            do {
                recordedDataSets = try context.fetch(RecordedDataSet.fetchRequest())
            } catch {
                print("Fetching failed")
            }
        }
        tableView.reloadData()
    }

    
    /**
     Wenn eine Zeile in der Tabelle angeklickt wird:
    */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var accX: [Double] = []
        var sensorDataArray: [SensorData] = []
        
        let recordedDataSet = recordedDataSets[indexPath.row]
        let sensorDatas = recordedDataSet.sensorData
        
        
        
        
        
        //TODO: Hier die geholten Sachen in lokale Klassen umwandeln!!!
        //test, obs klappt:
        let recordedDataSetStruct = coreDataToStruct(recordedDataSet: recordedDataSet)
        
        
        
        for sensorData in sensorDatas! {
            sensorDataArray.append(sensorData as! SensorData)
        }
    
        //SensorDaten werden als unsortiertes Set geladen, hier nach Zeit sortieren:
        sensorDataArray.sort{$0.loggingTime < $1.loggingTime}
            
        for i in 0..<sensorDataArray.count {
            accX.append(sensorDataArray[i].accelerationX)
        }
        
        //Die Beschriftung für den Graph erstellen:
        let timestamp = recordedDataSet.recordingTime
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        var dateString = ""
        var timeString = ""
        
        if timestamp != nil {
            dateString = dateFormatter.string(from: timestamp!)
            timeString = timeFormatter.string(from: timestamp!)
        }
        
        let graphLabelText = "\(dateString) - \(timeString)"
        
        
        //Das Chart updaten:
        
        //Den letzten angezeigten Datensatz entfernen, Expertendaten da lassen
        if (dataSets.count > 1) {
            dataSets.removeLast()
        }
        
        var yValues:[ChartDataEntry] = [ChartDataEntry]()
        for i in 0 ..< accX.count {
            yValues.append(ChartDataEntry(x: Double(i), y: accX[i]))
        }
        
        
        let set:LineChartDataSet = LineChartDataSet(values: yValues, label: graphLabelText)
        set.axisDependency = .left
        set.mode = .cubicBezier
        set.drawCirclesEnabled = false
        set.colors = [UIColor.red]
        dataSets.append(set)
        let data:LineChartData = LineChartData(dataSets: dataSets)
        self.lineChartView.data = data
        
    }
    
    /**
     Wenn eine Zeile abgewählt wird:
     */
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
