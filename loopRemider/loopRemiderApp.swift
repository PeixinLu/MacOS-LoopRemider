import SwiftUI
import AppKit

// App Delegate to handle lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ReminderController?
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?
    
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
            showSettingsWindow()
        }
        return true
    }
    
    func showSettingsWindow() {
        if let window = settingsWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

@main
struct loopRemiderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var controller = ReminderController()
    @State private var hasLaunched = false

    var body: some Scene {
        // 使用 WindowGroup 代替 Window（macOS 12 兼容）
        WindowGroup("配置", id: "settings") {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
                .onAppear {
                    setupApp()
                    // 只有在非静默启动模式下才打开设置窗口
                    if !hasLaunched {
                        hasLaunched = true
                        if !settings.silentLaunch {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appDelegate.showSettingsWindow()
                            }
                        }
                    }
                }
                .onDisappear {
                    // 切换回 accessory 模式，隐藏 Dock 图标
                    NSApp.setActivationPolicy(.accessory)
                }
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    private func setupApp() {
        appDelegate.controller = controller
        
        // 设置 settingsWindow 引用
        if appDelegate.settingsWindow == nil {
            DispatchQueue.main.async {
                appDelegate.settingsWindow = NSApp.windows.first(where: { $0.title == "配置" })
            }
        }
        
        // 创建状态栏控制器（兼容 macOS 12）
        if appDelegate.statusBarController == nil {
            appDelegate.statusBarController = StatusBarController(
                settings: settings,
                controller: controller,
                onShowSettings: {
                    appDelegate.showSettingsWindow()
                }
            )
        }
    }
}

// macOS 12 兼容：使用传统 NSStatusBar
class StatusBarController {
    private var statusItem: NSStatusItem?
    private var settings: AppSettings
    private var controller: ReminderController
    private var onShowSettings: () -> Void
    
    init(settings: AppSettings, controller: ReminderController, onShowSettings: @escaping () -> Void) {
        self.settings = settings
        self.controller = controller
        self.onShowSettings = onShowSettings
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            updateIcon()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        updateMenu()
    }
    
    @objc private func statusBarButtonClicked() {
        updateMenu()
        statusItem?.menu = createMenu()
        statusItem?.button?.performClick(nil)
    }
    
    private func updateIcon() {
        let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
        let iconName = hasRunningTimer ? "bell.fill" : "bell"
        
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Loop Reminder")
            image?.isTemplate = true
            button.image = image
        }
    }
    
    private func updateMenu() {
        statusItem?.menu = createMenu()
    }
    
    private func createMenu() -> NSMenu {
        updateIcon()
        
        let menu = NSMenu()
        
        // 全部启动/停止按钮
        let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
        let toggleAllItem = NSMenuItem(
            title: hasRunningTimer ? "全部停止" : "全部启动",
            action: #selector(toggleAll),
            keyEquivalent: ""
        )
        toggleAllItem.target = self
        menu.addItem(toggleAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 各个计时器的启停开关
        if !settings.timers.isEmpty {
            let timersSection = NSMenuItem(title: "计时器", action: nil, keyEquivalent: "")
            timersSection.isEnabled = false
            menu.addItem(timersSection)
            
            for timer in settings.timers {
                let timerItem = NSMenuItem(
                    title: timer.displayName,
                    action: #selector(toggleTimer(_:)),
                    keyEquivalent: ""
                )
                timerItem.target = self
                timerItem.representedObject = timer.id
                timerItem.state = timer.isRunning ? .on : .off
                timerItem.isEnabled = timer.isContentValid()
                menu.addItem(timerItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 设置中心
        let settingsItem = NSMenuItem(
            title: "设置中心",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(
            title: "退出 LoopReminder",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc private func toggleAll() {
        let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
        
        if hasRunningTimer {
            for timer in settings.timers where timer.isRunning {
                controller.stopTimer(timer.id, settings: settings)
            }
            settings.isRunning = false
        } else {
            settings.isRunning = true
            controller.start(settings: settings)
        }
        
        updateMenu()
    }
    
    @objc private func toggleTimer(_ sender: NSMenuItem) {
        guard let timerId = sender.representedObject as? UUID else { return }
        
        if let timer = settings.timers.first(where: { $0.id == timerId }) {
            if timer.isRunning {
                controller.stopTimer(timerId, settings: settings)
            } else {
                controller.startTimer(timerId, settings: settings)
            }
        }
        
        updateMenu()
    }
    
    @objc private func showSettings() {
        onShowSettings()
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
