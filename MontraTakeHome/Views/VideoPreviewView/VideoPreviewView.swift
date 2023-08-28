//
//  VideoPreviewView.swift
//  MontraTakeHome
//
//  Created by Seun Olalekan on 2023-08-26.
//

import Foundation
import SwiftUI
import AVFoundation

struct VideoPreviewView: NSViewRepresentable{
    
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> some NSView {
        let view: NSView = .init()
        previewLayer.frame = view.bounds
        view.layer = previewLayer
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        previewLayer.frame = nsView.bounds
    }
    
}
