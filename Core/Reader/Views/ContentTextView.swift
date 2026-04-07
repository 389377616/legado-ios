import UIKit

class ContentTextView: UIView {
    
    var textPage: TextPage?
    var selectedPaint: UIColor = .systemBlue.withAlphaComponent(0.3)
    var imagePaint: CGContext?
    
    private var displayLink: CADisplayLink?
    private var needsDisplay = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let textPage = textPage else { return }
        
        context.saveGState()
        
        textPage.draw(in: self, context: context, relativeOffset: 0)
        
        context.restoreGState()
    }
    
    func setPage(_ page: TextPage?) {
        textPage = page
        setNeedsDisplay()
    }
    
    func invalidate() {
        setNeedsDisplay()
    }
}