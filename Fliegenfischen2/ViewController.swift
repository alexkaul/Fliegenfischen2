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
    
    init() {
        id = 0
        recordingTime = Date()
        sensorDataStruct = []
    }
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
import AVFoundation

class ViewController: UIViewController, ChartViewDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate {
    
    let cmMotionManager = CMMotionManager()
    var nsOperationQueue = OperationQueue()
    var timer: Timer!
    
    
    //In diesen Arrays werden die aufgenommen Sensordaten zwischengespeichert, bis sie persistiert werden
    var timestampArray: [Date] = []
    var accXArray: [Double] = []
    var accYArray: [Double] = []
    var accZArray: [Double] = []
    var rotXArray: [Double] = []
    var rotYArray: [Double] = []
    var rotZArray: [Double] = []
    var yawArray: [Double] = []
    var rollArray: [Double] = []
    var pitchArray: [Double] = []
    
    var selectedSensor = 0
    var expertData = RecordedDataSetStruct()
    var userData = RecordedDataSetStruct()
    
    @IBOutlet weak var timeSelectorSliderVar: UISlider!
    var selectedTime = 10
    var countdownSeconds = 10
    
    var dataSets: [LineChartDataSet] = [LineChartDataSet]()
    
    //Für die TableView
    var recordedDataSets: [RecordedDataSet] = []
    
    @IBOutlet weak var sensorSelector: UISegmentedControl!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toggleExpertsVar: UISegmentedControl!
    @IBOutlet weak var timeSelectorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timeSelectorSliderVar.setValue(Float(self.selectedTime), animated: false)
        timeSelectorLabel.text = String(self.selectedTime)
        self.countdownSeconds = self.selectedTime
        
        tableView.dataSource = self
        tableView.delegate = self
        
        //Device MotionManager für andere Sensordaten als Accelaration benutzen
        self.cmMotionManager.deviceMotionUpdateInterval = 0.02
        //self.cmMotionManager.accelerometerUpdateInterval = 0.01
        
        self.lineChartView.delegate = self
        self.lineChartView.chartDescription?.text = ""

        self.lineChartView.noDataText = "keine Daten vorhanden"
        
        self.lineChartView.leftAxis.drawAxisLineEnabled = false
        self.lineChartView.leftAxis.drawGridLinesEnabled = false
        
        self.lineChartView.rightAxis.drawAxisLineEnabled = false
        self.lineChartView.rightAxis.drawGridLinesEnabled = false

        
        self.lineChartView.xAxis.drawAxisLineEnabled = false
        self.lineChartView.xAxis.drawGridLinesEnabled = false
        
        self.lineChartView.pinchZoomEnabled = false
        self.lineChartView.doubleTapToZoomEnabled = false
        
        toggleExpertsVar.selectedSegmentIndex = 0
        
        expertData = loadExpertData(expertFlag: 0)
        
        printChart(recordedDataSet: expertData, sensor: selectedSensor, person: "expert")
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        //Daten aus CoreData laden
        getData()
        
        //TableView neu laden
        tableView.reloadData()
    }
    
    
    func coreDataToStruct(recordedDataSet: RecordedDataSet) -> RecordedDataSetStruct {
        let date = Date()
        //let sensorDataStruct: [SensorDataStruct] = []
        //var recordedDataSetStruct = RecordedDataSetStruct(id: 0, recordingTime: date, sensorDataStruct: sensorDataStruct)
        var recordedDataSetStruct = RecordedDataSetStruct()
        
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
    
    func loadExpertData(expertFlag: Int) -> RecordedDataSetStruct {
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
        
        var path: String?
        
        if expertFlag == 0 {
            path = Bundle.main.path(forResource: "expertData", ofType: "json")
        }
        
        if expertFlag == 1 {
            let p = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            path = p.first
            if path != nil {
                path = path! + "/expertDataNew.json"
            }
        }

        
        if path != nil {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path!), options: .alwaysMapped)
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
        //let sensorDataStruct: [SensorDataStruct] = []
        //var expertRecordedDataSet = RecordedDataSetStruct(id: 0, recordingTime: date, sensorDataStruct: sensorDataStruct)
        var expertRecordedDataSet = RecordedDataSetStruct()
        
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
                //für weniger Daten, nur jeden zweiten Wert nehmen
                if i%2 == 0 {
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
        }
        return expertRecordedDataSet
    }
    
    
    func printChart(recordedDataSet: RecordedDataSetStruct, sensor: Int, person: String) {
        
        //Den letzten angezeigten Datensatz entfernen, Expertendaten da lassen
//        if (dataSets.count > 1) {
//            dataSets.removeLast()
//        }
        
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
    
    
    func dataToJsonString() -> String {
        var s = "{ \"loggingTime\" : [\""
        
        for i in 0..<userData.sensorDataStruct.count {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let t = String(describing: dateFormatter.string(from: userData.sensorDataStruct[i].loggingTime))
            s = s.appending(t)
            s = s.appending("\",\"")
        }
        
        //letztes Anführungszeichen löschen
        s.remove(at: s.index(before: s.endIndex))
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"accelerometerAccelerationX\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].accelerationX)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"accelerometerAccelerationY\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].accelerationY)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"accelerometerAccelerationZ\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].accelerationZ)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"gyroRotationX\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].rotationX)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"gyroRotationY\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].rotationY)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"gyroRotationZ\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].rotationZ)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"motionYaw\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].motionYaw)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"motionRoll\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].motionRoll)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("],\"motionPitch\" : [")
        
        for i in 0..<userData.sensorDataStruct.count {
            let t = String(userData.sensorDataStruct[i].motionPitch)
            s = s.appending(t)
            s = s.appending(",")
        }
        
        //letzes Komma löschen
        s.remove(at: s.index(before: s.endIndex))
        
        s = s.appending("]}")
        
        return s
    }
    
    //func saveDataToJsonFile(recordedDataSetStruct: RecordedDataSetStruct) {
    func saveDataToJsonFile() {
        let p = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        
        if let path = p.first {
            
            do {
                // Zeichenkette speichern
                let s = dataToJsonString()
                try s.write(toFile: path + "/expertDataNew.json", atomically : false , encoding: String.Encoding.utf8 )
                // Textdatei in eine Variable lesen
                //let t = try String(contentsOfFile: path + "/test.txt", encoding: String.Encoding.utf8 )
            } catch let err as NSError {
                print(err.description)
            }
        }
    }
    
    @IBAction func saveDataToFile(_ sender: Any) {
        //saveDataToJsonFile(recordedDataSetStruct: <#T##RecordedDataSetStruct#>)
        saveDataToJsonFile()
    }
    

    
    
    /**
     Die Sensordaten aufnehmen
    */
    @IBAction func startRecording(_ sender: AnyObject) {
        
        self.countdownSeconds = self.selectedTime
        timestampArray = []
        //accXArray = []
        
        //Wenn die App im Simulator läuft, ist test = false => kein DeviceMotion available
        //var test = cmMotionManager.isDeviceMotionAvailable
        
        //self.cmMotionManager.startAccelerometerUpdates(to: nsOperationQueue, withHandler: {
        self.cmMotionManager.startDeviceMotionUpdates(to: nsOperationQueue, withHandler: {
            
            (motionSensor, error) -> Void in
            if(error != nil) {
                NSLog("\(error)")
            } else {
                //Werte aufnehmen
                let timestamp: Date = Date()
                self.timestampArray.append(timestamp)
                
                let accel = motionSensor!.userAcceleration
                self.accXArray.append(accel.x)
                self.accYArray.append(accel.y)
                self.accZArray.append(accel.z)
                
                let rota = motionSensor!.rotationRate
                self.rotXArray.append(rota.x)
                self.rotYArray.append(rota.y)
                self.rotZArray.append(rota.z)
                
                let atti = motionSensor!.attitude
                self.yawArray.append(atti.yaw)
                self.rollArray.append(atti.roll)
                self.pitchArray.append(atti.pitch)

                //Die folgenden Werte müssen vom MotionSensor ausgelesen werden, nicht vom AccelerationSensor
                //                let rotX = 0.0
                //                let rotY = 0.0
                //                let rotZ = 0.0
                //
                //                let yaw = 0.0
                //                let roll = 0.0
                //                let pitch = 0.0
            }
        })
        
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
    }

    
    //läuft 12 Sekunden lang, dann werden die Daten aus Array in CoreData gespeichert
    func update() {
        if(self.countdownSeconds >= 0) {
            let s = String(self.countdownSeconds)
            timeLabel.text = s + " Sekunden"
            self.countdownSeconds -= 1
        } else {
            AudioServicesPlaySystemSound(1003) //1016
            timeLabel.text = "Verbleibende Zeit"
            cmMotionManager.stopDeviceMotionUpdates()
            //cmMotionManager.stopAccelerometerUpdates()
            timer.invalidate()
            saveDataToCoreData()
        }
    }
    
    func saveDataToCoreData() {
        
        
        //Neuen Context (Verknüpfung zu CoreData) erstellen
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        
        //Neuen Datensatz erstellen
        let recordedDataSet = RecordedDataSet(context: context)
        recordedDataSet.recordingTime = timestampArray[0]
        
        
        for i in 0..<timestampArray.count {
            
            //Die aufgenommenen Daten in ein SensorData Objekt speichern
            let sensorData = SensorData(context: context)
            
            sensorData.loggingTime = timestampArray[i]
            sensorData.accelerationX = accXArray[i]
            sensorData.accelerationY = accYArray[i]
            sensorData.accelerationZ = accZArray[i]
            
            sensorData.rotationX = rotXArray[i]
            sensorData.rotationY = rotYArray[i]
            sensorData.rotationZ = rotZArray[i]
            
            sensorData.motionYaw = yawArray[i]
            sensorData.motionRoll = rollArray[i]
            sensorData.motionPitch = pitchArray[i]
            
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
        
//        var accX: [Double] = []
//        var sensorDataArray: [SensorData] = []
        
        let recordedDataSet = recordedDataSets[indexPath.row]
//        let sensorDatas = recordedDataSet.sensorData
        
        
        
        
        
        //TODO: Hier die geholten Sachen in lokale Klassen umwandeln!!!
        //test, obs klappt:
        userData = coreDataToStruct(recordedDataSet: recordedDataSet)
        
        
        printChart(recordedDataSet: userData, sensor: selectedSensor, person: "user")
        
        
//        for sensorData in sensorDatas! {
//            sensorDataArray.append(sensorData as! SensorData)
//        }
//    
//        //SensorDaten werden als unsortiertes Set geladen, hier nach Zeit sortieren:
//        sensorDataArray.sort{$0.loggingTime < $1.loggingTime}
//            
//        for i in 0..<sensorDataArray.count {
//            accX.append(sensorDataArray[i].accelerationX)
//        }
//        
//        //Die Beschriftung für den Graph erstellen:
//        let timestamp = recordedDataSet.recordingTime
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "dd.MM.yyyy"
//        let timeFormatter = DateFormatter()
//        timeFormatter.dateFormat = "HH:mm:ss"
//        var dateString = ""
//        var timeString = ""
//        
//        if timestamp != nil {
//            dateString = dateFormatter.string(from: timestamp!)
//            timeString = timeFormatter.string(from: timestamp!)
//        }
//        
//        let graphLabelText = "\(dateString) - \(timeString)"
//        
//        
//        //Das Chart updaten:
//        
//        //Den letzten angezeigten Datensatz entfernen, Expertendaten da lassen
//        if (dataSets.count > 1) {
//            dataSets.removeLast()
//        }
//        
//        var yValues:[ChartDataEntry] = [ChartDataEntry]()
//        for i in 0 ..< accX.count {
//            yValues.append(ChartDataEntry(x: Double(i), y: accX[i]))
//        }
//        
//        
//        let set:LineChartDataSet = LineChartDataSet(values: yValues, label: graphLabelText)
//        set.axisDependency = .left
//        set.mode = .cubicBezier
//        set.drawCirclesEnabled = false
//        set.colors = [UIColor.red]
//        dataSets.append(set)
//        let data:LineChartData = LineChartData(dataSets: dataSets)
//        self.lineChartView.data = data
        
    }
    
    /**
     Wenn eine Zeile abgewählt wird:
     */
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {

    }
    
    @IBAction func timeSelectorSlieder(_ sender: UISlider) {
        self.selectedTime = Int(sender.value)
        timeSelectorLabel.text = String(self.selectedTime)
    }

    @IBAction func toggleExperts(_ sender: UISegmentedControl) {
        dataSets.removeAll()
        expertData = loadExpertData(expertFlag: sender.selectedSegmentIndex)
        printChart(recordedDataSet: expertData, sensor: self.selectedSensor, person: "expert")
        printChart(recordedDataSet: userData, sensor: self.selectedSensor, person: "user")
    }

    
    @IBAction func toggleSensor(_ sender: UISegmentedControl) {
        dataSets.removeAll()
        self.selectedSensor = sender.selectedSegmentIndex
        printChart(recordedDataSet: expertData, sensor: self.selectedSensor, person: "expert")
        printChart(recordedDataSet: userData, sensor: self.selectedSensor, person: "user")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
