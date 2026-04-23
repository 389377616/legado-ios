import Foundation
import UIKit

// MARK: - 屏幕工具

enum ScreenUtils {

    // MARK: 尺寸

    static var screenBounds: CGRect {
        UIScreen.main.bounds
    }

    static var screenScale: CGFloat {
        UIScreen.main.scale
    }

    static var screenWidth: CGFloat {
        screenBounds.width
    }

    static var screenHeight: CGFloat {
        screenBounds.height
    }

    static var screenWidthPx: Int {
        Int((screenWidth * screenScale).rounded())
    }

    static var screenHeightPx: Int {
        Int((screenHeight * screenScale).rounded())
    }

    static var isLandscape: Bool {
        screenWidth > screenHeight
    }

    static var brightness: CGFloat {
        UIScreen.main.brightness
    }

    static func setBrightness(_ value: CGFloat) {
        UIScreen.main.brightness = min(max(value, 0), 1)
    }

    // MARK: 安全区域 / 状态栏

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    static var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .statusBarManager?
            .statusBarFrame.height ?? 0
    }

    static var navigationBarHeight: CGFloat {
        keyWindow?.safeAreaInsets.bottom ?? 0
    }

    static var safeAreaInsets: UIEdgeInsets {
        keyWindow?.safeAreaInsets ?? .zero
    }

    // MARK: 单位转换

    static func pointsToPixels(_ points: CGFloat) -> CGFloat {
        points * screenScale
    }

    static func pixelsToPoints(_ pixels: CGFloat) -> CGFloat {
        pixels / screenScale
    }
}
