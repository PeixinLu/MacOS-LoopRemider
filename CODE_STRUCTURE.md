# 文件结构说明

项目代码已重构为模块化结构，方便维护和扩展。

## 目录结构

```
loopRemider/
├── Models/                      # 数据模型
│   └── AppSettings.swift        # 应用设置类（包含所有配置和枚举）
│
├── Controllers/                 # 控制器
│   └── ReminderController.swift # 提醒控制器（定时器和通知管理）
│
├── Views/                       # 视图
│   ├── ContentView.swift        # 主视图（菜单栏显示内容）
│   ├── SettingsView.swift       # 设置界面（基本设置 + 样式设置）
│   └── OverlayNotificationView.swift  # 遮罩通知视图
│
├── Extensions/                  # 扩展
│   └── ColorExtension.swift     # Color扩展（RGB组件提取）
│
└── loopRemiderApp.swift         # 应用入口
```

## 各文件职责

### Models

- **AppSettings.swift**
  - 应用设置数据模型
  - UserDefaults持久化
  - 配置枚举（通知模式、位置、颜色等）
  - 辅助方法（时间格式化、颜色获取等）

### Controllers

- **ReminderController.swift**
  - 定时器管理
  - 系统通知发送
  - 遮罩窗口创建和管理
  - 通知权限处理

### Views

- **ContentView.swift**
  - 菜单栏主视图
  - 显示运行状态和频率

- **SettingsView.swift**
  - 左右分栏设置界面
  - 基本设置（启动/暂停、频率、内容等）
  - 样式设置（位置、颜色、尺寸、模糊等）
  - 实时预览功能

- **OverlayNotificationView.swift**
  - 屏幕遮罩通知视图
  - 自动淡化动画
  - 可自定义样式

### Extensions

- **ColorExtension.swift**
  - Color到RGB组件的转换
  - 用于自定义颜色的持久化

## 优势

1. **模块化**：每个文件职责单一，易于理解和维护
2. **可扩展**：新功能可以轻松添加到对应模块
3. **可测试**：各模块独立，便于单元测试
4. **代码复用**：组件化设计，便于在其他地方使用
