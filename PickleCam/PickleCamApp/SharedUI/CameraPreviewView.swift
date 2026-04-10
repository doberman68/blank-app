import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around AVCaptureVideoPreviewLayer.
/// Pass the live AVCaptureSession and the layer fills its bounds automatically.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> _PreviewView {
        let view = _PreviewView()
        view.previewLayer.session      = session
        view.previewLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ uiView: _PreviewView, context: Context) {
        uiView.previewLayer.videoGravity = gravity
    }

    // Private UIView subclass that vends AVCaptureVideoPreviewLayer as its backing layer.
    final class _PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
