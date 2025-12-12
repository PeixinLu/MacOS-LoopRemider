//
//  LogsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct LogsView: View {
    @State private var logs: [String] = []
    private let logger = EventLogger.shared
    private let blockedKeywords = ["script", "javascript:", "<", ">", "file://", "vscode://", "http://", "https://"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("日志", systemImage: "doc.text.magnifyingglass")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        reload()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    Button {
                        logger.clear()
                        reload()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    Button {
                        logger.openInFinder()
                    } label: {
                        Label("访达中打开", systemImage: "folder")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Text("记录通知发送、启动/重置/停止等关键事件，方便排查问题。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if logs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.fill").font(.largeTitle).foregroundStyle(.secondary)
                            Text("暂无日志").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                            Text(sanitize(line))
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1) // 单行展示，不换行
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }
    
    private func reload() {
        logs = logger.readAll()
    }
    
    private func sanitize(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\n", with: " ")
        for keyword in blockedKeywords {
            if result.localizedCaseInsensitiveContains(keyword) {
                result = result.replacingOccurrences(of: keyword, with: "***", options: .regularExpression, range: nil)
            }
        }
        return result
    }
}
