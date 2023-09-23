//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Copyright © 2020 Oliver Peate. All rights reserved.
//

import Cocoa
import IOBluetooth
import LaunchAtLogin
import CoreWLAN
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var bluetoothMenu: NSMenu!
    @IBOutlet weak var disableBluetoothOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet weak var disconnectBluetoothDevicesOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet weak var bluetoothDeviceListStart: NSMenuItem!
    @IBOutlet weak var bluetoothDeviceListEnd: NSMenuItem!
    @IBOutlet weak var disableWifiOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var hideIconMenuItem: NSMenuItem!
    
    private let bluetoothLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "bluetooth")
    private let wifiLog: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "wifi")
    
    private var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var prevBluetoothState: Int32 = IOBluetoothPreferenceGetControllerPowerState()
    private var prevBluetoothDevicesConnectedState: [String : Bool] = [String : Bool]()
    private var prevWifiState: Bool = CWWiFiClient.shared().interface()!.powerOn()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        LaunchAtLogin.migrateIfNeeded() // Migrate to macOS 13 API (https://github.com/sindresorhus/LaunchAtLogin/releases/tag/v5.0.0)
        if !UserDefaults.standard.bool(forKey: "hideIcon") {
            initStatusItem()
        }
        setupNotificationHandlers()
    }

    // Re-add the status bar icon when the app is launched a second time
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        initStatusItem()
        return true
    }
    
    func getPairedBluetoothDevices() -> [IOBluetoothDevice] {
        let pairedDevices: [IOBluetoothDevice] = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [IOBluetoothDevice]()
        os_log("Raw paired Bluetooth devices: %{public}@", log: bluetoothLog, type: .debug, pairedDevices)
        
        let filteredDevices: [IOBluetoothDevice] = pairedDevices.filter({
            // Make sure that it's a classic device and not a BLE device
            //
            // I don't know what's the expected behavior of IOBluetoothDevice.pairedDevices(). On my Mac Mini M1, Ventura 13.2.1 (22D68):
            //   - IOBluetoothDevice.pairedDevices() doesn't return my BLE devices.
            //   - However, if Bluesnooze is running and after waking up from sleep, it will return the BLE devices.
            //
            // But I also don't know the expected behavior of a IOBluetoothDevice that references a BLE device:
            //   - closeConnection() returns success but doesn't acutally disconnect the device.
            //
            // But I can't test on any other BLE devices because the only one I have is my MX Master mouse.
            //
            // For now, to be consistent and to avoid any uknown behaviors, force to return classic devices.
            //
            // Validation code taken from:
            //   Issue 630581: bluetooth: paired devices always created as BT classic, but could be BLE
            //   https://bugs.chromium.org/p/chromium/issues/detail?id=630581
            $0.getServiceRecord(for: IOBluetoothSDPUUID(uuid32: kBluetoothSDPUUID16ServiceClassPnPInformation.rawValue)) != nil
        })
        
        return filteredDevices
    }

    // Settings

    var disableBluetoothOnPowerDown: Bool {
        get {
            if UserDefaults.standard.object(forKey: "disableBluetoothOnPowerDown") == nil {
                // the primary function of the program is enabled by default
                return true
            }
            return UserDefaults.standard.bool(forKey: "disableBluetoothOnPowerDown")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "disableBluetoothOnPowerDown")
        }
    }

    var disconnectBluetoothDevicesOnPowerDown: Bool {
        get {
            if UserDefaults.standard.object(forKey: "disconnectBluetoothDevicesOnPowerDown") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "disconnectBluetoothDevicesOnPowerDown")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "disconnectBluetoothDevicesOnPowerDown")
        }
    }
    
    var disableBluetoothOrDisconnectBluetoothDevicesOnPowerDown: Bool {
        disableBluetoothOnPowerDown || disconnectBluetoothDevicesOnPowerDown
    }
    
    var bluetoothDevicesToDisconnect: [String] {
        UserDefaults.standard.array(forKey: "bluetoothDevicesToDisconnectOnPowerDown") as? [String] ?? [String]()
    }
    
    func setDisconnectBluetoothDeviceOnPowerDown(address addressString: String, _ disconnect: Bool)
    {
        var devicesToDisconnect = bluetoothDevicesToDisconnect
        
        if (disconnect) {
            if (!devicesToDisconnect.contains(addressString)) {
                devicesToDisconnect.append(addressString)
            }
        } else {
            devicesToDisconnect.removeAll(where: { $0 == addressString })
        }
        
        UserDefaults.standard.set(devicesToDisconnect, forKey: "bluetoothDevicesToDisconnectOnPowerDown")
    }
    
    func isDisconnectBluettohDeviceOnPowerDown(_ addressString: String) -> Bool
    {
        let devicesToDisconnect = UserDefaults.standard.array(forKey: "bluetoothDevicesToDisconnectOnPowerDown") as? [String] ?? [String]()
        
        return devicesToDisconnect.contains(addressString)
    }
    
    var bluetoothActionOnScreenUnlock: String {
        get {
            if let value = UserDefaults.standard.string(forKey: "bluetoothActionOnScreenUnlock") {
                return value
            }
            return "restore"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "bluetoothActionOnScreenUnlock")
        }
    }

    var disableWifiOnPowerDown: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "disableWifiOnPowerDown")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "disableWifiOnPowerDown")
        }
    }

    var wifiActionOnScreenUnlock: String {
        get {
            if let value = UserDefaults.standard.string(forKey: "wifiActionOnScreenUnlock") {
                return value
            }
            return "nothing"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "wifiActionOnScreenUnlock")
        }
    }

    // Click handlers

    @IBAction func handleMenuOpen(_ sender: NSMenu) {
        // Bluetooth
        disableBluetoothOnPowerDownMenuItem.state = boolToMenuState(v: disableBluetoothOnPowerDown)
        disconnectBluetoothDevicesOnPowerDownMenuItem.state = boolToMenuState(v: disconnectBluetoothDevicesOnPowerDown)
        
        // Populate the Bluetooth device list
        let bluetoothDeviceListInsertIndex = bluetoothMenu.index(of: bluetoothDeviceListStart) + 1
        let bluetoothDeviceListEndIndex = bluetoothMenu.index(of: bluetoothDeviceListEnd)

        for _ in bluetoothDeviceListInsertIndex..<bluetoothDeviceListEndIndex {
            bluetoothMenu.removeItem(at: bluetoothDeviceListInsertIndex)
        }
        
        let pairedBluetoothDevices = getPairedBluetoothDevices()
        os_log("Paired Bluetooth devices: %{public}@", log: bluetoothLog, pairedBluetoothDevices)
        if (pairedBluetoothDevices.isEmpty) {
            let noDevicesMenuItem = NSMenuItem(title: "No devices", action: nil, keyEquivalent: "")
            noDevicesMenuItem.isEnabled = false
            noDevicesMenuItem.indentationLevel = bluetoothDeviceListStart.indentationLevel
        } else {
            for case let device in pairedBluetoothDevices.reversed() {
                let deviceMenuItem = BluetoothDeviceMenuItem(forDevice: device, action: #selector(blutoothDeviceClicked(_:)), keyEquivalent: "")
                deviceMenuItem.target = self
                deviceMenuItem.state = boolToMenuState(v: isDisconnectBluettohDeviceOnPowerDown(device.addressString))
                deviceMenuItem.isEnabled = disconnectBluetoothDevicesOnPowerDown
                deviceMenuItem.indentationLevel = bluetoothDeviceListStart.indentationLevel
                
                bluetoothMenu.insertItem(deviceMenuItem, at: bluetoothDeviceListInsertIndex)
            }
        }
        
        bluetoothActionOnScreenUnlockRestore.isEnabled = disableBluetoothOrDisconnectBluetoothDevicesOnPowerDown
        bluetoothActionOnScreenUnlockRestore.state = boolToMenuState(v: bluetoothActionOnScreenUnlock == "restore" ? (disableBluetoothOrDisconnectBluetoothDevicesOnPowerDown ? true : nil) : false)
        bluetoothActionOnScreenUnlockEnable.state = boolToMenuState(v: bluetoothActionOnScreenUnlock == "enable")
        bluetoothActionOnScreenUnlockNothing.state = boolToMenuState(v: bluetoothActionOnScreenUnlock == "nothing")

        // Wi-Fi
        disableWifiOnPowerDownMenuItem.state = boolToMenuState(v: disableWifiOnPowerDown)
        wifiActionOnScreenUnlockRestore.isEnabled = disableWifiOnPowerDown
        wifiActionOnScreenUnlockRestore.state = boolToMenuState(v: wifiActionOnScreenUnlock == "restore" ? (disableWifiOnPowerDown ? true : nil) : false)
        wifiActionOnScreenUnlockEnable.state = boolToMenuState(v: wifiActionOnScreenUnlock == "enable")
        wifiActionOnScreenUnlockNothing.state = boolToMenuState(v: wifiActionOnScreenUnlock == "nothing")

        // Launch at login
        launchAtLoginMenuItem.state = boolToMenuState(v: LaunchAtLogin.isEnabled)

        // Hide icon
        hideIconMenuItem.state = boolToMenuState(v: UserDefaults.standard.bool(forKey: "hideIcon"))

        // Show menu
        statusItem.popUpMenu(statusMenu)
    }

    @IBAction func disableBluetoothOnPowerDownClicked(_ sender: NSMenuItem) {
        disableBluetoothOnPowerDown = !disableBluetoothOnPowerDown
        if bluetoothActionOnScreenUnlock == "restore" {
            bluetoothActionOnScreenUnlock = "nothing"
        }
        
        if disableBluetoothOnPowerDown {
            disconnectBluetoothDevicesOnPowerDown = false
        }
    }
    
    @IBAction func disconnectBluetoothDevicesOnPowerDownClicked(_ sender: NSMenuItem) {
        disconnectBluetoothDevicesOnPowerDown = !disconnectBluetoothDevicesOnPowerDown
        if bluetoothActionOnScreenUnlock == "restore" {
            bluetoothActionOnScreenUnlock = "nothing"
        }
        
        if disconnectBluetoothDevicesOnPowerDown {
            disableBluetoothOnPowerDown = false
        }
    }

    @IBAction func bluetoothActionOnScreenUnlockRestoreClicked(_ sender: NSMenuItem) {
        bluetoothActionOnScreenUnlock = "restore"
    }

    @IBAction func bluetoothActionOnScreenUnlockEnableClicked(_ sender: NSMenuItem) {
        bluetoothActionOnScreenUnlock = "enable"
    }

    @IBAction func bluetoothActionOnScreenUnlockNothingClicked(_ sender: NSMenuItem) {
        bluetoothActionOnScreenUnlock = "nothing"
    }

    @IBAction func disableWifiOnPowerDownClicked(_ sender: NSMenuItem) {
        disableWifiOnPowerDown = !disableWifiOnPowerDown
        if wifiActionOnScreenUnlock == "restore" {
            wifiActionOnScreenUnlock = "nothing"
        }
    }

    @IBAction func wifiActionOnScreenUnlockRestoreClicked(_ sender: NSMenuItem) {
        wifiActionOnScreenUnlock = "restore"
    }

    @IBAction func wifiActionOnScreenUnlockEnableClicked(_ sender: NSMenuItem) {
        wifiActionOnScreenUnlock = "enable"
    }

    @IBAction func wifiActionOnScreenUnlockNothingClicked(_ sender: NSMenuItem) {
        wifiActionOnScreenUnlock = "nothing"
    }

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
    }

    @IBAction func hideIconClicked(_ sender: NSMenuItem) {
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            UserDefaults.standard.removeObject(forKey: "hideIcon")
            hideIconMenuItem.state = NSControl.StateValue.off
        } else {
            // Show a tip on how to get the icon back
            let alert = NSAlert()
            alert.messageText = "Important information"
            alert.informativeText = "Launch the app a second time to show the icon again."
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn {
                return
            }
            // Hide the icon
            UserDefaults.standard.set(true, forKey: "hideIcon")
            hideIconMenuItem.state = NSControl.StateValue.on
            statusItem.statusBar?.removeStatusItem(statusItem)
        }
    }

    @IBAction func websiteClicked(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "https://github.com/stefansundin/bluesnooze")!)
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func blutoothDeviceClicked(_ sender: BluetoothDeviceMenuItem) {
        setDisconnectBluetoothDeviceOnPowerDown(address: sender.deviceAddressString, !isDisconnectBluettohDeviceOnPowerDown(sender.deviceAddressString))
    }

    // Notification handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:))
        ].forEach { notification, sel in
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: sel, name: notification, object: nil)
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { notification in
            self.onScreenUnlock(note: notification)
        }
    }

    @objc func onPowerDown(note: NSNotification) {
        prevBluetoothState = IOBluetoothPreferenceGetControllerPowerState()
        os_log("prevBluetoothState: %d", log: bluetoothLog, type: .debug, prevBluetoothState)
        
        getPairedBluetoothDevices().forEach({
            prevBluetoothDevicesConnectedState[$0.addressString] = $0.isConnected()
        })
        os_log("prevBluetoothDevicesConnectedState: %{public}@", log: bluetoothLog, type: .debug, prevBluetoothDevicesConnectedState)
        
        var disconnectedBluetoothDevices: [IOBluetoothDevice] = [IOBluetoothDevice]()
        if disableBluetoothOnPowerDown {
            setBluetooth(powerOn: false)
        } else if disconnectBluetoothDevicesOnPowerDown {
            bluetoothDevicesToDisconnect.forEach({
                let device = disconnectBluetoothDevice(address: $0)
                disconnectedBluetoothDevices.append(device)
            })
        }
        
        prevWifiState = CWWiFiClient.shared().interface()!.powerOn()
        os_log("prevWifiState: %{bool}d", log: wifiLog, type: .debug, prevWifiState)
        if disableWifiOnPowerDown {
            setWifi(powerOn: false)
        }
        
        // Wait for the the Bluetooth devices to be actually disconnected to avoid a race condition when the Mac is awakened right away while it tries to go to sleep:
        //   1. Sleep
        //   2. Disconnect Bluetooth device
        //      1. IOBluetoothDevice.closeConnection() returns successfully.
        //      2. But actual Bluetooth device hasn't disconnected yet.
        //   3. Wake up right away
        //   4. Connect Bluetooth device
        //      1. Bluetooth device is actually still connected.
        //      2. IOBluetoothDevice.openConnection() returns successfully.
        //   5. Bluetooth device finally disconnects.
        //   6. Even though the Mac is now awake, the Bluetooth device remains disconnected.
        waitToBeActuallyDisconnected(blueToothDevices: disconnectedBluetoothDevices, retryInterval: 0.5, timeout: 5)
    }

    func onScreenUnlock(note: Notification) {
        if bluetoothActionOnScreenUnlock == "enable" || (bluetoothActionOnScreenUnlock == "restore" && prevBluetoothState != 0) {
            setBluetooth(powerOn: true)
            
            if disconnectBluetoothDevicesOnPowerDown {
                bluetoothDevicesToDisconnect.forEach({
                    if bluetoothActionOnScreenUnlock == "enable" || prevBluetoothDevicesConnectedState[$0] ?? false {
                        connectBluetoothDevice(address: $0)
                    }
                })
            }
        }
        if wifiActionOnScreenUnlock == "enable" || (wifiActionOnScreenUnlock == "restore" && prevWifiState) {
            setWifi(powerOn: true)
        }
    }

    private func setBluetooth(powerOn: Bool) {
        os_log("Set Bluetooth on: %{bool}d", log: bluetoothLog, powerOn)
        
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    private func setWifi(powerOn: Bool) {
        if let interface = CWWiFiClient.shared().interface() {
            os_log("Set Wifi %{public}@ on: %{bool}d", log: wifiLog, interface, powerOn)
            do {
                try interface.setPower(powerOn)
            } catch {
                os_log("Error setting Wifi state: %{public}@", log: wifiLog, type: .error, String(describing: error))
            }
        } else {
            os_log("No default Wifi interface available", log: wifiLog, type: .error)
        }
    }
    
    private func disconnectBluetoothDevice(address addressString: String) -> IOBluetoothDevice {
        let device: IOBluetoothDevice = IOBluetoothDevice(addressString: addressString)
        os_log("Disconnect %{public}@, paired: %{bool}d, connected: %{bool}d", log: bluetoothLog, device, device.isPaired(), device.isConnected())
        
        if device.isConnected() {
            let status: IOReturn = device.closeConnection()
            os_log("Closed connection: %{public}@, success: %{bool}d", log: bluetoothLog, device, status == kIOReturnSuccess)
        }
        
        return device
    }
    
    private func connectBluetoothDevice(address addressString: String) {
        let device: IOBluetoothDevice = IOBluetoothDevice(addressString: addressString)
        os_log("Connect %{public}@, paired: %{bool}d, connected: %{bool}d", log: bluetoothLog, device, device.isPaired(), device.isConnected())
        
        if device.isPaired() && !device.isConnected() {
            // Connect asynchronously
            let status: IOReturn = device.openConnection(self)
            os_log("%{public}@, CREATE_CONNECTION command success: %{bool}d", log: bluetoothLog, device, status == kIOReturnSuccess)
        }
    }
    
    @objc func connectionComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        os_log("Connection complete: %{public}@, success: %{bool}d", log: bluetoothLog, device, status == kIOReturnSuccess)
    }
    
    private func waitToBeActuallyDisconnected(blueToothDevices devices: [IOBluetoothDevice], retryInterval: TimeInterval, timeout: TimeInterval) {
        let sleepInterval = TimeInterval.minimum(retryInterval, timeout)
        let timeoutTime = Date() + timeout
        
        var timeoutReached: Bool = false
        while(!timeoutReached && devices.contains(where: { $0.isConnected() })) {
            timeoutReached = Date() > timeoutTime
            if (!timeoutReached) {
                os_log("Waiting for devices to be disconnected", log: bluetoothLog)
                Thread.sleep(forTimeInterval: sleepInterval)
            }
        }
        
        if (timeoutReached) {
            os_log("Gave up on waiting for devices to be disconnected", log: bluetoothLog)
        } else {
            os_log("All devices disconnected", log: bluetoothLog)
        }
    }

    // UI state

    private func initStatusItem() {
        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }
        statusItem.button?.action = #selector(handleMenuOpen(_:))
    }

    private func boolToMenuState(v: Bool?) -> NSControl.StateValue {
        return v == true ? NSControl.StateValue.on :
               v == false ? NSControl.StateValue.off :
               NSControl.StateValue.mixed
    }
}

class BluetoothDeviceMenuItem : NSMenuItem {
    var deviceAddressString : String
    
    public init(forDevice device: IOBluetoothDevice, action selector: Selector?, keyEquivalent charCode: String) {
        self.deviceAddressString = device.addressString
        
        super.init(title: device.nameOrAddress, action: selector, keyEquivalent: charCode)
    }
    
    public required init(coder: NSCoder) {
        deviceAddressString = (coder.decodeObject(forKey: "deviceAddressString") as? String)!
        
        super.init(coder: coder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        coder.encode(deviceAddressString, forKey: "deviceAddressString")
    }
}
