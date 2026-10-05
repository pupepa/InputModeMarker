//
//  InputModeMarkerApp.swift
//  InputModeMarker
//

import SwiftUI

@main
struct InputModeMarkerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let monitor = InputSourceMonitor()
  private var panelController: IndicatorPanelController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    panelController = IndicatorPanelController(monitor: monitor)
  }
}
