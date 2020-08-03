//
//  ViewController.swift
//  anotherTest
//
//  Created by Yirun Zhao on 2020/7/29.
//  Copyright © 2020 Yirun Zhao. All rights reserved.
//

import UIKit
import AVFoundation

enum AudioStatus: Int{
    case stopped=0,playing,recording
}
class ViewController: UIViewController {

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pathText: UITextView!
    @IBOutlet weak var truncateButton: UIButton!
    @IBOutlet weak var truncatePlayButton: UIButton!
    
    // 3个测试button
    @IBOutlet weak var truncateResultButton1: UIButton!
    @IBOutlet weak var truncateResultButton2: UIButton!
    @IBOutlet weak var truncateResultButton3: UIButton!
    //
    
    
    var audioRecorder:AVAudioRecorder!
    var audioPlayer:AVAudioPlayer!
    var audioStatus:AudioStatus = .stopped
    var truncateTimer: Timer!
    var truncateUrl: URL!       // 截取的URL，单独测试的，后面要用list
    var truncateCount: Int64!     // 记录截取音频的个数，应该在点击录音按钮的时候初始化
    var exportProcessing: Bool = false  // 异步是否正在导出
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        initRecorder()
    }
    // 3个测试button
    func playTruncateAudio(id: Int){
        let audioPath = URL(fileURLWithPath: NSTemporaryDirectory() + "S\(id)-E\(id+3).m4a")
        do{
            audioPlayer = try AVAudioPlayer(contentsOf: audioPath)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            if audioPlayer.duration > 0.0{
                audioPlayer.play()
                audioStatus = .playing
                playButton.setTitle("播放中...", for: .normal)
            } else {
                print("没有时长")
            }
        }catch{
            print("创建player失败，播放的路径是\(audioPath)")
        }
    }
    @IBAction func testOnTouch1(_ sender: Any) {
        playTruncateAudio(id: 0)
    }
    @IBAction func testOnTouch2(_ sender: Any) {
        playTruncateAudio(id: 3)
    }
    @IBAction func testOnTouch3(_ sender: Any) {
        playTruncateAudio(id: 6)
    }
    
    //
    
    func startRecording(){
        truncateCount = 0
        audioStatus = .recording
        recordButton.setTitle("录音中...", for: .normal)
        let ret = audioRecorder.record()
        if ret == false{
            print("录音失败了")
        }
        initTimer()
        print("开始录音")
    }
    func stopPlaying(){
        if audioPlayer != nil{
            audioStatus = .stopped
            audioPlayer.stop()
            playButton.setTitle("播放", for: .normal)
            print("停止播放")
        }
        else{
            print("没有audio player")
        }
    }
    func stopRecording(){
        audioStatus = .stopped
        recordButton.setTitle("录音", for: .normal)
        print("录音时长是:\(audioRecorder.currentTime)")
        audioRecorder.stop()
    }
    func startPlaying(audioPath : URL){
        do{
            audioPlayer = try AVAudioPlayer(contentsOf: audioPath)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            if audioPlayer.duration > 0.0{
                audioPlayer.play()
                audioStatus = .playing
                playButton.setTitle("播放中...", for: .normal)
            } else {
                print("没有时长")
            }
        }catch{
            print("播放失败")
        }
        
    }
    @IBAction func recordOnTouch(_ sender: Any) {
        switch audioStatus {
        case .stopped:
            startRecording()
        case .playing:
            stopPlaying()
            startRecording()
        case .recording:
            stopRecording()
        }
    }
    @IBAction func playOnTouch(_ sender: Any) {
        print("当前状态\(audioStatus)")
        let tempRecordUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "tempRecord.caf")
        switch audioStatus {
        case .stopped:
            startPlaying(audioPath: tempRecordUrl)
        case .playing:
            stopPlaying()
        case .recording:
            stopRecording()
            startPlaying(audioPath: tempRecordUrl)
        }
    }
    @IBAction func truncateOnTouch(_ sender: Any) {
        let prepareUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "tempRecord.caf")
        let start = CMTime(value: truncateCount*3, timescale: 1)
        let end = CMTime(value: truncateCount*3+3, timescale: 1)
        let truncateResultUrl = truncateAudio(url: prepareUrl, startTime: start, endTime: end)
        print("截取url是\(truncateResultUrl.absoluteString)")
        
        while(exportProcessing){}
        truncateUrl = truncateResultUrl
        truncateCount += 1
        pathText.text += "\n\(truncateUrl.absoluteString)"
    }
    @IBAction func truncatePlayOnTouch(_ sender: Any) {
        startPlaying(audioPath: truncateUrl)
    }
    
    

}

extension ViewController: AVAudioRecorderDelegate, AVAudioPlayerDelegate{
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("录音结束")
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlaying()
    }
    func initRecorder(){
        let tempRecordPath = NSTemporaryDirectory() + "tempRecord.caf"
        let recordSettings: [String: Any] = [
            // 编码格式
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            // 采样率
            AVSampleRateKey: 44100.0,
            // 通道数
            AVNumberOfChannelsKey: 2,
            // 录音质量
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        
        // 初始化session，不然第一次录音会不成功
        // 因为初始设置是不能录音的
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setCategory(AVAudioSession.Category.playAndRecord)
            
        }catch{
            print("session错误")
        }
        do{
            audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: tempRecordPath), settings: recordSettings)
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
        }catch{
            print("生成recorder失败")
        }
    }
}

extension ViewController{
    // url是截取片段的url
    // MARK -: url是待截取的地址，返回截取后的地址
    func truncateAudio(url : URL, startTime: CMTime, endTime: CMTime) -> URL{
        exportProcessing = false
        let resultAudioName = "S\(startTime.value)-E\(endTime.value).m4a"
        let resultAudioUrl = URL(fileURLWithPath: NSTemporaryDirectory() + resultAudioName)
        
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
//        let exportTimeRange = CMTimeRangeMake(start: startTime, duration: endTime - startTime)
        let exportTimeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
            
        exportSession?.outputURL = resultAudioUrl
        exportSession?.outputFileType = .m4a
        exportSession?.timeRange = exportTimeRange
            
        // 如果有录音文件，删除
        do{
            try FileManager.default.removeItem(at: resultAudioUrl)
        }catch{
            print("删除截取录音文件失败: \(error.localizedDescription)")
        }
        // 截取
        exportSession?.exportAsynchronously(completionHandler: {
            () in
            if exportSession?.status == AVAssetExportSession.Status.failed{
                print("导出失败！原因是\(exportSession?.error?.localizedDescription ?? "error还不知道")")
                self.exportProcessing = true
            }
            else if exportSession?.status == AVAssetExportSession.Status.completed{
                print("导出成功！路径是\(resultAudioUrl.absoluteString)")
                self.exportProcessing = true
            } else if exportSession?.status == AVAssetExportSession.Status.cancelled{
                print("导出撤销")
                self.exportProcessing = true
            }
        })
        return resultAudioUrl
    }
}

// MARK: - 和定时器相关的
extension ViewController{
    
    func initTimer(){
        truncateTimer?.invalidate()
        // 这个初始化的时候就开始计时了
        truncateTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(truncateTimerAction), userInfo: nil, repeats: true)
    }
    @objc func truncateTimerAction(){
        // 录音的时候才进行截取
        if audioStatus == .recording{
            // 对于片段进行截取
            let url = URL(fileURLWithPath: NSTemporaryDirectory() + "tempRecord.caf")
            let startTime = CMTime(value: truncateCount, timescale: 1)
            let endTime = CMTime(value: truncateCount+3, timescale: 1)
            let resultAudioUrl = truncateAudio(url: url, startTime: startTime, endTime: endTime)
            
            while(exportProcessing){}
            truncateCount += 3
            // 添加显示截取的url
            truncateUrl = resultAudioUrl
            pathText.text += "\n\(resultAudioUrl.absoluteString)"
        }
    }
    
}
