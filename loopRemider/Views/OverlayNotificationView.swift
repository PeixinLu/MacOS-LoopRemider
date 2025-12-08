//
//  OverlayNotificationView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct OverlayNotificationView: View {
    let emoji: String
    let title: String
    let message: String
    let backgroundColor: Color
    let backgroundOpacity: Double
    let fadeStartDelay: Double
    let fadeDuration: Double
    let titleFontSize: Double
    let iconSize: Double
    let cornerRadius: Double
    let contentSpacing: Double
    let useBlur: Bool
    let blurIntensity: Double
    let overlayWidth: Double
    let overlayHeight: Double
    let animationStyle: AppSettings.AnimationStyle
    let position: AppSettings.OverlayPosition
    let padding: Double
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 1.0
    @State private var scale: Double = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            // 通知卡片
            VStack(spacing: contentSpacing) {
                HStack(spacing: contentSpacing) {
                    Text(emoji.isEmpty ? "⏰" : emoji)
                        .font(.system(size: iconSize))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title.isEmpty ? "提醒" : title)
                            .font(.system(size: titleFontSize, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(message)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .background(
                ZStack {
                    if useBlur {
                        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor.opacity(backgroundOpacity * blurIntensity * 0.7))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor.opacity(backgroundOpacity))
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(offset)
            // 只有卡片区域响应点击
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss()
            }
            // 根据position和padding计算对齐位置
            .padding(edgeInsetsForPosition())
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignmentForPosition())
            .onAppear {
                applyEntryAnimation(containerSize: geometry.size)
                startExitTimer(containerSize: geometry.size)
            }
            // 缓冲区不响应鼠标事件
            .allowsHitTesting(true)
        }
        // 窗口级别：只有卡片内容响应点击
        .background(Color.clear.allowsHitTesting(false))
    }
    
    // 根据位置返回对齐方式
    private func alignmentForPosition() -> Alignment {
        switch position {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        case .topCenter:
            return .top
        case .center:
            return .center
        case .bottomCenter:
            return .bottom
        }
    }
    
    // 根据位置返回EdgeInsets（保持padding距离）
    private func edgeInsetsForPosition() -> EdgeInsets {
        switch position {
        case .topLeft:
            return EdgeInsets(top: padding, leading: padding, bottom: 0, trailing: 0)
        case .topRight:
            return EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: padding)
        case .bottomLeft:
            return EdgeInsets(top: 0, leading: padding, bottom: padding + 80, trailing: 0)
        case .bottomRight:
            return EdgeInsets(top: 0, leading: 0, bottom: padding + 80, trailing: padding)
        case .topCenter:
            return EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: 0)
        case .center:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .bottomCenter:
            return EdgeInsets(top: 0, leading: 0, bottom: padding + 80, trailing: 0)
        }
    }
    
    private func applyEntryAnimation(containerSize: CGSize) {
        switch animationStyle {
        case .fade:
            opacity = 0
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1.0
            }
        case .slide:
            // 计算从哪个边进入：根据 position 选择最近的边
            let direction = slideDirectionForPosition()
            let extra: CGFloat = 60
            
            switch direction {
            case .fromLeft:
                // 从左侧外飞入（负x）
                offset = CGSize(width: -(containerSize.width/2 + overlayWidth/2 + extra), height: 0)
            case .fromRight:
                // 从右侧外飞入（正x）
                offset = CGSize(width: containerSize.width/2 + overlayWidth/2 + extra, height: 0)
            case .fromTop:
                // 从顶部外飞入（向上 = 负y）
                offset = CGSize(width: 0, height: -(containerSize.height/2 + overlayHeight/2 + extra))
            case .fromBottom:
                // 从底部外飞入（向下 = 正y）
                offset = CGSize(width: 0, height: containerSize.height/2 + overlayHeight/2 + extra)
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = .zero
            }
        case .scale:
            scale = 0.5
            opacity = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func startExitTimer(containerSize: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeStartDelay) {
            applyExitAnimation(containerSize: containerSize)
        }
    }
    
    private func applyExitAnimation(containerSize: CGSize) {
        switch animationStyle {
        case .fade:
            withAnimation(.easeInOut(duration: fadeDuration)) {
                opacity = 0.0
                scale = 0.95
            }
        case .slide:
            let direction = slideDirectionForPosition()
            let extra: CGFloat = 60
            
            withAnimation(.easeIn(duration: fadeDuration)) {
                opacity = 0.0
                switch direction {
                case .fromLeft:
                    offset = CGSize(width: -(containerSize.width/2 + overlayWidth/2 + extra), height: 0)
                case .fromRight:
                    offset = CGSize(width: containerSize.width/2 + overlayWidth/2 + extra, height: 0)
                case .fromTop:
                    offset = CGSize(width: 0, height: -(containerSize.height/2 + overlayHeight/2 + extra))
                case .fromBottom:
                    offset = CGSize(width: 0, height: containerSize.height/2 + overlayHeight/2 + extra)
                }
            }
        case .scale:
            withAnimation(.easeIn(duration: fadeDuration)) {
                scale = 0.5
                opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.1) {
            onDismiss()
        }
    }
    
    // 根据position确定从哪个边进入/退出
    private func slideDirectionForPosition() -> SlideDirection {
        switch position {
        case .topLeft, .bottomLeft:
            return .fromLeft
        case .topRight, .bottomRight:
            return .fromRight
        case .topCenter:
            return .fromTop
        case .bottomCenter:
            return .fromBottom
        case .center:
            // center位置：默认从上方进入
            return .fromTop
        }
    }
    
    private enum SlideDirection {
        case fromLeft
        case fromRight
        case fromTop
        case fromBottom
    }
}

// MARK: - Visual Effect Blur
// 自定义视觉效果模糊视图，实现整体模糊效果
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
