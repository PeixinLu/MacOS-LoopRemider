import SwiftUI

struct AboutView: View {
    @State private var markdownContent: AttributedString = AttributedString("")
    @State private var isLoading = true
    @State private var showCopiedToast = false
    @State private var copiedType: CopiedType? = nil
    
    enum CopiedType {
        case groupNumber
        case answer
    }
    
    private let qqGroupNumber = "1077353755" // 替换为你的实际QQ群号
    private let qqGroupAnswer = "小怪兽" // 入群验证答案
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: "关于",
                subtitle: "了解更多应用信息"
            )
            
            // 内容区域 - 可滚动
            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // QQ群卡片
                        qqGroupCard
                        
                        Divider()
                            .padding(.horizontal, DesignTokens.Spacing.xxxl)
                        
                        // Markdown内容
                        Text(markdownContent)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, DesignTokens.Spacing.xxxl)
                    }
                    .padding(.vertical, DesignTokens.Spacing.xl)
                }
                .background(Color.clear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // 复制成功提示
            Group {
                if showCopiedToast, let type = copiedType {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(type == .groupNumber ? "已复制QQ群号" : "已复制入群答案")
                                .font(.callout)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        )
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
        .onAppear {
            loadMarkdownContent()
        }
    }
    
    // MARK: - QQ Group Card
    
    private var qqGroupCard: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("加入反馈交流群")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Text("使用中遇到任何问题（或者功能许愿）请加入群聊，我会积极处理🫡")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // QQ群信息卡片
            VStack(spacing: DesignTokens.Spacing.md) {
                // QQ群号
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "number.circle.fill")
                            .foregroundStyle(.blue)
                        Text("QQ群号")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        copyToClipboard(qqGroupNumber, type: .groupNumber)
                    } label: {
                        HStack(spacing: 4) {
                            Text("点击复制")
                                .font(.callout)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // 入群验证
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.orange)
                        Text("入群答案")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        copyToClipboard(qqGroupAnswer, type: .answer)
                    } label: {
                        HStack(spacing: 4) {
                            Text("点击复制")
                                .font(.callout)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
            
            // 提示信息
            InfoHint("点击上方按钮复制QQ群号和入群答案，然后在QQ中搜索群号并申请加入", color: .blue)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: 500)
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
    
    private func copyToClipboard(_ text: String, type: CopiedType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 显示复制成功提示
        copiedType = type
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        
        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AboutView()
        .frame(width: 800, height: 600)
}
