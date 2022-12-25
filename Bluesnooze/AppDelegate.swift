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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var disableBluetoothOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet weak var bluetoothActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet weak var disableWifiOnPowerDownMenuItem: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockRestore: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockEnable: NSMenuItem!
    @IBOutlet weak var wifiActionOnScreenUnlockNothing: NSMenuItem!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var hideIconMenuItem: NSMenuItem!

    private var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var prevBluetoothState: Int32 = IOBluetoothPreferenceGetControllerPowerState()
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
        bluetoothActionOnScreenUnlockRestore.isEnabled = disableBluetoothOnPowerDown
        bluetoothActionOnScreenUnlockRestore.state = boolToMenuState(v: bluetoothActionOnScreenUnlock == "restore" ? (disableBluetoothOnPowerDown ? true : nil) : false)
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
        if disableBluetoothOnPowerDown {
            setBluetooth(powerOn: false)
        }
        prevWifiState = CWWiFiClient.shared().interface()!.powerOn()
        if disableWifiOnPowerDown {
            setWifi(powerOn: false)
        }
    }

    func onScreenUnlock(note: Notification) {
        if bluetoothActionOnScreenUnlock == "enable" || (bluetoothActionOnScreenUnlock == "restore" && prevBluetoothState != 0) {
            setBluetooth(powerOn: true)
        }
        if wifiActionOnScreenUnlock == "enable" || (wifiActionOnScreenUnlock == "restore" && prevWifiState) {
            setWifi(powerOn: true)
        }
    }

    private func setBluetooth(powerOn: Bool) {
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    private func setWifi(powerOn: Bool) {
        try! CWWiFiClient.shared().interface()!.setPower(powerOn)
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
