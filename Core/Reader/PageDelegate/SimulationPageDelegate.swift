import UIKit
import simd

/// 仿真翻页代理
/// 一比一移植自 Android Legado SimulationPageDelegate.kt (613行)
/// 原版路径: app/src/main/java/io/legado/app/ui/book/read/page/delegate/SimulationPageDelegate.kt
class SimulationPageDelegate: HorizontalPageDelegate {
    
    private var mTouchX: CGFloat = 0.1
    private var mTouchY: CGFloat = 0.1
    private var mCornerX: Int = 1
    private var mCornerY: Int = 1
    
    private let mPath0 = UIBezierPath()
    private let mPath1 = UIBezierPath()
    
    private let mBezierStart1 = CGPoint.zero
    private let mBezierControl1 = CGPoint.zero
    private let mBezierVertex1 = CGPoint.zero
    private var mBezierEnd1 = CGPoint.zero
    
    private let mBezierStart2 = CGPoint.zero
    private let mBezierControl2 = CGPoint.zero
    private let mBezierVertex2 = CGPoint.zero
    private var mBezierEnd2 = CGPoint.zero
    
    private var mMiddleX: CGFloat = 0
    private var mMiddleY: CGFloat = 0
    private var mDegrees: CGFloat = 0
    private var mTouchToCornerDis: CGFloat = 0
    
    private var mIsRtOrLb: Bool = false
    private var mMaxLength: CGFloat = 0
    
    private var curBitmap: UIImage?
    private var prevBitmap: UIImage?
    private var nextBitmap: UIImage?
    
    override init(readView: ReadViewProtocol) {
        super.init(readView: readView)
        mMaxLength = sqrt(viewWidth * viewWidth + viewHeight * viewHeight)
    }
    
    override func setBitmap() {
        switch mDirection {
        case .prev:
            prevBitmap = prevPage.screenshot()
            curBitmap = curPage.screenshot()
        case .next:
            nextBitmap = nextPage.screenshot()
            curBitmap = curPage.screenshot()
        case .none:
            break
        }
    }
    
    override func setViewSize(width: CGFloat, height: CGFloat) {
        super.setViewSize(width: width, height: height)
        mMaxLength = sqrt(viewWidth * viewWidth + viewHeight * viewHeight)
    }
    
    override func onTouch(event: UITouch, view: UIView) {
        super.onTouch(event: event, view: view)
        
        let point = event.location(in: view)
        
        switch event.phase {
        case .began:
            calcCornerXY(x: point.x, y: point.y)
        case .moved:
            if (startY > viewHeight / 3 && startY < viewHeight * 2 / 3) || mDirection == .prev {
                readView?.touchY = viewHeight
            }
            if startY > viewHeight / 3 && startY < viewHeight / 2 && mDirection == .next {
                readView?.touchY = 1
            }
        default:
            break
        }
    }
    
    override func setDirection(_ direction: PageDirection) {
        super.setDirection(direction)
        
        switch direction {
        case .prev:
            if startX > viewWidth / 2 {
                calcCornerXY(x: startX, y: viewHeight)
            } else {
                calcCornerXY(x: viewWidth - startX, y: viewHeight)
            }
        case .next:
            if viewWidth / 2 > startX {
                calcCornerXY(x: viewWidth - startX, y: startY)
            }
        case .none:
            break
        }
    }
    
    override func onAnimStart(_ animationSpeed: Int) {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        
        if isCancel {
            dx = mCornerX > 0 && mDirection == .next ? (viewWidth - touchX) : -touchX
            if mDirection != .next {
                dx = -(viewWidth + touchX)
            }
            dy = mCornerY > 0 ? (viewHeight - touchY) : -touchY
        } else {
            dx = mCornerX > 0 && mDirection == .next ? -(viewWidth + touchX) : viewWidth - touchX
            dy = mCornerY > 0 ? (viewHeight - touchY) : (1 - touchY)
        }
        
        startScroll(startX: Int(touchX), startY: Int(touchY), dx: Int(dx), dy: Int(dy), animationSpeed: animationSpeed)
    }
    
    override func onAnimStop() {
        if !isCancel {
            readView?.fillPage(mDirection)
        }
    }
    
    override func onDraw(_ context: CGContext) {
        if !isRunning { return }
        
        switch mDirection {
        case .next:
            calcPoints()
            drawCurrentPageArea(context: context, bitmap: curBitmap)
            drawNextPageAreaAndShadow(context: context, bitmap: nextBitmap)
            drawCurrentPageShadow(context: context)
            drawCurrentBackArea(context: context, bitmap: curBitmap)
        case .prev:
            calcPoints()
            drawCurrentPageArea(context: context, bitmap: prevBitmap)
            drawNextPageAreaAndShadow(context: context, bitmap: curBitmap)
            drawCurrentPageShadow(context: context)
            drawCurrentBackArea(context: context, bitmap: prevBitmap)
        case .none:
            return
        }
    }
    
    private func calcCornerXY(x: CGFloat, y: CGFloat) {
        mCornerX = x <= viewWidth / 2 ? 0 : Int(viewWidth)
        mCornerY = y <= viewHeight / 2 ? 0 : Int(viewHeight)
        mIsRtOrLb = (mCornerX == 0 && mCornerY == Int(viewHeight)) || (mCornerY == 0 && mCornerX == Int(viewWidth))
    }
    
    private func calcPoints() {
        mTouchX = touchX
        mTouchY = touchY
        
        mMiddleX = (mTouchX + CGFloat(mCornerX)) / 2
        mMiddleY = (mTouchY + CGFloat(mCornerY)) / 2
        
        var bezierControl1 = CGPoint.zero
        var bezierControl2 = CGPoint.zero
        var bezierStart1 = CGPoint.zero
        var bezierStart2 = CGPoint.zero
        var bezierEnd1 = CGPoint.zero
        var bezierEnd2 = CGPoint.zero
        
        bezierControl1.x = mMiddleX - (CGFloat(mCornerY) - mMiddleY) * (CGFloat(mCornerY) - mMiddleY) / (CGFloat(mCornerX) - mMiddleX)
        bezierControl1.y = CGFloat(mCornerY)
        bezierControl2.x = CGFloat(mCornerX)
        
        let f4 = CGFloat(mCornerY) - mMiddleY
        if f4 == 0 {
            bezierControl2.y = mMiddleY - (CGFloat(mCornerX) - mMiddleX) * (CGFloat(mCornerX) - mMiddleX) / 0.1
        } else {
            bezierControl2.y = mMiddleY - (CGFloat(mCornerX) - mMiddleX) * (CGFloat(mCornerX) - mMiddleX) / f4
        }
        
        bezierStart1.x = bezierControl1.x - (CGFloat(mCornerX) - bezierControl1.x) / 2
        bezierStart1.y = CGFloat(mCornerY)
        
        if mTouchX > 0 && mTouchX < viewWidth {
            if bezierStart1.x < 0 || bezierStart1.x > viewWidth {
                if bezierStart1.x < 0 {
                    bezierStart1.x = viewWidth - bezierStart1.x
                }
                
                let f1 = abs(CGFloat(mCornerX) - mTouchX)
                let f2 = viewWidth * f1 / bezierStart1.x
                mTouchX = abs(CGFloat(mCornerX) - f2)
                
                let f3 = abs(CGFloat(mCornerX) - mTouchX) * abs(CGFloat(mCornerY) - mTouchY) / f1
                mTouchY = abs(CGFloat(mCornerY) - f3)
                
                mMiddleX = (mTouchX + CGFloat(mCornerX)) / 2
                mMiddleY = (mTouchY + CGFloat(mCornerY)) / 2
                
                bezierControl1.x = mMiddleX - (CGFloat(mCornerY) - mMiddleY) * (CGFloat(mCornerY) - mMiddleY) / (CGFloat(mCornerX) - mMiddleX)
                bezierControl1.y = CGFloat(mCornerY)
                bezierControl2.x = CGFloat(mCornerX)
                
                let f5 = CGFloat(mCornerY) - mMiddleY
                if f5 == 0 {
                    bezierControl2.y = mMiddleY - (CGFloat(mCornerX) - mMiddleX) * (CGFloat(mCornerX) - mMiddleX) / 0.1
                } else {
                    bezierControl2.y = mMiddleY - (CGFloat(mCornerX) - mMiddleX) * (CGFloat(mCornerX) - mMiddleX) / f5
                }
                
                bezierStart1.x = bezierControl1.x - (CGFloat(mCornerX) - bezierControl1.x) / 2
            }
        }
        
        bezierStart2.x = CGFloat(mCornerX)
        bezierStart2.y = bezierControl2.y - (CGFloat(mCornerY) - bezierControl2.y) / 2
        
        mTouchToCornerDis = sqrt((mTouchX - CGFloat(mCornerX)) * (mTouchX - CGFloat(mCornerX)) + (mTouchY - CGFloat(mCornerY)) * (mTouchY - CGFloat(mCornerY)))
        
        bezierEnd1 = getCross(
            P1: CGPoint(x: mTouchX, y: mTouchY),
            P2: bezierControl1,
            P3: bezierStart1,
            P4: bezierStart2
        )
        bezierEnd2 = getCross(
            P1: CGPoint(x: mTouchX, y: mTouchY),
            P2: bezierControl2,
            P3: bezierStart1,
            P4: bezierStart2
        )
        
        let bezierVertex1 = CGPoint(
            x: (bezierStart1.x + 2 * bezierControl1.x + bezierEnd1.x) / 4,
            y: (2 * bezierControl1.y + bezierStart1.y + bezierEnd1.y) / 4
        )
        let bezierVertex2 = CGPoint(
            x: (bezierStart2.x + 2 * bezierControl2.x + bezierEnd2.x) / 4,
            y: (2 * bezierControl2.y + bezierStart2.y + bezierEnd2.y) / 4
        )
        
        mBezierStart1.set(bezierStart1)
        mBezierControl1.set(bezierControl1)
        mBezierVertex1.set(bezierVertex1)
        mBezierEnd1.set(bezierEnd1)
        mBezierStart2.set(bezierStart2)
        mBezierControl2.set(bezierControl2)
        mBezierVertex2.set(bezierVertex2)
        mBezierEnd2.set(bezierEnd2)
    }
    
    private func getCross(P1: CGPoint, P2: CGPoint, P3: CGPoint, P4: CGPoint) -> CGPoint {
        let a1 = (P2.y - P1.y) / (P2.x - P1.x)
        let b1 = (P1.x * P2.y - P2.x * P1.y) / (P1.x - P2.x)
        let a2 = (P4.y - P3.y) / (P4.x - P3.x)
        let b2 = (P3.x * P4.y - P4.x * P3.y) / (P3.x - P4.x)
        
        let x = (b2 - b1) / (a1 - a2)
        let y = a1 * x + b1
        
        return CGPoint(x: x, y: y)
    }
    
    private func drawCurrentPageArea(context: CGContext, bitmap: UIImage?) {
        guard let bitmap = bitmap else { return }
        
        mPath0.removeAllPoints()
        mPath0.move(to: mBezierStart1)
        mPath0.addQuadCurve(to: mBezierEnd1, controlPoint: mBezierControl1)
        mPath0.addLine(to: CGPoint(x: mTouchX, y: mTouchY))
        mPath0.addLine(to: mBezierEnd2)
        mPath0.addQuadCurve(to: mBezierStart2, controlPoint: mBezierControl2)
        mPath0.addLine(to: CGPoint(x: CGFloat(mCornerX), y: CGFloat(mCornerY)))
        mPath0.close()
        
        context.saveGState()
        context.addPath(mPath0.cgPath)
        context.clip(using: .evenOddRule)
        bitmap.draw(in: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        context.restoreGState()
    }
    
    private func drawNextPageAreaAndShadow(context: CGContext, bitmap: UIImage?) {
        guard let bitmap = bitmap else { return }
        
        mPath1.removeAllPoints()
        mPath1.move(to: mBezierStart1)
        mPath1.addLine(to: mBezierVertex1)
        mPath1.addLine(to: mBezierVertex2)
        mPath1.addLine(to: mBezierStart2)
        mPath1.addLine(to: CGPoint(x: CGFloat(mCornerX), y: CGFloat(mCornerY)))
        mPath1.close()
        
        mDegrees = atan2(mBezierControl1.x - CGFloat(mCornerX), mBezierControl2.y - CGFloat(mCornerY)) * 180 / .pi
        
        let leftX: CGFloat
        let rightX: CGFloat
        
        if mIsRtOrLb {
            leftX = mBezierStart1.x
            rightX = mBezierStart1.x + mTouchToCornerDis / 4
        } else {
            leftX = mBezierStart1.x - mTouchToCornerDis / 4
            rightX = mBezierStart1.x
        }
        
        context.saveGState()
        context.addPath(mPath0.cgPath)
        context.clip()
        context.addPath(mPath1.cgPath)
        context.clip()
        
        bitmap.draw(in: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        
        context.rotate(by: mDegrees * .pi / 180)
        
        let colors: [CGColor] = [
            UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1).cgColor,
            UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 0).cgColor
        ]
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: leftX, y: mBezierStart1.y), end: CGPoint(x: rightX, y: mBezierStart1.y + mMaxLength), options: [])
        }
        
        context.restoreGState()
    }
    
    private func drawCurrentPageShadow(context: CGContext) {
        let degree: Double
        if mIsRtOrLb {
            degree = .pi / 4 - atan2(mBezierControl1.y - mTouchY, mTouchX - mBezierControl1.x)
        } else {
            degree = .pi / 4 - atan2(mTouchY - mBezierControl1.y, mTouchX - mBezierControl1.x)
        }
        
        let d1 = CGFloat(25) * 1.414 * CGFloat(cos(degree))
        let d2 = CGFloat(25) * 1.414 * CGFloat(sin(degree))
        let x = mTouchX + d1
        let y: CGFloat = mIsRtOrLb ? mTouchY + d2 : mTouchY - d2
        
        mPath1.removeAllPoints()
        mPath1.move(to: CGPoint(x: x, y: y))
        mPath1.addLine(to: CGPoint(x: mTouchX, y: mTouchY))
        mPath1.addLine(to: mBezierControl1)
        mPath1.addLine(to: mBezierStart1)
        mPath1.close()
        
        context.saveGState()
        context.addPath(mPath0.cgPath)
        context.clip(using: .evenOddRule)
        context.addPath(mPath1.cgPath)
        context.clip()
        
        let leftX: CGFloat = mIsRtOrLb ? mBezierControl1.x : mBezierControl1.x - 25
        let rightX: CGFloat = mIsRtOrLb ? mBezierControl1.x + 25 : mBezierControl1.x + 1
        
        let colors: [CGColor] = [
            UIColor(white: 0.9, alpha: 0.5).cgColor,
            UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 0).cgColor
        ]
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: leftX, y: mBezierControl1.y - mMaxLength), end: CGPoint(x: rightX, y: mBezierControl1.y), options: [])
        }
        
        context.restoreGState()
    }
    
    private func drawCurrentBackArea(context: CGContext, bitmap: UIImage?) {
        guard let bitmap = bitmap else { return }
        
        let i = Int((mBezierStart1.x + mBezierControl1.x) / 2)
        let f1 = abs(CGFloat(i) - mBezierControl1.x)
        let i1 = Int((mBezierStart2.y + mBezierControl2.y) / 2)
        let f2 = abs(CGFloat(i1) - mBezierControl2.y)
        let f3 = min(f1, f2)
        
        mPath1.removeAllPoints()
        mPath1.move(to: mBezierVertex2)
        mPath1.addLine(to: mBezierVertex1)
        mPath1.addLine(to: mBezierEnd1)
        mPath1.addLine(to: CGPoint(x: mTouchX, y: mTouchY))
        mPath1.addLine(to: mBezierEnd2)
        mPath1.close()
        
        let left: Int
        let right: Int
        
        if mIsRtOrLb {
            left = Int(mBezierStart1.x - 1)
            right = Int(mBezierStart1.x + f3 + 1)
        } else {
            left = Int(mBezierStart1.x - f3 - 1)
            right = Int(mBezierStart1.x + 1)
        }
        
        context.saveGState()
        context.addPath(mPath0.cgPath)
        context.clip()
        context.addPath(mPath1.cgPath)
        context.clip()
        
        context.setFillColor(UIColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        
        bitmap.draw(in: CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        
        context.restoreGState()
    }
}

private extension CGPoint {
    mutating func set(_ other: CGPoint) {
        self.x = other.x
        self.y = other.y
    }
}