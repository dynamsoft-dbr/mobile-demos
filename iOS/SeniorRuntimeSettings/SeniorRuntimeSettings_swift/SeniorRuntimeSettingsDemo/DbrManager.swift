//
//  DbrManager.swift
//  SeniorRuntimeSettingsDemo
//
//  Created by Dynamsoft on 05/07/2020.
//  Copyright © 2020 Dynamsoft. All rights reserved.
//

import UIKit
import AVFoundation
import DynamsoftBarcodeReader

class  DbrManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,DBRServerLicenseVerificationDelegate {
    
    var barcodeFormat:Int?
    var barcodeFormat2:Int?
    var startRecognitionDate:NSDate?
    var startVidioStreamDate:NSDate?
    var isPauseFramesComing:Bool?
    var isCurrentFrameDecodeFinished:Bool?
    var m_videoCaptureSession:AVCaptureSession!
    var barcodeReader: DynamsoftBarcodeReader!
    var settings:iPublicRuntimeSettings!
    var m_recognitionCallback:Selector?
    var m_recognitionReceiver:ViewController?
    var m_verificationCallback:Selector?
    var m_verificationReceiver:ViewController?

    var inputDevice:AVCaptureDevice?
    var itrFocusFinish:Int!
    var firstFocusFinish:Bool!
    
    init(serverURL:String,licenseKey:String) {
        super.init()
        barcodeReader = DynamsoftBarcodeReader(licenseFromServer: serverURL, licenseKey: licenseKey, verificationDelegate: self)
        self.parametersInit()
    }
    
    init(license:String)
    {
        super.init()
        barcodeReader = DynamsoftBarcodeReader(license: license)
        
        var err:NSError?
        //Senior Runtime Settings
        barcodeReader.initRuntimeSettings(with: "{\"Version\":\"3.0\",\"ImageParameterContentArray\":[{\"Name\":\"TestSeniorSettings\",\"FormatSpecificationNameArray\":[\"FP_1\"],\"ExpectedBarcodesCount\":0,\"MaxAlgorithmThreadCount\":4,\"BarcodeFormatIds\":[\"BF_ALL\"],\"LocalizationModes\":[\"LM_CONNECTED_BLOCKS\",\"LM_SCAN_DIRECTLY\",\"LM_STATISTICS\",\"LM_LINES\"],\"BinarizationModes\":[\"BM_LOCAL_BLOCK(20,20,1,,10)\"],\"DeblurLevel\":9}],\"FormatSpecificationArray\":[{\"Name\":\"FP_1\",\"BarcodeFormatIds\":[\"BF_PDF417\",\"BF_QR_CODE\",\"BF_DATAMATRIX\"],\"MirrorMode\":\"MM_Both\"}]}", conflictMode: EnumConflictMode.overwrite, error: &err)
        settings = try! barcodeReader.getRuntimeSettings()
        settings.barcodeFormatIds  = Int(EnumBarcodeFormat.ALL.rawValue)
        //Set for BlockSize
        settings.binarizationModes = [Int(EnumBinarizationMode.localBlock.rawValue), 0, 0, 0, 0, 0, 0, 0]
        
        barcodeReader.update(settings!, error: nil)
        var err1:NSError?
        var err2:NSError?
        var err3:NSError?
        barcodeReader.setModeArgument("BinarizationModes", index: 0, argumentName: "EnableFillBinaryVacancy", argumentValue: "1", error: &err1)
        barcodeReader.setModeArgument("BinarizationModes", index: 0, argumentName: "BlockSizeX", argumentValue: "20", error: &err2)
        barcodeReader.setModeArgument("BinarizationModes", index: 0, argumentName: "BlockSizeY", argumentValue: "20", error: &err3)
        barcodeReader.setModeArgument("BinarizationModes", index: 0, argumentName: "ThreshValueCoefficient", argumentValue: "10", error: nil)
        
//        let blockSizex  = barcodeReader.getModeArgument("BinarizationModes", index: 0, argumentName: "BlockSizeX", error: nil)
//        let blockSizey  = barcodeReader.getModeArgument("BinarizationModes", index: 0, argumentName: "BlockSizeY", error: nil)
//        let vacancy     = barcodeReader.getModeArgument("BinarizationModes", index: 1, argumentName: "EnableFillBinaryVacancy", error: nil)
//        let threshValue = barcodeReader.getModeArgument("BinarizationModes", index: 0, argumentName: "ThreshValueCoefficient", error: nil)
        self.parametersInit()
    }
    
    deinit {
        barcodeReader = nil
        if(m_videoCaptureSession != nil)
        {
            if(m_videoCaptureSession.isRunning)
            {
                m_videoCaptureSession.stopRunning()
            }
            m_videoCaptureSession = nil
        }
        inputDevice = nil
        m_recognitionReceiver = nil
        m_recognitionCallback = nil
        m_verificationReceiver = nil
        m_verificationCallback = nil
    }
    
    func connectServerAfterInit(serverURL:String,licenseKey:String)
    {
        barcodeReader = DynamsoftBarcodeReader(licenseFromServer: serverURL, licenseKey: licenseKey, verificationDelegate: self)
    }
    
    func parametersInit()
    {
        m_videoCaptureSession = nil
        isPauseFramesComing = false
        isCurrentFrameDecodeFinished = true
        barcodeFormat = Int(EnumBarcodeFormat.ALL.rawValue)
        barcodeFormat2 = 0
        startRecognitionDate = nil
        m_recognitionReceiver = nil
        startVidioStreamDate  = NSDate()
        itrFocusFinish = 0
        firstFocusFinish = false
    }
    
    func setBarcodeFormat(format:Int, format2:Int)
    {
        do
        {
            barcodeFormat = format
            barcodeFormat2 = format2
            let settings = try barcodeReader.getRuntimeSettings()
            settings.barcodeFormatIds = format
            settings.barcodeFormatIds_2 = format2
            barcodeReader.update(settings, error: nil)
        }
        catch{
            print(error)
        }
    }
    
    func setVideoSession()
    {
        do
        {
            inputDevice = self.getAvailableCamera()
            let tInputDevice = inputDevice!
            let captureInput = try? AVCaptureDeviceInput(device: tInputDevice)
            let captureOutput = AVCaptureVideoDataOutput.init()
            captureOutput.alwaysDiscardsLateVideoFrames = true
            var queue:DispatchQueue
            queue = DispatchQueue(label: "dbrCameraQueue")
            captureOutput.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: queue)
            
            // Enable continuous autofocus
            if(tInputDevice.isFocusModeSupported(AVCaptureDevice.FocusMode.continuousAutoFocus))
            {
                try tInputDevice.lockForConfiguration()
                tInputDevice.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
                tInputDevice.unlockForConfiguration()
            }
            
            // Enable AutoFocusRangeRestriction
            if(tInputDevice.isAutoFocusRangeRestrictionSupported)
            {
                try tInputDevice.lockForConfiguration()
                tInputDevice.autoFocusRangeRestriction = AVCaptureDevice.AutoFocusRangeRestriction.near
                tInputDevice.unlockForConfiguration()
            }
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
            
            if(captureInput == nil)
            {
                return
            }
            self.m_videoCaptureSession = AVCaptureSession.init()
            self.m_videoCaptureSession.addInput(captureInput!)
            self.m_videoCaptureSession.addOutput(captureOutput)
            
            if(self.m_videoCaptureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1920x1080"))){
                self.m_videoCaptureSession.sessionPreset = AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1920x1080")
            }
            else if(self.m_videoCaptureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1280x720"))){
                self.m_videoCaptureSession.sessionPreset = AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1280x720")
            }
            else if(self.m_videoCaptureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset640x480"))){
                self.m_videoCaptureSession.sessionPreset = AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset640x480")
            }
        }catch{
            print(error)
        }
    }
    
    func startVideoSession()
    {
        if(!self.m_videoCaptureSession.isRunning)
        {
            self.m_videoCaptureSession.startRunning()
        }
    }
    
    func getAvailableCamera() -> AVCaptureDevice {
        let videoDevices = AVCaptureDevice.devices(for: AVMediaType.video)
        var captureDevice:AVCaptureDevice?
        for device in videoDevices
        {
            if(device.position == AVCaptureDevice.Position.back)
            {
                captureDevice = device
                break
            }
        }
        if(captureDevice != nil)
        {
            captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        }
        return captureDevice!
    }
    
    func getVideoSession() -> AVCaptureSession
    {
        return m_videoCaptureSession
    }
    
    //AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        if(inputDevice == nil)
        {
            return
        }
        
        if(inputDevice?.isAdjustingFocus == false)
        {
            itrFocusFinish = itrFocusFinish + 1
            if(itrFocusFinish == 1)
            {
                firstFocusFinish = true
            }
        }
        if(!firstFocusFinish || isPauseFramesComing == true || isCurrentFrameDecodeFinished == false)
        {
            return
        }

        isCurrentFrameDecodeFinished = false
        let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bufferSize = CVPixelBufferGetDataSize(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(imageBuffer)
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        startRecognitionDate = NSDate()
        let buffer = Data(bytes: baseAddress!, count: bufferSize)
        guard let results = try? barcodeReader.decodeBuffer(buffer, withWidth: width, height: height, stride: bpr, format: .ARGB_8888, templateName: "") else { return }
        DispatchQueue.main.async{
            self.m_recognitionReceiver?.perform(self.m_recognitionCallback!, with: results as [iTextResult])
        }
    }
    
    func setRecognitionCallback(sender:ViewController, callBack:Selector)
    {
        m_recognitionReceiver = sender
        m_recognitionCallback = callBack
    }
    
    func setServerLicenseVerificationCallback(sender:ViewController, callBack:Selector)
    {
        m_verificationReceiver = sender
        m_verificationCallback = callBack
    }
    
    func licenseVerificationCallback(_ isSuccess: Bool, error: Error?)
    {
        let boolNumber = NSNumber(value: isSuccess)
        DispatchQueue.main.async{
            self.m_verificationReceiver?.perform(self.m_verificationCallback!, with: boolNumber, with: error)
        }
    }
}
