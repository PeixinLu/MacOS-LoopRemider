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
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 1.0
    @State private var scale: Double = 1.0
    
    var body: some View {
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
                    // 整体模糊背景效果（类似iOS18之前的效果）
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    
                    // 颜色叠加层
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
        .onAppear {
            startFadeTimer()
        }
        .onTapGesture {
            onDismiss()
        }
    }
    
    private func startFadeTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeStartDelay) {
            // 使用更平滑的淡出动画，结合透明度和缩放
            withAnimation(.easeInOut(duration: fadeDuration)) {
                opacity = 0.0
                scale = 0.95
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.1) {
                onDismiss()
            }
        }
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
