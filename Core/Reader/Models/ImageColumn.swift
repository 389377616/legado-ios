import UIKit

class ImageColumn: BaseColumn {
    var start: Float
    var end: Float
    var src: String
    var textLine: TextLine = TextLine.empty
    
    init(start: Float, end: Float, src: String) {
        self.start = start
        self.end = end
        self.src = src
    }
    
    func draw(in view: ContentTextView, context: CGContext) {
        let height = CGFloat(textLine.height)
        let width = CGFloat(end - start)
        
        var image: UIImage?
        if let cachedImage = ImageCache.shared.getImage(for: src) {
            image = cachedImage
        }
        
        guard let img = image else {
            drawPlaceholder(in: context, width: width, height: height)
            return
        }
        
        let drawRect: CGRect
        if textLine.isImage {
            drawRect = CGRect(x: CGFloat(start), y: 0, width: width, height: height)
        } else {
            let h = width / img.size.width * img.size.height
            let div = (height - h) / 2
            drawRect = CGRect(x: CGFloat(start), y: div, width: width, height: h)
        }
        
        context.saveGState()
        context.interpolationQuality = .high
        img.draw(in: drawRect)
        context.restoreGState()
    }
    
    private func drawPlaceholder(in context: CGContext, width: CGFloat, height: CGFloat) {
        context.setFillColor(UIColor.systemGray4.cgColor)
        context.fill(CGRect(x: CGFloat(start), y: 0, width: width, height: height))
        
        context.setFillColor(UIColor.systemGray2.cgColor)
        let iconRect = CGRect(x: CGFloat(start) + width/2 - 20, y: height/2 - 20, width: 40, height: 40)
        let path = UIBezierPath(ovalIn: iconRect)
        context.addPath(path.cgPath)
        context.fillPath()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
    }
    
    func getImage(for src: String) -> UIImage? {
        return cache.object(forKey: src as NSString)
    }
    
    func setImage(_ image: UIImage, for src: String) {
        cache.setObject(image, forKey: src as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}