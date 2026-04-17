import UIKit

/// 覆盖翻页代理
/// 一比一移植自 Android Legado CoverPageDelegate.kt (117行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/CoverPageDelegate.kt
class CoverPageDelegate: HorizontalPageDelegate {
    
    private var shadowDrawableR: CAGradientLayer?
    
    override init(readView: ReadViewProtocol) {
        super.init(readView: readView)
        setupShadowDrawable()
    }
    
    private func setupShadowDrawable() {
        let shadowColors: [CGColor] = [
            UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 0.4).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
        ]
        shadowDrawableR = CAGradientLayer()
        shadowDrawableR?.colors = shadowColors
        shadowDrawableR?.startPoint = CGPoint(x: 0, y: 0.5)
        shadowDrawableR?.endPoint = CGPoint(x: 1, y: 0.5)
    }
    
    override func onDraw(_ context: CGContext) {
        if !isRunning { return }
        let offsetX = touchX - startX
        
        if (mDirection == .next && offsetX > 0) || (mDirection == .prev && offsetX < 0) {
            return
        }
        
        let distanceX: CGFloat = offsetX > 0 ? offsetX - viewWidth : offsetX + viewWidth
        
        context.saveGState()
        
        if mDirection == .prev {
            if offsetX <= viewWidth {
                context.translateBy(x: distanceX, y: 0)
                prevRecorder.draw(context)
                context.restoreGState()
                addShadow(left: distanceX, context: context)
            } else {
                prevRecorder.draw(context)
                context.restoreGState()
            }
        } else if mDirection == .next {
            let width = nextRecorder.width
            let height = nextRecorder.height
            let clipRect = CGRect(x: width + offsetX, y: 0, width: width, height: height)
            context.clip(to: clipRect)
            nextRecorder.draw(context)
            context.restoreGState()
            
            context.saveGState()
            context.translateBy(x: distanceX - viewWidth, y: 0)
            curRecorder.draw(context)
            context.restoreGState()
            addShadow(left: distanceX, context: context)
        } else {
            context.restoreGState()
        }
    }
    
    override func setBitmap() {
        switch mDirection {
        case .prev:
            prevRecorder.setImage(prevPage.screenshot())
        case .next:
            nextRecorder.setImage(nextPage.screenshot())
            curRecorder.setImage(curPage.screenshot())
        case .none:
            break
        }
    }
    
    private func addShadow(left: CGFloat, context: CGContext) {
        if left == 0 { return }
        let dx: CGFloat = left < 0 ? left + viewWidth : left
        
        context.saveGState()
        context.translateBy(x: dx, y: 0)
        
        let colors: [CGColor] = [
            UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 0.4).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor
        ]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 30, y: 0), options: [])
        }
        
        context.restoreGState()
    }
    
    override func setViewSize(width: CGFloat, height: CGFloat) {
        super.setViewSize(width: width, height: height)
        shadowDrawableR?.frame = CGRect(x: 0, y: 0, width: 30, height: viewHeight)
    }
    
    override func onAnimStop() {
        if !isCancel {
            readView?.fillPage(mDirection)
        }
    }
    
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
}