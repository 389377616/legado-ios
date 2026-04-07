import UIKit

/// 无动画翻页代理
/// 一比一移植自 Android Legado NoAnimPageDelegate.kt (28行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/NoAnimPageDelegate.kt
class NoAnimPageDelegate: HorizontalPageDelegate {
    
    override func onAnimStart(_ animationSpeed: Int) {
        if !isCancel {
            readView?.fillPage(mDirection)
        }
        stopScroll()
    }
    
    override func setBitmap() {
    }
    
    override func onDraw(_ context: CGContext) {
    }
    
    override func onAnimStop() {
    }
}