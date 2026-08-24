import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// High-performance native streaming parser for Home Assistant MJPEG camera streams (`multipart/x-mixed-replace`).
@Observable
@MainActor
public final class HAMJPEGStreamer: @unchecked Sendable {
    public var currentFrameData: Data? = nil
    #if canImport(UIKit)
    public var currentFrame: UIImage? = nil
    #endif
    public var isStreaming: Bool = false
    public var isConnecting: Bool = false
    public var errorMessage: String? = nil
    
    private var session: URLSession? = nil
    private var dataTask: URLSessionDataTask? = nil
    private var receiver: MJPEGDataReceiver? = nil
    private var buffer = Data()
    private let soi = Data([0xFF, 0xD8]) // JPEG Start of Image
    private let eoi = Data([0xFF, 0xD9]) // JPEG End of Image
    
    public init() {}
    
    public func startStream(url: URL, token: String? = nil) {
        stopStream()
        isConnecting = true
        isStreaming = false
        errorMessage = nil
        buffer.removeAll(keepingCapacity: true)
        
        print("[HAMJPEG] Connecting to: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let receiver = MJPEGDataReceiver()
        self.receiver = receiver
        
        receiver.onResponse = { [weak self] response in
            Task { @MainActor in
                print("[HAMJPEG] Response code: \(response.statusCode), Content-Type: \(response.value(forHTTPHeaderField: "Content-Type") ?? "none")")
                if !(200...299).contains(response.statusCode) {
                    self?.handleError("Server returned HTTP \(response.statusCode)")
                }
            }
        }
        
        receiver.onData = { [weak self] chunk in
            Task { @MainActor in
                self?.processChunk(chunk)
            }
        }
        
        receiver.onError = { [weak self] error in
            Task { @MainActor in
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    print("[HAMJPEG] Stream error: \(error.localizedDescription)")
                    self?.handleError(error.localizedDescription)
                }
            }
        }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24 hours
        
        let session = URLSession(configuration: config, delegate: receiver, delegateQueue: nil)
        self.session = session
        
        let task = session.dataTask(with: request)
        self.dataTask = task
        task.resume()
    }
    
    @MainActor
    private func processChunk(_ chunk: Data) {
        buffer.append(chunk)
        
        // Scan for complete JPEG frames
        while let endIndex = buffer.range(of: eoi)?.upperBound {
            if let startIndex = buffer.range(of: soi)?.lowerBound, startIndex < endIndex {
                let jpegData = buffer.subdata(in: startIndex..<endIndex)
                handleFrame(jpegData)
                buffer.removeSubrange(0..<endIndex)
            } else {
                buffer.removeSubrange(0..<endIndex)
            }
        }
        
        // Prevent buffer from growing unbounded if stream is non-JPEG
        if buffer.count > 5 * 1024 * 1024 {
            buffer.removeAll(keepingCapacity: true)
        }
    }
    
    @MainActor
    private func handleFrame(_ data: Data) {
        self.currentFrameData = data
        #if canImport(UIKit)
        if let img = UIImage(data: data) {
            self.currentFrame = img
        }
        #endif
        self.isStreaming = true
        self.isConnecting = false
    }
    
    @MainActor
    private func handleError(_ msg: String) {
        self.errorMessage = msg
        self.isConnecting = false
        self.isStreaming = false
    }
    
    public func stopStream() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        receiver = nil
        buffer.removeAll(keepingCapacity: true)
        isStreaming = false
        isConnecting = false
    }
}

// MARK: - Delegate

final class MJPEGDataReceiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    var onResponse: ((HTTPURLResponse) -> Void)?
    var onData: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            onResponse?(http)
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData?(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onError?(error)
        }
    }
}
