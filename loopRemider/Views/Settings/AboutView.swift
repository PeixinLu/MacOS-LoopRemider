//
//  AboutView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct AboutView: View {
    @State private var markdownContent: AttributedString = AttributedString("")
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(markdownContent)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                }
                .background(Color.clear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadMarkdownContent()
        }
    }
    
    private func loadMarkdownContent() {
        guard let url = Bundle.main.url(forResource: "welcome", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            markdownContent = AttributedString("无法加载欢迎内容。")
            isLoading = false
            return
        }
        
        do {
            // 使用 SwiftUI 原生的 Markdown 支持，保留原始换行和空格
            var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            markdownContent = try AttributedString(markdown: content, options: options)
        } catch {
            // 如果解析失败，使用原始文本
            markdownContent = AttributedString(content)
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    AboutView()
        .frame(width: 800, height: 600)
}
