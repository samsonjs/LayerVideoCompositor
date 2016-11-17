//
//  LayerVideoCompositor.swift
//  LayerVideoCompositor
//
//  Created by Sami Samhuri on 2016-09-05.
//  Copyright © 2016 Guru Logic Inc. All rights reserved.
//

import Foundation
import Dispatch
import AVFoundation
import CoreImage

enum LayerVideoCompositingError: Error {
    case invalidRequest
    case sourceFrameBuffer
    case overlayTextLayer
}

final class LayerVideoCompositor: NSObject, AVVideoCompositing {
    private let queue = DispatchQueue(label: "ca.gurulogic.layer-video-compositor.render", qos: .default)
    private var renderContext: AVVideoCompositionRenderContext = AVVideoCompositionRenderContext()
    private var cancelled: Bool = false
    private let ciContext: CIContext = {
        if let eaglContext = EAGLContext(api: .openGLES3) ?? EAGLContext(api: .openGLES2) {
            return CIContext(eaglContext: eaglContext)
        }
        return CIContext()
    }()
    private var cachedOverlaySnapshot: CGImage?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    var supportsWideColorSourceFrames: Bool {
        return false
    }

    private static let pixelFormat = kCVPixelFormatType_32BGRA

    let sourcePixelBufferAttributes: [String : Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: LayerVideoCompositor.pixelFormat),
        kCVPixelBufferOpenGLESCompatibilityKey as String : NSNumber(value: true),
    ]

    let requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: LayerVideoCompositor.pixelFormat),
        kCVPixelBufferOpenGLESCompatibilityKey as String : NSNumber(value: true),
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContext = newRenderContext
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async {
            guard !self.cancelled else {
                request.finishCancelledRequest()
                return
            }

            do {
                let renderedBuffer = try self.renderFrame(forRequest: request)
                request.finish(withComposedVideoFrame: renderedBuffer)
            }
            catch {
                request.finish(with: error)
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        cancelled = true
        queue.async(flags: .barrier) {
            self.cancelled = false
        }
    }

    private func overlaySnapshot(layer: CALayer) throws -> CGImage {
        if let cachedSnapshot = cachedOverlaySnapshot {
            return cachedSnapshot
        }
        layer.isGeometryFlipped = true
        let size = layer.bounds.size
        let w = Int(size.width)
        let h = Int(size.height)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 4 * w, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw NSError() }
        layer.render(in: context)
        guard let snapshot = context.makeImage() else { throw NSError() }
        cachedOverlaySnapshot = snapshot
        return snapshot
    }

    private func renderFrame(forRequest request: AVAsynchronousVideoCompositionRequest) throws -> CVPixelBuffer {
        return try autoreleasepool {
            guard let instruction = request.videoCompositionInstruction as? LayerVideoCompositionInstruction else {
                throw LayerVideoCompositingError.invalidRequest
            }
            guard let videoFrameBuffer = request.sourceFrame(byTrackID: instruction.videoTrackID) else {
                // Try to be resilient in the face of errors. If we can't even generate a blank frame then fail.
                if let blankBuffer = renderContext.newPixelBuffer() {
                    return blankBuffer
                }
                else {
                    throw LayerVideoCompositingError.sourceFrameBuffer
                }
            }
            let frameImage = CIImage(cvPixelBuffer: videoFrameBuffer).applying(instruction.transform)
            guard let layer = instruction.overlayLayer, let overlayImage = try? CIImage(cgImage: overlaySnapshot(layer: layer)),
                let composeFilter = CIFilter(name: "CISourceAtopCompositing") else {
                    throw LayerVideoCompositingError.overlayTextLayer
            }
            composeFilter.setValue(frameImage, forKey: kCIInputBackgroundImageKey)
            composeFilter.setValue(overlayImage, forKey: kCIInputImageKey)
            guard let outputImage = composeFilter.outputImage,
                let renderedBuffer = renderContext.newPixelBuffer() else {
                throw LayerVideoCompositingError.overlayTextLayer
            }
            ciContext.render(outputImage, to: renderedBuffer, bounds: outputImage.extent, colorSpace: self.colorSpace)
            return renderedBuffer
        }
    }
}

