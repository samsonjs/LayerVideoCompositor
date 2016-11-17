//
//  ViewController.swift
//  LayerVideoCompositor
//
//  Created by Sami Samhuri on 2016-11-16.
//  Copyright © 2016 Guru Logic. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet private var label: UILabel?
    @IBOutlet private var indicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        let path = Bundle.main.path(forResource: "video.mov", ofType: nil)
        let url = URL(fileURLWithPath: path!)
        let start = Date()
        overlayTextOnVideo(videoURL: url) { maybeURL in
            DispatchQueue.main.async {
                self.indicator?.stopAnimating()
                guard let url = maybeURL else {
                    self.label?.text = "Error. See console for details."
                    return
                }

                let end = Date()
                let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
                print("Exported in \(duration) seconds.")

                self.label?.text = "Done. Video is in the Documents folder which you can access with iTunes, or an app like iMazing or iExplorer."
                let player = AVPlayer(url: url)
                let layer = AVPlayerLayer(player: player)
                let y = 16 + (self.label?.frame.maxY ?? 0)
                let width = self.view.bounds.width
                layer.frame = CGRect(x: 0, y: y, width: width, height: 9 / 16 * width)
                self.view.layer.addSublayer(layer)
                player.play()
            }
        }
    }

    private func newOverlayLayer(size: CGSize, text: String) -> CALayer {
        let margin: CGFloat = 16
        let textHeight: CGFloat = 120
        let textLayer = CATextLayer()
        textLayer.alignmentMode = kCAAlignmentCenter
        textLayer.fontSize = 96
        textLayer.frame = CGRect(x: margin, y: margin, width: size.width - 2 * margin, height: textHeight)
        textLayer.string = text
        textLayer.foregroundColor = UIColor(white: 1, alpha: 0.7).cgColor
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 0.8

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)
        overlayLayer.addSublayer(textLayer)

        return overlayLayer
    }

    private func overlayTextOnVideo(videoURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        let videoTracks = asset.tracks(withMediaType: AVMediaTypeVideo)
        guard let sourceVideoTrack = videoTracks.first else {
            print("error: asset has no video tracks")
            completion(nil)
            return
        }
        let timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
        let videoComposition = AVMutableVideoComposition(propertiesOf: asset)
        videoComposition.customVideoCompositorClass = LayerVideoCompositor.self
        let overlayLayer = newOverlayLayer(size: sourceVideoTrack.naturalSize, text: "Layeriffic!")
        let instruction = LayerVideoCompositionInstruction(track: sourceVideoTrack, timeRange: timeRange, overlayLayer: overlayLayer, transform: sourceVideoTrack.preferredTransform, targetSize: sourceVideoTrack.naturalSize)
        videoComposition.instructions = [instruction]

        let documentDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let path = documentDir.appending("/export.mov")
        let outputURL = URL(fileURLWithPath: path)
        _ = try? FileManager.default.removeItem(at: outputURL)

        guard let presetName = AVAssetExportSession.exportPresets(compatibleWith: asset).first,
            let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
                print("failed to create asset export session")
                completion(nil)
                return
        }
        exportSession.videoComposition = videoComposition
        exportSession.outputFileType = AVFileTypeMPEG4
        exportSession.outputURL = outputURL
        exportSession.exportAsynchronously {
            guard exportSession.status == .completed else {
                print("export failed: \(exportSession.error)")
                completion(nil)
                return
            }
            completion(outputURL)
        }
    }
}

