import UIKit

/// 滑动翻页代理
/// 一比一移植自 Android Legado SlidePageDelegate.kt (64行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/SlidePageDelegate.kt
class SlidePageDelegate: HorizontalPageDelegate {
    
    override func onAnimStart(animationSpeed: Int) {
        var distanceX: CGFloat = 0
        
        switch mDirection {
        case .next:
            if isCancel {
                var dis = viewWidth - startX + touchX
                if dis > viewWidth { dis = viewWidth }
                distanceX = viewWidth - dis
            } else {
                distanceX = -(touchX + (viewWidth - startX))
            }
        case .prev:
            if isCancel {
                distanceX = -(touchX - startX)
            } else {
                distanceX = viewWidth - (touchX - startX)
            }
        case .none:
            break
        }
        
        startScroll(startX: Int(touchX), startY: 0, dx: Int(distanceX), dy: 0, animationSpeed: animationSpeed)
    }
    
    override func onDraw(_ context: CGContext) {
        let offsetX = touchX - startX
        
        if (mDirection == .next && offsetX > 0) || (mDirection == .prev && offsetX < 0) {
            return
        }
        
        if !isRunning { return }
        
        let distanceX: CGFloat = offsetX > 0 ? offsetX - viewWidth : offsetX + viewWidth
        
        if mDirection == .prev {
            context.saveGState()
            context.translateBy(x: distanceX + viewWidth, y: 0)
            curRecorder.draw(context)
            context.restoreGState()
            
            context.saveGState()
            context.translateBy(x: distanceX, y: 0)
            prevRecorder.draw(context)
            context.restoreGState()
        } else if mDirection == .next {
            context.saveGState()
            context.translateBy(x: distanceX, y: 0)
            nextRecorder.draw(context)
            context.restoreGState()
            
            context.saveGState()
            context.translateBy(x: distanceX - viewWidth, y: 0)
            curRecorder.draw(context)
            context.restoreGState()
        }
    }
    
    override func onAnimStop() {
        if !isCancel {
            readView?.fillPage(mDirection)
        }
    }
}