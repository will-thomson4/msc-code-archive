//
//  DepthStream.swift
//  Capture
//
//  Created by William Thomson on 03/07/2022.
//

import AVFoundation
import Foundation
import Compression

// Credit for majority of this code goes to mantoone for his work on depth streaming
// see https://github.com/mantoone/DepthCapture

class DepthStream {
    let kErrorDomain = "DepthCapture"
    
    let maxNumberOfFrame = 250
    lazy var bufferSize = 640 * 480 * 2 * maxNumberOfFrame
    
    var dstBuffer: UnsafeMutablePointer<UInt8>?
    var frameCount: Int64 = 0
    var outputURL: URL?
    var compresserPtr: UnsafeMutablePointer<compression_stream>?
    var file: FileHandle?
    
    //Queue for processing depth data
    var processingQueue = DispatchQueue(label: "compression",
                                    qos: .userInteractive)
    
    func reset() {
        frameCount = 0
        outputURL = nil
        if self.compresserPtr != nil {
            compression_stream_destroy(self.compresserPtr!)
            self.compresserPtr = nil
        }
        if self.file != nil {
            self.file!.closeFile()
            self.file = nil
        }
    }
    
    
    func configureSession() {
        reset()
        // Create the output zip file, remove old one if exists
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        self.outputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("Depth"))
        FileManager.default.createFile(atPath: self.outputURL!.path, contents: nil, attributes: nil)
        
        self.file = FileHandle(forUpdatingAtPath: self.outputURL!.path)
        if self.file == nil {
            NSLog("Cannot create file at: \(self.outputURL!.path)")
            return
        }
        
        // Init the compression object
        compresserPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        compression_stream_init(compresserPtr!, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB)
        dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        compresserPtr!.pointee.dst_ptr = dstBuffer!
        compresserPtr!.pointee.dst_size = bufferSize
    }
    
    
    func flush() {
        let nBytes = bufferSize - compresserPtr!.pointee.dst_size
        let data = Data(bytesNoCopy: dstBuffer!, count: nBytes, deallocator: .none)
        self.file?.write(data)
    }
    
    
    func addPixelBuffers(pixelBuffer: CVPixelBuffer, callback: @escaping ()->Void) {
        processingQueue.async {
            //Have maxed out or frame count so need to flush buffer and reset frame count
            if self.frameCount >= self.maxNumberOfFrame {
                print("Attempting to flush")
                self.flush()
                
                self.frameCount = 0
                //callback()
                return
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            let add : UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(pixelBuffer)!
            
            self.compresserPtr!.pointee.src_ptr = UnsafePointer<UInt8>(add.assumingMemoryBound(to: UInt8.self))
            let height = CVPixelBufferGetHeight(pixelBuffer)
            self.compresserPtr!.pointee.src_size = CVPixelBufferGetBytesPerRow(pixelBuffer) * height
            
            let flags = Int32(0)
            let compression_status = compression_stream_process(self.compresserPtr!, flags)
            
            if compression_status != COMPRESSION_STATUS_OK {
                NSLog("Buffer compression retured: \(compression_status)")
                return
            }
            if self.compresserPtr!.pointee.src_size != 0 {
                NSLog("Compression lib didn't eat all data: \(compression_status)")
                return
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

            self.frameCount += 1
            print("handled \(self.frameCount) buffers")
        }
    }
    
    //Start stream
    func startRecording() throws {
        processingQueue.async {
            self.configureSession()
        }
    }
    
    //Finish stream
    func finishRecording(success: @escaping ((URL) -> Void)) throws {
        processingQueue.async {
            let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            self.compresserPtr!.pointee.src_size = 0
            let compression_status = compression_stream_process(self.compresserPtr!, flags)
            if compression_status != COMPRESSION_STATUS_END {
                NSLog("ERROR: Finish failed. compression retured: \(compression_status)")
                return
            }
            self.flush()
            DispatchQueue.main.sync {
                success(self.outputURL!)
            }
            self.reset()
        }
    }
    
    
}
