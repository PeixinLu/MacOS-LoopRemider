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
}

@main
struct loopRemiderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var controller = ReminderController()

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

            SettingsLink {
                Text("配置…")
            }

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        } label: {
            Text(settings.notifEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "⏰" : settings.notifEmoji)
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.menu)

        // "配置"窗口（系统设置风格）
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
                .onAppear {
                    // 确保设置窗口在前台
                    NSApp.activate(ignoringOtherApps: true)
                    // 传递 controller 给 AppDelegate 用于清理
                    appDelegate.controller = controller
                }
        }
    }
}
