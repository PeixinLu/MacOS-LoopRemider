//
//  AboutView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct AboutView: View {
    @State private var markdownContent: AttributedString = AttributedString("")
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if markdownContent.characters.isEmpty {
                ProgressView("加载中...")
            } else {
                Text(markdownContent)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 650)
                    .padding(.horizontal, 50)
            }
            
            Spacer()
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
            return
        }
        
        // 使用 SwiftUI 原生的 Markdown 支持
        do {
            markdownContent = try AttributedString(markdown: content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            markdownContent = AttributedString(content)
        }
    }
}
