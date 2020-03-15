import Foundation
import Alloy
import CoreGraphics

final class TextMesh: Mesh {

    var vertices: [Vertex] = []
    var indices: [UInt16] = []

    init(string: String,
         rect: CGRect,
         fontAtlas: FontAtlas,
         fontSize: CGFloat,
         device: MTLDevice) throws {
        super.init()
        
        let font = fontAtlas.parentFont.withSize(fontSize)
        let attributedString = NSAttributedString(string: string,
                                                  attributes: [NSAttributedString.Key.font : font])
        let stringRange = CFRangeMake(0, attributedString.length)
        let rectPath = CGPath(rect: rect,
                              transform: nil)

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frame = CTFramesetterCreateFrame(framesetter, stringRange, rectPath, nil)

        var frameGlyphCount: CFIndex = 0
        let lines = CTFrameGetLines(frame) as! [CTLine]
        lines.forEach { frameGlyphCount += CTLineGetGlyphCount($0) }

        let vertexCount = frameGlyphCount * 4
        let indexCount = frameGlyphCount * 6

        var vertices = [Vertex](repeating: .init(), count: vertexCount)
        var indices = [UInt16](repeating: .zero, count: indexCount)

        var v = Int()
        var i = Int()

        self.enumerateGlyphs(in: frame) { (glyph, glyphIndex, glyphBounds) in
            guard glyph < fontAtlas.glyphDescriptors.count
            else { return }

            let glyphInfo = fontAtlas.glyphDescriptors[.init(glyph)]
            let minX: Float = .init(glyphBounds.minX)
            let maxX: Float = .init(glyphBounds.maxX)
            let minY: Float = .init(glyphBounds.minY)
            let maxY: Float = .init(glyphBounds.maxY)

            let minS: Float = .init(glyphInfo.topLeftTexCoord.x)
            let maxS: Float = .init(glyphInfo.bottomRightTexCoord.x)
            let minT: Float = .init(glyphInfo.topLeftTexCoord.y)
            let maxT: Float = .init(glyphInfo.bottomRightTexCoord.y)

            vertices[v] = .init(position: .init(minX, maxY, 0, 1),
                                texCoords: .init(minS, maxT))
            v += 1
            vertices[v] = .init(position: .init(minX, minY, 0, 1),
                                texCoords: .init(minS, minT))
            v += 1
            vertices[v] = .init(position: .init(maxX, minY, 0, 1),
                                texCoords: .init(maxS, minT))
            v += 1
            vertices[v] = .init(position: .init(maxX, maxY, 0, 1),
                                texCoords: .init(maxS, maxT))
            v += 1

            indices[i] = .init(glyphIndex) * 4
            i += 1
            indices[i] = .init(glyphIndex) * 4 + 1
            i += 1
            indices[i] = .init(glyphIndex) * 4 + 2
            i += 1
            indices[i] = .init(glyphIndex) * 4 + 2
            i += 1
            indices[i] = .init(glyphIndex) * 4 + 3
            i += 1
            indices[i] = .init(glyphIndex) * 4
            i += 1
        }

        self.vertexBuffer = try device.buffer(with: vertices,
                                              options: .storageModeShared)
        self.indexBuffer = try device.buffer(with: indices,
                                             options: .storageModeShared)

        self.vertices = vertices
        self.indices = indices
    }

    func enumerateGlyphs(in frame: CTFrame,
                         block: (_ glyph: CGGlyph, _ glyphIndex: Int, _ glyphBounds: CGRect) -> Void) {
        let entire = CFRangeMake(0, 0)

        let framePath = CTFrameGetPath(frame)
        let frameBoundingRect = framePath.boundingBox

        let lines = CTFrameGetLines(frame) as! [CTLine]

        var lineOriginBuffer = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, entire, &lineOriginBuffer)

        var glyphIndexInFrame = CFIndex()

        UIGraphicsBeginImageContext(.init(width: 1, height: 1))
        let context = UIGraphicsGetCurrentContext()

        lines.enumerated().forEach { lineIndex, line in
            let lineOrigin = lineOriginBuffer[lineIndex]

            let runs = CTLineGetGlyphRuns(line) as! [CTRun]

            runs.enumerated().forEach { runIndex, run in

                let glyphCount = CTRunGetGlyphCount(run)

                var glyphBuffer = [CGGlyph](repeating: .init(), count: glyphCount)
                CTRunGetGlyphs(run, entire, &glyphBuffer)

                var positionBuffer = [CGPoint](repeating: .zero, count: glyphCount)
                CTRunGetPositions(run, entire, &positionBuffer)

                for glyphIndex in 0 ..< glyphCount {
                    let glyph = glyphBuffer[glyphIndex]
                    let glyphOrigin = positionBuffer[glyphIndex]
                    var glyphRect = CTRunGetImageBounds(run, context, CFRangeMake(glyphIndex, 1))
                    let boundsTransX = frameBoundingRect.origin.x + lineOrigin.x
                    let boundsTransY = frameBoundingRect.height + frameBoundingRect.origin.y - lineOrigin.y + glyphOrigin.y
                    let pathTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: boundsTransX, ty: boundsTransY)
                    glyphRect = glyphRect.applying(pathTransform)

                    block(glyph, glyphIndexInFrame, glyphRect);

                    glyphIndexInFrame += 1
                }
            }
        }

        UIGraphicsEndImageContext()
    }
}
