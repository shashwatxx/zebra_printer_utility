//
//  Printer.swift
//  Runner
//
//  Created by faranegar on 6/21/20.
//

import Foundation


class Printer{

    let connectedStr:String = "Connected"
    let disconnectedStr:String = "Disconnected"
    let disconnectingStr:String = "Disconnecting"
    let connectingStr:String = "Connecting"
    let sendingDataStr:String = "Sending Data"
    
    let disconnectedColor = "R"
    let connectedColor = "G"
    let connectingColor = "Y"
    
    let doneStr:String = "Done"
    var connection : ZebraPrinterConnection?
    var methodChannel : FlutterMethodChannel?
    var selectedIPAddress: String? = nil
    var selectedMacAddress: String? = nil
    var isZebraPrinter :Bool = true
    var wifiManager: POSWIFIManager?
    var isConnecting :Bool = false
    
    static func getInstance(binaryMessenger : FlutterBinaryMessenger) -> Printer {
        let printer = Printer()
        printer.setMethodChannel(binaryMessenger: binaryMessenger)
        return printer
    }

    //Send dummy to get user permission for local network
    func dummyConnect(){
        var connection = TcpPrinterConnection(address: "0.0.0.0", andWithPort: 9100)
        connection?.open()
        connection?.close()
    }

    func discoveryPrinters(){
      dummyConnect()
      print("Message from ios: starting for discovering printers")
      let manager = EAAccessoryManager.shared()
        
      let devices = manager.connectedAccessories
      for d in devices {
        print("Message from ios: orinter found")
        let data: [String: Any] = [
            "Name": d.name,
            "Address": d.serialNumber,
             "IsWifi": false
              ]
        self.methodChannel?.invokeMethod("printerFound", arguments: data)
      }
        self.methodChannel?.invokeMethod("onPrinterDiscoveryDone", arguments: nil)
    }
    
    func setMethodChannel(binaryMessenger : FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: "ZebraPrinterObject" + toString(), binaryMessenger: binaryMessenger)
        self.methodChannel?.setMethodCallHandler({ (FlutterMethodCall,  FlutterResult) in
            let args = FlutterMethodCall.arguments
            let myArgs = args as? [String: Any]
            if(FlutterMethodCall.method == "print"){
                self.printData(data: myArgs?["Data"] as! NSString)
            } else if(FlutterMethodCall.method == "checkPermission"){
                FlutterResult(true)
            } else if(FlutterMethodCall.method == "disconnect"){
                DispatchQueue.global(qos: .utility).async {
                    self.disconnect()
                          }
            } else if(FlutterMethodCall.method == "isPrinterConnected") {
                     FlutterResult(self.isPrinterConnect())
            } else if(FlutterMethodCall.method == "discoverPrinters") {
                self.discoveryPrinters()
            } else if(FlutterMethodCall.method == "setSettings") {
                let settingCommand = myArgs?["SettingCommand"] as? NSString
                        self.setSettings(settings: settingCommand!)
            } else if(FlutterMethodCall.method == "connectToPrinter" || FlutterMethodCall.method == "connectToGenericPrinter" ) {
                   let address = myArgs?["Address"] as? String
                DispatchQueue.global(qos: .utility).async { self.connectToSelectPrinter(address: address!)
                             }
            }
        })
    }

    func toString() -> String{
        return String(UInt(bitPattern: ObjectIdentifier(self)))
    }
    
    func connectToGenericPrinter(address: String) {
        self.isZebraPrinter = false
           setStatus(message: connectingStr, color:connectingColor)
        if self.wifiManager != nil{
            self.wifiManager?.posDisConnect()
                 setStatus(message: disconnectedStr, color: disconnectedColor)
                 setStatus(message: connectingStr, color: connectingColor)
        }
        self.wifiManager = POSWIFIManager()
        self.wifiManager?.posConnect(withHost: address, port: 9100, completion: { (result) in
            if result == true {
                self.setStatus(message: self.connectedStr, color: self.connectedColor)
            } else {
                self.setStatus(message: self.disconnectedStr, color: self.disconnectedColor)
            }
        })  
    }
    
    func connectToSelectPrinter(address: String) -> Bool{
        if(self.isConnecting == false) {
            self.isConnecting = true
            self.isZebraPrinter = true
            selectedIPAddress = nil
            setStatus(message: connectingStr, color:connectingColor)
            if(self.connection != nil){
                self.connection?.close()
                setStatus(message: disconnectedStr, color: disconnectedColor)
                setStatus(message: connectingStr, color: connectingColor)
            }
            if(!address.contains(".")){
                self.connection = MfiBtPrinterConnection(serialNumber: address)

            }else {
               self.connection = TcpPrinterConnection(address: address, andWithPort: 9100)
            }
            Thread.sleep(forTimeInterval: 1)
            let isOpen = self.connection?.open()
                 print("connection open ")
            self.isConnecting = false
            if isOpen == true {
                Thread.sleep(forTimeInterval: 1)
                self.selectedIPAddress = address
                setStatus(message: connectedStr, color: connectedColor)
                return true
            } else {
                setStatus(message: disconnectedStr, color: disconnectedColor)
                return false
            }
        }
        else  {
            return false
        }
    }

    func isPrinterConnect() -> String{
        if self.isZebraPrinter == true {
        if self.connection?.isConnected() == true {
            setStatus(message: connectedStr, color: connectedColor)
              return connectedStr
        }
        else {
            setStatus(message: disconnectedStr, color: disconnectedColor)
              return disconnectedStr
        }
        } else {
            if(self.wifiManager?.connectOK == true){
                setStatus(message: connectedStr, color: connectedColor)
                return connectedStr
            } else {
                setStatus(message: disconnectedStr, color: disconnectedColor)
                        return disconnectedStr
            }
        }
    }

    func setSettings(settings: NSString){
        printData(data: settings)
    }

    func disconnect() {
        if self.isZebraPrinter == true {
            setStatus(message: disconnectingStr, color: connectingColor)
            if self.connection != nil {
                self.connection?.close()
            }
            setStatus(message: disconnectedStr, color: disconnectedColor)
        } else {
               setStatus(message: disconnectingStr, color: connectingColor)
            if self.wifiManager != nil{
                self.wifiManager?.posDisConnect()
            }
           setStatus(message: disconnectedStr, color: disconnectedColor)
        }
    }

   func printData(data: NSString) {
    //ToDo improve sending data
     DispatchQueue.global(qos: .utility).async {
      let dataBytes = Data(bytes: data.utf8String!, count: data.length)
      DispatchQueue.main.async {
        self.setStatus(message: "Sending Data", color: self.connectingColor)
             }
        
        var printSuccessful = false
        var errorMessage = ""
        
        if self.isZebraPrinter == true {
              var error: NSError?
              let result = self.connection?.write(dataBytes, error: &error)
              
              if result == -1, let error = error {
                print("iOS Print Error: \(error)")
                errorMessage = "Connection error: \(error.localizedDescription)"
                self.disconnect()
              } else {
                // Check if data was sent successfully
                if result != nil && result! >= 0 {
                    // Additional check using printer status if available
                    if let zebraPrinter = ZebraPrinterFactory.getInstance(self.connection) {
                        var statusError: NSError?
                        if let printerStatus = zebraPrinter.getCurrentStatus(&statusError) {
                            if printerStatus.isReadyToPrint {
                                printSuccessful = true
                            } else {
                                // Check for specific error conditions
                                if printerStatus.isPaperOut {
                                    errorMessage = "Paper out"
                                } else if printerStatus.isHeadOpen {
                                    errorMessage = "Printer head open"
                                } else if printerStatus.isPaused {
                                    errorMessage = "Printer paused"
                                } else if printerStatus.isHeadTooHot {
                                    errorMessage = "Printer head too hot"
                                } else if printerStatus.isHeadCold {
                                    errorMessage = "Printer head too cold"
                                } else if printerStatus.isRibbonOut {
                                    errorMessage = "Ribbon out"
                                } else {
                                    errorMessage = "Printer not ready"
                                }
                            }
                        } else {
                            // Assume success if we can't get status but data was sent
                            printSuccessful = true
                        }
                    } else {
                        // Assume success if we can't get printer instance but data was sent
                        printSuccessful = true
                    }
                } else {
                    errorMessage = "Failed to send data to printer"
                }
              }
        } else {
            // Handle generic printer
            self.wifiManager?.posWriteCommand(with: dataBytes, withResponse: { (result) in
                if result {
                    printSuccessful = true
                } else {
                    errorMessage = "Failed to send data to generic printer"
                }
            })
            
            // Wait a bit for the generic printer response
            sleep(1)
            
            // Check connection state for generic printer
            if self.wifiManager?.connectOK == true {
                printSuccessful = true
            } else {
                printSuccessful = false
                if errorMessage.isEmpty {
                    errorMessage = "Generic printer connection lost"
                }
            }
        }
      
      sleep(1)
        
        DispatchQueue.main.async {
            if printSuccessful {
                // Send success callback to Flutter
                self.methodChannel?.invokeMethod("onPrintComplete", arguments: nil)
                self.setStatus(message: self.doneStr, color: self.connectedColor)
            } else {
                // Send error callback to Flutter
                let errorArgs: [String: Any] = [
                    "ErrorText": errorMessage
                ]
                self.methodChannel?.invokeMethod("onPrintError", arguments: errorArgs)
                self.setStatus(message: "Print Error: \(errorMessage)", color: self.disconnectedColor)
            }
        }
     }
    }

    func setStatus(message: String, color: String){
        let data: [String: Any] = [
            "Status": message,
            "Color": color
        ]
        self.methodChannel?.invokeMethod("changePrinterStatus", arguments: data)

    }

}
