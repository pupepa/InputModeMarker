//
//  IndicatorSettings.swift
//  InputModeMarker
//

import AppKit
import Observation
import SwiftUI

/// UserDefaultsのキー
enum SettingsKey {
  static let indicatorSize = "indicatorSize"
  static let japaneseColor = "japaneseColor"
  static let alphabetColor = "alphabetColor"
}

/// バッジの背景色のプリセット
enum IndicatorColor: String, CaseIterable, Identifiable {
  case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, brown, gray, black

  var id: Self { self }

  var name: LocalizedStringKey {
    switch self {
    case .blue: "青"
    case .indigo: "藍"
    case .purple: "紫"
    case .pink: "ピンク"
    case .red: "赤"
    case .orange: "オレンジ"
    case .yellow: "黄"
    case .green: "緑"
    case .mint: "ミント"
    case .teal: "ティール"
    case .brown: "茶"
    case .gray: "グレー"
    case .black: "黒"
    }
  }

  var nsColor: NSColor {
    switch self {
    case .blue: .systemBlue
    case .indigo: .systemIndigo
    case .purple: .systemPurple
    case .pink: .systemPink
    case .red: .systemRed
    case .orange: .systemOrange
    case .yellow: .systemYellow
    case .green: .systemGreen
    case .mint: .systemMint
    case .teal: .systemTeal
    case .brown: .systemBrown
    case .gray: .systemGray
    case .black: .black
    }
  }

  var color: Color {
    Color(nsColor: nsColor)
  }

  /// 明るい背景色では白文字が読みにくいので黒文字にする
  var textColor: Color {
    switch self {
    case .yellow, .mint: .black
    default: .white
    }
  }

  /// メニューに表示する色見本。テンプレート画像にならないようNSImageで描く
  var swatch: NSImage {
    let nsColor = nsColor
    let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
      nsColor.setFill()
      NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()

      return true
    }
    image.isTemplate = false

    return image
  }
}

/// バッジの大きさとパネルの寸法を管理する
@Observable
final class IndicatorLayout {
  static let defaultSize = 40.0
  static let sizeRange = 12.0...120.0

  /// 文字の大きさ。バッジやパネルの寸法はこれを基準に決まる
  var size: Double

  init() {
    let stored = UserDefaults.standard.double(forKey: SettingsKey.indicatorSize)
    size = stored > 0 ? stored.clamped(to: Self.sizeRange) : Self.defaultSize
  }

  var badgeSize: CGSize {
    CGSize(width: size * 2.2, height: size * 1.5)
  }

  /// 切り替え時の拡大アニメーションがはみ出さないための余白
  var padding: Double {
    6 + size * 0.15
  }

  var panelSize: CGSize {
    CGSize(width: badgeSize.width + padding * 2, height: badgeSize.height + padding * 2)
  }

  func save() {
    UserDefaults.standard.set(size, forKey: SettingsKey.indicatorSize)
  }
}

extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
