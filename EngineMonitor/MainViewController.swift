//
//  MainViewController.swift
//  EngineMonitor
//
//  Created by Yury Shalin on 5/12/20.
//  Copyright © 2020 Yury Shalin. All rights reserved.
//

import UIKit

import CoreBluetooth

private enum Constants {
    
    struct Connection {
        static let deviceName = "MLT-BT05"
        static let serviceId = "FFE0"
        static let serviceUUID = CBUUID(string: "FFE0")
        static let propertyUUID = CBUUID(string: "FFE1")
    }
    
    struct Temperature {
        static let minTemperature = 30
        static let maxTemperature = 230
        static let yellowZone = 195
        static let redZone = 215
        static let temperatureRange = maxTemperature - minTemperature
        static let degreePerPercent = temperatureRange / 100
    }
    
}

final class MainViewController: UIViewController {
    
    var manager:CBCentralManager?
    var peripheral:CBPeripheral!
    @IBOutlet weak var scanButton: UIButton!
    
    @IBOutlet weak var head1Label: UILabel!
    @IBOutlet weak var head2Label: UILabel!
    @IBOutlet weak var head3Label: UILabel!
    @IBOutlet weak var head4Label: UILabel!
    @IBOutlet weak var head5Label: UILabel!
    @IBOutlet weak var head6Label: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    
    @IBOutlet weak var head1Bar: UIProgressView!
    @IBOutlet weak var head2Bar: UIProgressView!
    @IBOutlet weak var head3Bar: UIProgressView!
    @IBOutlet weak var head4Bar: UIProgressView!
    @IBOutlet weak var head5Bar: UIProgressView!
    @IBOutlet weak var head6Bar: UIProgressView!
    
    var scanningInProgress: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    @IBAction func scanTapped(_ sender: Any) {
        if scanningInProgress {
            manager?.stopScan()
            scanButton.setTitle("Connect", for: .normal)
        } else {
            manager?.scanForPeripherals(withServices: nil, options: nil)
            scanButton.setTitle("Disconnect", for: .normal)
        }
        
    }
    
}

extension MainViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
//            central.scanForPeripherals(withServices: nil, options: nil)
            scanButton.isEnabled = true
        } else {
            scanButton.isEnabled = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString

        if device?.contains(Constants.Connection.deviceName) ?? false {
            central.stopScan()
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            
            
            manager?.connect(self.peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        
    }
}

extension MainViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == Constants.Connection.serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Constants.Connection.propertyUUID {
                self.peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        struct Response {
            static var responseString: String = ""
        }
//        characteristic.properties
        if characteristic.uuid == Constants.Connection.propertyUUID {
            if let bytes = characteristic.value, let stringData = String(bytes: bytes, encoding: .utf8) {
                
                if stringData.contains("Time:") {
                    let response = Response.responseString.trimmingCharacters(in: .controlCharacters)
                    if response.count > 0 {
                        handleResponse(response: response)
                    }
                    Response.responseString = stringData
                } else {
                    Response.responseString.append(stringData)
                }
            }
        }
    }
}

private extension MainViewController {
    func setupViews() {
        head1Bar.progress = 0.0
        head1Bar.transform = head1Bar.transform.scaledBy(x: 1, y: 5)
        
        head2Bar.progress = 0.0
        head2Bar.transform = head2Bar.transform.scaledBy(x: 1, y: 5)
        
        head3Bar.progress = 0.0
        head3Bar.transform = head3Bar.transform.scaledBy(x: 1, y: 5)
        
        head4Bar.progress = 0.0
        head4Bar.transform = head4Bar.transform.scaledBy(x: 1, y: 5)
        
        head5Bar.progress = 0.0
        head5Bar.transform = head5Bar.transform.scaledBy(x: 1, y: 5)
        
        head6Bar.progress = 0.0
        head6Bar.transform = head6Bar.transform.scaledBy(x: 1, y: 5)
    }
}

private extension MainViewController {
    func handleResponse(response: String) {
        let elements = response.components(separatedBy: ",")
        print(elements)
        let elementsDictionary = elements.reduce([String: String]()) { (dict, element) -> [String: String] in
            var dict = dict
            let valueElements = element.components(separatedBy: ":")
            dict[valueElements[0]] = valueElements[1]
            return dict
        }
        updateUI(viewModel: elementsDictionary)
    }
    
    func temperatureToPercent(temperature: Int) -> Float {
        let percents = (temperature - Constants.Temperature.minTemperature) / Constants.Temperature.degreePerPercent
        return Float(percents) / 100
    }
    
    func temperatureInYellowRange(temperature: Int) -> Bool {
        return (temperature >= Constants.Temperature.yellowZone) && (temperature < Constants.Temperature.redZone) ? true : false
    }
    
    func temperatureInRedRange(temperature: Int) -> Bool {
        return temperature >= Constants.Temperature.redZone ? true : false
    }
    
    func updateUI(viewModel: Dictionary<String, String>) {
        print(viewModel)
        struct EngineMonitorParameterKeys {
            static let timestampKey = "Time"
            static let head1Key = "T1"
            static let head2Key = "T2"
            static let head3Key = "T3"
            static let head4Key = "T4"
            static let head5Key = "T5"
            static let head6Key = "T6"
        }
        if let head1TemperatureValue = viewModel[EngineMonitorParameterKeys.head1Key],
            let temperature = Int(head1TemperatureValue) {
            let modifiedTemp = temperature + 190
            
            updateUIElements(temperatureLabel: head1Label, with: modifiedTemp, bar: head1Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head1Label.text = "#1 NA"
        }
        
        if let head2TemperatureValue = viewModel[EngineMonitorParameterKeys.head2Key],
            let temperature = Int(head2TemperatureValue) {
            let modifiedTemp = temperature + 190
            
            updateUIElements(temperatureLabel: head2Label, with: modifiedTemp, bar: head2Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head2Label.text = "#2 NA"
        }
        
        if let head3TemperatureValue = viewModel[EngineMonitorParameterKeys.head3Key],
            let temperature = Int(head3TemperatureValue) {
            let modifiedTemp = temperature + 190
            
            updateUIElements(temperatureLabel: head3Label, with: modifiedTemp, bar: head3Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head3Label.text = "#3 NA"
        }
        
        if let head4TemperatureValue = viewModel[EngineMonitorParameterKeys.head4Key],
            let temperature = Int(head4TemperatureValue) {
            let modifiedTemp = temperature + 190
            
            updateUIElements(temperatureLabel: head4Label, with: modifiedTemp, bar: head4Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head4Label.text = "#4 NA"
        }
        
        
        if let head5TemperatureValue = viewModel[EngineMonitorParameterKeys.head5Key],
            let temperature = Int(head5TemperatureValue) {
            let modifiedTemp = temperature + 190
            
            updateUIElements(temperatureLabel: head5Label, with: modifiedTemp, bar: head5Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head5Label.text = "#5 NA"
        }
        
        if let head6TemperatureValue = viewModel[EngineMonitorParameterKeys.head6Key],
            let temperature = Int(head6TemperatureValue) {
            let modifiedTemp = temperature + 217
            
            updateUIElements(temperatureLabel: head6Label, with: modifiedTemp, bar: head6Bar, with: temperatureToPercent(temperature: modifiedTemp))
        } else {
            head6Label.text = "#6 NA"
        }
        
        if let timeStamp = viewModel[EngineMonitorParameterKeys.timestampKey] {
            timestampLabel.text = "Timestamp: \(timeStamp)"
        } else {
            timestampLabel.text = ""
        }
    }
    
    func updateUIElements(temperatureLabel: UILabel, with temperature: Int,
                          bar: UIProgressView, with percents: Float) {
        
        temperatureLabel.text = "\(temperature) °C"
        
        bar.progress = temperatureToPercent(temperature: temperature)
        if temperatureInRedRange(temperature: temperature) {
            bar.progressTintColor = UIColor.red
        } else if temperatureInYellowRange(temperature: temperature) {
            bar.progressTintColor = UIColor.yellow
        } else {
            bar.progressTintColor = UIColor.green
        }
    }
}
