//
//  InputSourceMonitor.swift
//  InputModeMarker
//

import AppKit
import Carbon
import Observation

/// 現在の入力モード
enum InputMode {
  case japanese
  case alphabet
}

/// システムの入力ソースを監視し、日本語 / 英数のどちらかを公開する
@Observable
final class InputSourceMonitor {
  private(set) var mode: InputMode = .alphabet
  private(set) var sourceName = ""

  @ObservationIgnored
  private var tasks: [Task<Void, Never>] = []

  init() {
    refresh()

    // 入力ソースが切り替わったときに通知される分散通知
    let inputSourceChanged = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)

    tasks.append(
      Task { [weak self] in
        for await _ in DistributedNotificationCenter.default().notifications(named: inputSourceChanged) {
          self?.refresh()
        }
      }
    )

    // アプリごとに入力ソースが異なる設定の場合に備え、アプリ切り替え時にも再取得する
    tasks.append(
      Task { [weak self] in
        for await _ in NSWorkspace.shared.notificationCenter.notifications(
          named: NSWorkspace.didActivateApplicationNotification
        ) {
          self?.refresh()
        }
      }
    )
  }

  deinit {
    tasks.forEach { $0.cancel() }
  }

  func refresh() {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }

    // IMEの場合は入力モードID (例: com.apple.inputmethod.Japanese.Roman) を優先する
    let modeID: String? = property(of: source, key: kTISPropertyInputModeID)
    let sourceID: String? = property(of: source, key: kTISPropertyInputSourceID)
    let identifier = modeID ?? sourceID ?? ""
    let languages: [String] = property(of: source, key: kTISPropertyInputSourceLanguages) ?? []

    // ことえり・Google日本語入力・ATOKなどは英数モードのIDが "Roman" で終わる
    let isJapanese = languages.first == "ja" && !identifier.contains("Roman")
    let newMode: InputMode = isJapanese ? .japanese : .alphabet
    if mode != newMode {
      mode = newMode
    }

    sourceName = property(of: source, key: kTISPropertyLocalizedName) ?? identifier
  }

  private func property<T>(of source: TISInputSource, key: CFString) -> T? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }

    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
  }
}
