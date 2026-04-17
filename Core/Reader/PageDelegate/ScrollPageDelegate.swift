import UIKit

/// 滚动翻页代理
/// 一比一移植自 Android Legado ScrollPageDelegate.kt (186行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/ScrollPageDelegate.kt
class ScrollPageDelegate: PageDelegate {
    
    private let velocityDuration: CGFloat = 1000
    private var velocityY: CGFloat = 0
    private var lastEventY: CGFloat = 0
    private var lastEventTime: CFTimeInterval = 0
    var noAnim: Bool = false
    
    override init(readView: ReadViewProtocol) {
        super.init(readView: readView)
    }
    
    override func onAnimStart(animationSpeed: Int) {
        readView?.onScrollAnimStart()
        fling(
            startX: 0, startY: Int(touchY),
            velocityX: 0, velocityY: Int(velocityY),
            minX: 0, maxX: 0,
            minY: -10 * Int(viewHeight), maxY: 10 * Int(viewHeight)
        )
    }
    
    override func onAnimStop() {
        readView?.onScrollAnimStop()
    }
    
    override func onTouch(event: UITouch, view: UIView) {
        let point = event.location(in: view)
        let time = CACurrentMediaTime()
        
        switch event.phase {
        case .began:
            abortAnim()
            velocityY = 0
            lastEventY = point.y
            lastEventTime = time
        case .moved:
            onScroll(event: event, view: view)
            if time - lastEventTime > 0 {
                velocityY = (point.y - lastEventY) / CGFloat(time - lastEventTime) * velocityDuration
            }
            lastEventY = point.y
            lastEventTime = time
        case .ended, .cancelled:
            onAnimStart(animationSpeed: readView?.defaultAnimationSpeed ?? 300)
        default:
            break
        }
    }
    
    override func onScroll() {
        curPage.scroll(Int(touchY - lastY))
    }
    
    override func onDraw(_ context: CGContext) {
    }
    
    private func onScroll(event: UITouch, view: UIView) {
        let point = event.location(in: view)
        let pointX = point.x
        let pointY = point.y
        
        if isMoved || (readView?.isLongScreenShot() ?? false) {
            readView?.setTouchPoint(pointX, pointY, anim: false)
        }
        
        if !isMoved {
            let deltaX = Int(pointX - startX)
            let deltaY = Int(pointY - startY)
            let distance = deltaX * deltaX + deltaY * deltaY
            let slopSquare = readView?.pageSlopSquare2 ?? 0
            isMoved = distance > slopSquare
            if isMoved {
                readView?.setStartPoint(point.x, point.y, anim: false)
            }
        }
        
        if isMoved {
            isRunning = true
        }
    }
    
    override func onDestroy() {
        super.onDestroy()
    }
    
    override func abortAnim() {
        readView?.onScrollAnimStop()
        isStarted = false
        isMoved = false
        isRunning = false
        if !isScrollerFinished {
            readView?.isAbortAnim = true
            abortScrollerAnimation()
        } else {
            readView?.isAbortAnim = false
        }
    }
    
    override func nextPageByAnim(animationSpeed: Int) {
        if readView?.isAbortAnim == true {
            readView?.isAbortAnim = false
            return
        }
        if noAnim {
            curPage.scroll(calcNextPageOffset())
            return
        }
        readView?.setStartPoint(0, 0, anim: false)
        startScroll(startX: 0, startY: 0, dx: 0, dy: calcNextPageOffset(), animationSpeed: animationSpeed)
    }
    
    override func prevPageByAnim(animationSpeed: Int) {
        if readView?.isAbortAnim == true {
            readView?.isAbortAnim = false
            return
        }
        if noAnim {
            curPage.scroll(calcPrevPageOffset())
            return
        }
        readView?.setStartPoint(0, 0, anim: false)
        startScroll(startX: 0, startY: 0, dx: 0, dy: calcPrevPageOffset(), animationSpeed: animationSpeed)
    }
    
    private func calcNextPageOffset() -> Int {
        let visibleHeight = ChapterProvider.shared.visibleHeight
        guard let book = ReadBook.shared.book else {
            return -Int(visibleHeight)
        }
        
        if book.type == 2 {
            return -Int(visibleHeight)
        }
        
        guard let visiblePage = readView?.getCurVisiblePage() else {
            return -Int(visibleHeight)
        }
        
        if visiblePage.lines.isEmpty {
            return -Int(visibleHeight)
        }
        
        let lastLineTop = Int(visiblePage.lines.last?.lineTop ?? 0)
        let paddingTop = ChapterProvider.shared.paddingTop
        let offset = lastLineTop - Int(paddingTop)
        return -offset
    }
    
    private func calcPrevPageOffset() -> Int {
        let visibleHeight = ChapterProvider.shared.visibleHeight
        guard let book = ReadBook.shared.book else {
            return Int(visibleHeight)
        }
        
        if book.type == 2 {
            return Int(visibleHeight)
        }
        
        guard let visiblePage = readView?.getCurVisiblePage() else {
            return Int(visibleHeight)
        }
        
        if visiblePage.lines.isEmpty {
            return Int(visibleHeight)
        }
        
        let firstLineBottom = Int(visiblePage.lines.first?.lineBottom ?? 0)
        let paddingTop = ChapterProvider.shared.paddingTop
        let offset = Int(visibleHeight) - (firstLineBottom - Int(paddingTop))
        return offset
    }
}
