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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var onPowerUpActionRemember: NSMenuItem!
    @IBOutlet weak var onPowerUpActionAlways: NSMenuItem!
    @IBOutlet weak var onPowerUpActionNever: NSMenuItem!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var hideIconMenuItem: NSMenuItem!

    private var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var prevState: Int32 = IOBluetoothPreferenceGetControllerPowerState()
    private var onPowerUpAction: String = "remember"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        LaunchAtLogin.migrateIfNeeded() // Migrate to macOS 13 API (https://github.com/sindresorhus/LaunchAtLogin/releases/tag/v5.0.0)
        if !UserDefaults.standard.bool(forKey: "hideIcon") {
            initStatusItem()
        }
        setupNotificationHandlers()
        syncSettings()
    }

    // Re-add the status bar icon when the app is launched a second time
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        initStatusItem()
        return true
    }

    // MARK: Click handlers

    @IBAction func handleMenuOpen(_ sender: NSMenu) {
        syncSettings()
        statusItem.popUpMenu(statusMenu)
    }

    @IBAction func onPowerUpActionRememberClicked(_ sender: NSMenuItem) {
        UserDefaults.standard.set("remember", forKey: "onPowerUpAction")
        syncSettings()
    }

    @IBAction func onPowerUpActionAlwaysClicked(_ sender: NSMenuItem) {
        UserDefaults.standard.set("always", forKey: "onPowerUpAction")
        syncSettings()
    }

    @IBAction func onPowerUpActionNeverClicked(_ sender: NSMenuItem) {
        UserDefaults.standard.set("never", forKey: "onPowerUpAction")
        syncSettings()
    }

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        syncSettings()
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

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: Notification handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:)),
            NSWorkspace.didWakeNotification: #selector(onPowerUp(note:))
        ].forEach { notification, sel in
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: sel, name: notification, object: nil)
        }
    }

    @objc func onPowerDown(note: NSNotification) {
        prevState = IOBluetoothPreferenceGetControllerPowerState()
        setBluetooth(powerOn: false)
    }

    @objc func onPowerUp(note: NSNotification) {
        if (onPowerUpAction == "remember" && prevState != 0) || onPowerUpAction == "always" {
            setBluetooth(powerOn: true)
        }
    }

    private func setBluetooth(powerOn: Bool) {
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    // MARK: UI state

    private func initStatusItem() {
        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }
        statusItem.button?.action = #selector(handleMenuOpen(_:))
    }

    private func syncSettings() {
        // Start Bluetooth on wake
        onPowerUpActionRemember.state = NSControl.StateValue.off
        onPowerUpActionAlways.state = NSControl.StateValue.off
        onPowerUpActionNever.state = NSControl.StateValue.off
        if let action = UserDefaults.standard.string(forKey: "onPowerUpAction") {
            onPowerUpAction = action
        }
        if onPowerUpAction == "remember" {
            onPowerUpActionRemember.state = NSControl.StateValue.on
        } else if onPowerUpAction == "always" {
            onPowerUpActionAlways.state = NSControl.StateValue.on
        } else if onPowerUpAction == "never" {
            onPowerUpActionNever.state = NSControl.StateValue.on
        }

        // Launch at login
        launchAtLoginMenuItem.state = boolToMenuState(v: LaunchAtLogin.isEnabled)

        // Hide icon
        hideIconMenuItem.state = boolToMenuState(v: UserDefaults.standard.bool(forKey: "hideIcon"))
    }

    private func boolToMenuState(v: Bool) -> NSControl.StateValue {
        return v ? NSControl.StateValue.on : NSControl.StateValue.off
    }
}
