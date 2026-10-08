//
//  IndicatorView.swift
//  InputModeMarker
//

import ServiceManagement
import SwiftUI

/// パネルのドラッグ操作をコントローラーに伝えるためのアクション
struct IndicatorActions {
  var moveChanged: () -> Void
  var moveEnded: () -> Void
  var resizeChanged: () -> Void
  var resizeEnded: () -> Void
  var resetSize: () -> Void
}

/// 好きな場所に置いて入力モードを表示するビュー
struct IndicatorView: View {
  var monitor: InputSourceMonitor
  var layout: IndicatorLayout
  var actions: IndicatorActions

  @AppStorage(SettingsKey.japaneseColor)
  private var japaneseColor = IndicatorColor.blue

  @AppStorage(SettingsKey.alphabetColor)
  private var alphabetColor = IndicatorColor.blue

  @AppStorage(SettingsKey.indicatorOpacity)
  private var indicatorOpacity = 1.0

  @State
  private var isPulsing = false

  @State
  private var isHovering = false

  @State
  private var isShowingOpacityControl = false

  @State
  private var launchAtLogin = SMAppService.mainApp.status == .enabled

  var body: some View {
    InputModeBadge(
      mode: monitor.mode,
      size: layout.size,
      color: monitor.mode == .japanese ? japaneseColor : alphabetColor
    )
    .opacity(indicatorOpacity)
    .scaleEffect(isPulsing ? 1.1 : 1)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(.rect)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in actions.moveChanged() }
        .onEnded { _ in actions.moveEnded() }
    )
    .overlay(alignment: .bottomTrailing) {
      ResizeHandle(isVisible: isHovering)
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { _ in actions.resizeChanged() }
            .onEnded { _ in actions.resizeEnded() }
        )
    }
    .onHover { isHovering = $0 }
    .contextMenu {
      ColorMenu(title: "日本語の背景色", selection: $japaneseColor)
      ColorMenu(title: "英数の背景色", selection: $alphabetColor)

      Button("不透明度を調整…") {
        isShowingOpacityControl = true
      }

      Divider()

      Button("サイズをリセット", action: actions.resetSize)
      Toggle("ログイン時に起動", isOn: $launchAtLogin)

      Divider()

      Button("あAマーカーを終了") {
        NSApplication.shared.terminate(nil)
      }
    }
    .popover(isPresented: $isShowingOpacityControl, arrowEdge: .bottom) {
      OpacityControl(opacity: $indicatorOpacity)
    }
    .onChange(of: launchAtLogin) { _, newValue in
      updateLaunchAtLogin(newValue)
    }
    .task(id: monitor.mode) {
      // モードが切り替わったら一瞬大きくして気付きやすくする
      withAnimation(.spring(duration: 0.15)) {
        isPulsing = true
      }

      try? await Task.sleep(for: .milliseconds(150))

      withAnimation(.spring(duration: 0.3)) {
        isPulsing = false
      }
    }
  }

  private func updateLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      launchAtLogin = SMAppService.mainApp.status == .enabled
    }
  }
}

/// 右下に表示するリサイズ用のつまみ
private struct ResizeHandle: View {
  var isVisible: Bool

  var body: some View {
    Image(systemName: "arrow.down.right")
      .font(.system(size: 8, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: 14, height: 14)
      .background(.black.opacity(0.5), in: .circle)
      .opacity(isVisible ? 1 : 0)
      .frame(width: 20, height: 20)
      .contentShape(.rect)
      .animation(.easeInOut(duration: 0.15), value: isVisible)
  }
}

/// コンテキストメニュー内で背景色を選ぶサブメニュー
private struct ColorMenu: View {
  var title: LocalizedStringKey

  @Binding
  var selection: IndicatorColor

  var body: some View {
    Picker(title, selection: $selection) {
      ForEach(IndicatorColor.allCases) { item in
        Label {
          Text(item.name)
        } icon: {
          Image(nsImage: item.swatch)
        }
        .tag(item)
      }
    }
  }
}

/// マーカーの不透明度を連続調整するポップオーバー
private struct OpacityControl: View {
  @Binding
  var opacity: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("不透明度")
        Spacer()
        Text(opacity, format: .percent.precision(.fractionLength(0)))
          .monospacedDigit()
      }

      Slider(value: $opacity, in: 0.1...1)
    }
    .padding()
    .frame(width: 240)
  }
}

/// macOSの入力モード切り替え時に表示されるような、楕円に「あ」「A」を書いたバッジ
struct InputModeBadge: View {
  var mode: InputMode
  var size: Double
  var color: IndicatorColor

  var body: some View {
    Text(mode == .japanese ? "あ" : "A")
      .font(.system(size: size, weight: .semibold))
      .foregroundStyle(color.textColor)
      .frame(width: size * 2.2, height: size * 1.5)
      .background(color.color, in: .capsule)
      .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
      .contentTransition(.opacity)
      .animation(.easeInOut(duration: 0.15), value: mode)
      .animation(.easeInOut(duration: 0.15), value: color)
  }
}

#Preview {
  HStack(spacing: 20) {
    InputModeBadge(mode: .japanese, size: 20, color: .red)
    InputModeBadge(mode: .alphabet, size: 20, color: .blue)
  }
  .padding()
}
