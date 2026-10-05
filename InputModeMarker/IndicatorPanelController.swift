//
//  IndicatorPanelController.swift
//  InputModeMarker
//

import AppKit
import SwiftUI

/// 入力モードを表示する、好きな場所に置けるフローティングパネルを管理する
final class IndicatorPanelController {
  private static let frameAutosaveName = "IndicatorPanel"

  private let panel: NSPanel
  private let layout = IndicatorLayout()

  // ドラッグ開始時の状態 (スクリーン座標)
  private var dragStartMouse: NSPoint?
  private var dragStartOrigin: NSPoint?
  private var dragStartSize: Double?

  init(monitor: InputSourceMonitor) {
    panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: layout.panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .statusBar
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

    let actions = IndicatorActions(
      moveChanged: { [weak self] in self?.moveChanged() },
      moveEnded: { [weak self] in self?.dragEnded() },
      resizeChanged: { [weak self] in self?.resizeChanged() },
      resizeEnded: { [weak self] in self?.dragEnded() },
      resetSize: { [weak self] in self?.resetSize() }
    )

    let hostingView = FirstMouseHostingView(rootView: IndicatorView(monitor: monitor, layout: layout, actions: actions))

    // パネルの大きさはコントローラーが決める
    hostingView.sizingOptions = []
    panel.contentView = hostingView

    // 前回置いた位置を復元する。画面外になっていたら初期位置に戻す
    if panel.setFrameUsingName(Self.frameAutosaveName), isOnScreen(panel.frame) {
      applySize()
    } else {
      resetPosition()
    }

    panel.setFrameAutosaveName(Self.frameAutosaveName)
    panel.orderFrontRegardless()
  }

  // MARK: - 位置とサイズ

  /// メイン画面の下部中央に置く
  private func resetPosition() {
    guard let screen = NSScreen.main else { return }

    let visible = screen.visibleFrame
    let size = layout.panelSize

    panel.setFrame(
      NSRect(x: visible.midX - size.width / 2, y: visible.minY + 40, width: size.width, height: size.height),
      display: true
    )

    panel.saveFrame(usingName: Self.frameAutosaveName)
  }

  private func resetSize() {
    layout.size = IndicatorLayout.defaultSize
    applySize()
    layout.save()
    panel.saveFrame(usingName: Self.frameAutosaveName)
  }

  /// 左上を固定したままパネルの大きさを合わせる
  private func applySize() {
    let size = layout.panelSize
    let frame = panel.frame

    panel.setFrame(
      NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height),
      display: true
    )
  }

  private func isOnScreen(_ frame: NSRect) -> Bool {
    NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
  }

  // MARK: - ドラッグ

  // ビュー内の座標ではなくスクリーン座標で計算し、ウインドウ移動によるずれを防ぐ

  private func moveChanged() {
    let mouse = NSEvent.mouseLocation

    if dragStartMouse == nil {
      dragStartMouse = mouse
      dragStartOrigin = panel.frame.origin
    }

    guard let startMouse = dragStartMouse, let startOrigin = dragStartOrigin else { return }

    panel.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x, y: startOrigin.y + mouse.y - startMouse.y))
  }

  private func resizeChanged() {
    let mouse = NSEvent.mouseLocation

    if dragStartMouse == nil {
      dragStartMouse = mouse
      dragStartSize = layout.size
    }

    guard let startMouse = dragStartMouse, let startSize = dragStartSize else { return }

    // 右方向と下方向の移動量を、バッジの縦横比に合わせて文字サイズの変化量に換算する
    let dx = mouse.x - startMouse.x
    let dy = startMouse.y - mouse.y
    let delta = (dx / 2.2 + dy / 1.5) / 2
    layout.size = (startSize + delta).clamped(to: IndicatorLayout.sizeRange)

    applySize()
  }

  private func dragEnded() {
    if dragStartSize != nil {
      layout.save()
    }

    dragStartMouse = nil
    dragStartOrigin = nil
    dragStartSize = nil

    panel.saveFrame(usingName: Self.frameAutosaveName)
  }
}

/// アプリが非アクティブでも最初のクリックからドラッグできるようにする
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }
}
