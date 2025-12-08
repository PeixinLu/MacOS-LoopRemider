import SwiftUI
import AppKit

// App Delegate to handle lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ReminderController?
    var openSettingsAction: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 默认使用 accessory 模式，不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理定时器和通知
        controller?.cleanup()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击 Dock 图标或 Command+Tab 切换时，显示设置窗口
        if !flag {
            openSettingsAction?()
        }
        return true
    }
}

@main
struct loopRemiderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var controller = ReminderController()
    @Environment(\.openWindow) private var openWindow
    @State private var settingsWindowOpen = false

    var body: some Scene {
        // 菜单栏
        MenuBarExtra {
            Button(settings.isRunning ? "暂停" : "启动") {
                if settings.isRunning {
                    settings.isRunning = false
                    controller.stop()
                } else {
                    settings.isRunning = true
                    controller.start(settings: settings)
                }
            }

            Button("配置…") {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: settings.isRunning ? "bell.fill" : "bell")
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.menu)

        // 配置窗口（使用普通 Window 而非 Settings）
        Window("配置", id: "settings") {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
                .onAppear {
                    appDelegate.controller = controller
                    appDelegate.openSettingsAction = openSettingsWindow
                    settingsWindowOpen = true
                    // 切换到 regular 模式，显示 Dock 图标
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    settingsWindowOpen = false
                    // 切换回 accessory 模式，隐藏 Dock 图标
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 1200, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    // 打开设置窗口
    func openSettingsWindow() {
        // 先查找是否已有窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "配置" || $0.identifier?.rawValue == "settings" }) {
            // 切换到 regular 模式
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // 创建新窗口
            openWindow(id: "settings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
