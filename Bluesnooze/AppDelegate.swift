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
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            hideIconMenuItem.state = NSControl.StateValue.on
        } else {
            initStatusItem()
        }
        setLaunchAtLoginState()
        setupNotificationHandlers()
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
    }

    // Re-add the status bar icon when the app is launched a second time
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        initStatusItem()
        return true
    }

    // MARK: Click handlers

    @IBAction func onPowerUpActionRememberClicked(_ sender: NSMenuItem) {
        onPowerUpAction = "remember"
        UserDefaults.standard.set(onPowerUpAction, forKey: "onPowerUpAction")
        onPowerUpActionRemember.state = NSControl.StateValue.on
        onPowerUpActionAlways.state = NSControl.StateValue.off
        onPowerUpActionNever.state = NSControl.StateValue.off
    }

    @IBAction func onPowerUpActionAlwaysClicked(_ sender: NSMenuItem) {
        onPowerUpAction = "always"
        UserDefaults.standard.set(onPowerUpAction, forKey: "onPowerUpAction")
        onPowerUpActionRemember.state = NSControl.StateValue.off
        onPowerUpActionAlways.state = NSControl.StateValue.on
        onPowerUpActionNever.state = NSControl.StateValue.off
    }

    @IBAction func onPowerUpActionNeverClicked(_ sender: NSMenuItem) {
        onPowerUpAction = "never"
        UserDefaults.standard.set(onPowerUpAction, forKey: "onPowerUpAction")
        onPowerUpActionRemember.state = NSControl.StateValue.off
        onPowerUpActionAlways.state = NSControl.StateValue.off
        onPowerUpActionNever.state = NSControl.StateValue.on
    }

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        setLaunchAtLoginState()
    }

    @IBAction func hideIconClicked(_ sender: NSMenuItem) {
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            UserDefaults.standard.removeObject(forKey: "hideIcon")
            hideIconMenuItem.state = NSControl.StateValue.off
        } else {
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
        statusItem.menu = statusMenu
    }

    private func setLaunchAtLoginState() {
        let state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
        launchAtLoginMenuItem.state = state
    }
}
