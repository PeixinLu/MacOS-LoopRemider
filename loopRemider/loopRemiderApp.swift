import SwiftUI
import AppKit

// App Delegate to handle lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ReminderController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 简单激活应用，用户可以手动点击菜单栏图标打开配置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理定时器和通知
        Task { @MainActor in
            await controller?.cleanup()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击 Dock 图标或 Command+Tab 切换时，显示设置窗口
        if !flag {
            openSettingsWindow()
        }
        return true
    }
    
    private func openSettingsWindow() {
        for window in NSApp.windows {
            if window.title == "配置" || window.identifier?.rawValue == "settings" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

@main
struct loopRemiderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var controller = ReminderController()
    @Environment(\.openWindow) private var openWindow

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
                openWindow(id: "settings")
                // 延迟激活以确保窗口已创建
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    activateSettingsWindow()
                }
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
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    // 激活设置窗口
    private func activateSettingsWindow() {
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 查找设置窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let settingsWindow = NSApp.windows.first(where: { $0.title == "配置" || $0.identifier?.rawValue == "settings" }) {
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
                settingsWindow.level = .floating
                
                // 重置窗口层级（避免一直置顶）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    settingsWindow.level = .normal
                }
            }
        }
    }
}
