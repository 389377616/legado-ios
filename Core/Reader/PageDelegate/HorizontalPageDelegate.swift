import UIKit

/// 水平翻页代理基类
/// 一比一移植自 Android Legado HorizontalPageDelegate.kt (155行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/HorizontalPageDelegate.kt
class HorizontalPageDelegate: PageDelegate {
    
    var curRecorder: CanvasRecorder
    var prevRecorder: CanvasRecorder
    var nextRecorder: CanvasRecorder
    
    override init(readView: ReadViewProtocol) {
        self.curRecorder = CanvasRecorder()
        self.prevRecorder = CanvasRecorder()
        self.nextRecorder = CanvasRecorder()
        super.init(readView: readView)
    }
    
    override func setDirection(_ direction: PageDirection) {
        super.setDirection(direction)
        setBitmap()
    }
    
    override func setBitmap() {
        switch mDirection {
        case .prev:
            prevRecorder.setImage(prevPage.screenshot())
            curRecorder.setImage(curPage.screenshot())
        case .next:
            nextRecorder.setImage(nextPage.screenshot())
            curRecorder.setImage(curPage.screenshot())
        case .none:
            break
        }
    }
    
    func upRecorder() {
        curRecorder.recycle()
        prevRecorder.recycle()
        nextRecorder.recycle()
        curRecorder = CanvasRecorder()
        prevRecorder = CanvasRecorder()
        nextRecorder = CanvasRecorder()
    }
    
    override func onTouch(event: UITouch, view: UIView) {
        switch event.phase {
        case .began:
            abortAnim()
        case .moved:
            onScroll(event: event, view: view)
        case .ended, .cancelled:
            onAnimStart(animationSpeed: readView?.defaultAnimationSpeed ?? 300)
        default:
            break
        }
    }
    
    private func onScroll(event: UITouch, view: UIView) {
        let point = event.location(in: view)
        var sumX = point.x
        var sumY = point.y
        
        if !isMoved {
            let deltaX = Int(sumX - startX)
            let deltaY = Int(sumY - startY)
            let distance = deltaX * deltaX + deltaY * deltaY
            let slopSquare = readView?.pageSlopSquare2 ?? 0
            isMoved = distance > slopSquare
            if isMoved {
                if sumX - startX > 0 {
                    if !hasPrev() {
                        noNext = true
                        return
                    }
                    setDirection(.prev)
                } else {
                    if !hasNext() {
                        noNext = true
                        return
                    }
                    setDirection(.next)
                }
                readView?.setStartPoint(point.x, point.y, anim: false)
            }
        }
        if isMoved {
            isCancel = mDirection == .next ? sumX > lastX : sumX < lastX
            isRunning = true
            readView?.setTouchPoint(sumX, sumY, anim: false)
        }
    }
    
    override func abortAnim() {
        isStarted = false
        isMoved = false
        isRunning = false
        if !isScrollerFinished {
            readView?.isAbortAnim = true
            abortScrollerAnimation()
            if !isCancel {
                readView?.fillPage(mDirection)
                readView?.invalidate()
            }
        } else {
            readView?.isAbortAnim = false
        }
    }
    
    override func nextPageByAnim(animationSpeed: Int) {
        abortAnim()
        if !hasNext() { return }
        setDirection(.next)
        let y: CGFloat
        if startY > viewHeight / 2 {
            y = viewHeight * 0.9
        } else {
            y = 1
        }
        readView?.setStartPoint(viewWidth * 0.9, y, anim: false)
        onAnimStart(animationSpeed: animationSpeed)
    }
    
    override func prevPageByAnim(animationSpeed: Int) {
        abortAnim()
        if !hasPrev() { return }
        setDirection(.prev)
        readView?.setStartPoint(0, viewHeight, anim: false)
        onAnimStart(animationSpeed: animationSpeed)
    }
    
    override func onDestroy() {
        super.onDestroy()
        prevRecorder.recycle()
        curRecorder.recycle()
        nextRecorder.recycle()
    }
}

/// Canvas 记录器
/// 一比一移植自 Android Legado CanvasRecorder
class CanvasRecorder: CanvasRecorderProtocol {
    private var image: UIImage?
    
    var width: CGFloat { image?.size.width ?? 0 }
    var height: CGFloat { image?.size.height ?? 0 }
    
    func setImage(_ image: UIImage?) {
        self.image = image
    }
    
    func draw(_ context: CGContext) {
        guard let image = image else { return }
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    
    func recycle() {
        image = nil
    }
}