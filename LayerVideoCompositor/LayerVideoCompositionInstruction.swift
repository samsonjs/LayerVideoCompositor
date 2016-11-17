//
//  LayerVideoCompositionInstruction.swift
//  LayerVideoCompositor
//
//  Created by Sami Samhuri on 2016-09-05.
//  Copyright © 2016 Guru Logic Inc. All rights reserved.
//

import Foundation
import AVFoundation

final class LayerVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    // Fixed
    let enablePostProcessing: Bool = true
    let containsTweening: Bool = false
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    // Variable
    let timeRange: CMTimeRange
    let requiredSourceTrackIDs: [NSValue]?
    let videoTrackID: CMPersistentTrackID
    let targetSize: CGSize
    let transform: CGAffineTransform
    let overlayLayer: CALayer?

    init(track: AVAssetTrack, timeRange: CMTimeRange, overlayLayer: CALayer?, transform: CGAffineTransform, targetSize: CGSize) {
        assert(overlayLayer == nil || overlayLayer!.bounds.size == targetSize)
        self.requiredSourceTrackIDs = [NSNumber(value: track.trackID)]
        self.timeRange = timeRange
        self.videoTrackID = track.trackID
        self.transform = transform
        self.targetSize = targetSize
        self.overlayLayer = overlayLayer
        super.init()
    }
}
