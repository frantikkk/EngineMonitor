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
    static let deviceName = "MLT-BT05"
    static let serviceId = "FFE0"
    static let serviceUUID = CBUUID(string: "FFE0")
    static let propertyUUID = CBUUID(string: "FFE1")
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
    
    var scanningInProgress: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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

        if device?.contains(Constants.deviceName) ?? false {
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
            if service.uuid == Constants.serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Constants.propertyUUID {
                self.peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        struct Response {
            static var responseString: String = ""
        }
//        characteristic.properties
        if characteristic.uuid == Constants.propertyUUID {
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
        if let head1TemperatureValue = viewModel[EngineMonitorParameterKeys.head1Key] {
            head1Label.text = "Head #1: \(head1TemperatureValue) °C"
        } else {
            head1Label.text = "Head #1 NOT AVAILABLE"
        }
        
        if let head2TemperatureValue = viewModel[EngineMonitorParameterKeys.head2Key] {
            head2Label.text = "Head #2: \(head2TemperatureValue) °C"
        } else {
            head2Label.text = "Head #2 NOT AVAILABLE"
        }
        
        if let head3TemperatureValue = viewModel[EngineMonitorParameterKeys.head3Key] {
            head3Label.text = "Head #3: \(head3TemperatureValue) °C"
        } else {
            head3Label.text = "Head #3 NOT AVAILABLE"
        }
        
        if let head4TemperatureValue = viewModel[EngineMonitorParameterKeys.head4Key] {
            head4Label.text = "Head #4: \(head4TemperatureValue) °C"
        } else {
            head4Label.text = "Head #4 NOT AVAILABLE"
        }
        
        
        if let head5TemperatureValue = viewModel[EngineMonitorParameterKeys.head5Key] {
            head5Label.text = "Head #5: \(head5TemperatureValue) °C"
        } else {
            head5Label.text = "Head #5 NOT AVAILABLE"
        }
        
        if let head6TemperatureValue = viewModel[EngineMonitorParameterKeys.head6Key] {
            head6Label.text = "Head #6: \(head6TemperatureValue) °C"
        } else {
            head6Label.text = "Head #6 NOT AVAILABLE"
        }
        
        if let timeStamp = viewModel[EngineMonitorParameterKeys.timestampKey] {
            timestampLabel.text = "Timestamp: \(timeStamp)"
        } else {
            timestampLabel.text = ""
        }
    }
}
