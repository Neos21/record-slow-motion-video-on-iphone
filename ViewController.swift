import UIKit
import AVFoundation
import Photos

// ViewController
class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UITabBarDelegate {
  // セッション
  var session: AVCaptureSession!
  // ビデオデバイス
  var videoDevice: AVCaptureDevice!
  // オーディオデバイス
  var audioDevice: AVCaptureDevice!
  // ファイル出力
  var fileOutput: AVCaptureMovieFileOutput!
  
  
  // ================================================================================
  // 初期処理
  // ================================================================================
  
  // ViewController がロードされた時
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // アプリ起動時・フォアグラウンド復帰時の通知を設定する
    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.onDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    // ホームボタン押下時の通知を設定する
    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.onWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    // アプリ終了時の通知を設定する
    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.onWillTerminate(_:)), name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
    
    print("セッション生成")
    session = AVCaptureSession()
    
    print("入力 : 背面カメラ")
    videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice)
    session.addInput(videoInput)
    
    print("フォーマット指定")
    // switchFormat(desiredFps: 30.0)  // 30fps 撮影する場合
    // switchFormat(desiredFps: 60.0)  // 60fps 撮影する場合
    // switchFormat(desiredFps: 120.0)  // 120fps 撮影する場合
    switchFormat(desiredFps: 240.0)  // 240fps 撮影する場合
    
    print("入力 (マイク)")
    audioDevice = AVCaptureDevice.default(for: .audio)
    let audioInput = try! AVCaptureDeviceInput.init(device: audioDevice)
    session.addInput(audioInput)
    
    print("出力")
    fileOutput = AVCaptureMovieFileOutput()
    session.addOutput(fileOutput)
    
    print("セッション開始")  // 録画開始は ApplicationDidBecomeActive で行う
    session.startRunning()
    
    print("初期処理完了")
  }
  
  
  // ================================================================================
  // プライベートメソッド : UI 操作に基づいて呼び出すように実装する
  // ================================================================================
  
  // 指定の FPS のフォーマットに切り替える (その FPS で最大解像度のフォーマットを選ぶ)
  // 
  // @param desiredFps 切り替えたい FPS (AVFrameRateRange.maxFrameRate が Double なので合わせる)
  private func switchFormat(desiredFps: Double) {
    print("フォーマット切替処理 : \(desiredFps) fps")
    
    // これ以上大きな解像度を選択しないようにする上限値 : フル HD サイズ以上を選ばないようにする
    let limitWidth: Int32 = 1921  // 幅 1920px まで
    let limitHeight: Int32 = 1081 // 高さ 1080px まで
    
    // セッションが始動しているかどうか・あとで再開するため控えておく
    let isRunning = session.isRunning
    if isRunning {
      print("セッション一時停止")  // セッションが始動中なら一時的に停止しておく
      session.stopRunning()
    }
    
    // 取得したフォーマットを格納する変数
    var selectedFormat: AVCaptureDevice.Format! = nil
    // そのフレームレートの中で一番大きい解像度を取得する
    var maxWidth: Int32 = 0
    var maxHeight: Int32 = 0
    
    // フォーマットを探る
    for format in videoDevice.formats {
      // フォーマット内の情報を抜き出す (for in と書いているが1つの format につき1つの range しかない)
      for range: AVFrameRateRange in format.videoSupportedFrameRateRanges {
        let description = format.formatDescription as CMFormatDescription  // フォーマットの説明
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)  // 幅・高さ情報を抜き出す
        let width = dimensions.width
        let height = dimensions.height
        // 指定のフレームレートで一番大きな解像度を得る (上限値を超える解像度は選ばない)
        if desiredFps == range.maxFrameRate && (maxWidth <= width && width < limitWidth) && (maxHeight <= height && height < limitHeight) {
          selectedFormat = format
          maxWidth = width
          maxHeight = height
          print("選択したフォーマット情報 : \(descrption)")
        }
      }
    }
    
    if selectedFormat != nil {  // フォーマットが取得できていれば設定する
      do {
        try videoDevice.lockForConfiguration()  // ロックできなければ例外を投げる
        videoDevice.activeFormat = selectedFormat
        videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, Int32(desiredFps))
        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(desiredFps))
        videoDevice.unlockForConfiguration()
        print("フォーマット・フレームレートを設定 : \(desiredFps) fps ・ \(maxWidth) × \(maxHeight) px")
        
        if isRunning {
          print("セッション再開")  // セッションが始動中だった時は一時停止していたものを再開する
          session.startRunning()
        }
      }
      catch {
        print("フォーマット・フレームレートが指定できなかった : \(desiredFps) fps")
      }
    }
    else {
      print("フォーマットが取得できなかった : \(desiredFps) fps")  // 他のフォーマットを試す
      switch desiredFps {
        case 240.0:
          print("240fps が選択できなかったので 120fps が選べるか再試行する")
          switchFormat(desiredFps: 120.0)
        case 120.0:
          print("60fps が選択できなかったので 60fps が選べるか再試行する")
          switchFormat(desiredFps: 60.0)
        case 60.0:
          print("60fps が選択できなかったので 30fps が選べるか再試行する")
          switchFormat(desiredFps: 30.0)
        case 30.0:
          print("30fps が選択できなかったので諦める")
        default:
          print("未知の FPS・何もしない : \(desiredFps)")
      }
    }
  }
  
  // 録画を開始する
  private func startRecording() {
    print("録画開始")
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0] as String
    // 現在時刻をファイル名に付与する
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMddHHmmssSSS"
    let filePath: String? = "\(documentsDirectory)/myvideo-\(formatter.string(from: Date())).mp4"
    print("録画開始 : \(filePath!)")
    let fileURL = NSURL(fileURLWithPath: filePath!)
    fileOutput?.startRecording(to: fileURL as URL, recordingDelegate: self)
  }
  
  // 録画を停止する
  private func stopRecording() {
    print("録画停止")
    fileOutput?.stopRecording()
  }
  
  // アプリ内の mp4 ファイルをフォトライブラリに書き出しアプリ内からは削除する
  private func downloadFiles() {
    let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    do {
      let contentUrls = try FileManager.default.contentsOfDirectory(at: documentDirectoryURL, includingPropertiesForKeys: nil)
      for contentUrl in contentUrls {
        if contentUrl.pathExtension == "mp4" {
          print("mp4 ファイルなのでフォトライブラリに書き出す : \(contentUrl.lastPathComponent)")
          PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: contentUrl)
          }) { (isCompleted, error) in
            if isCompleted {
              print("フォトライブラリに書き出し成功 : \(contentUrl.lastPathComponent)")
              do {
                try FileManager.default.removeItem(atPath: contentUrl.path)
                print("フォトライブラリ書き出し後のファイル削除成功 : \(contentUrl.lastPathComponent)")
              }
              catch {
                print("フォトライブラリ書き出し後のファイル削除失敗 : \(contentUrl.lastPathComponent)")
              }
            }
            else {
              print("フォトライブラリ書き出し失敗 : \(contentUrl.lastPathComponent)")
            }
          }
        }
        else {
          print("mp4 ファイルではないので無視 : \(contentUrl.lastPathComponent)")
        }
      }
    }
    catch {
      print("ファイル一覧取得エラー : \(error)")
    }
  }
  
  
  // ================================================================================
  // 通知イベント系
  // ================================================================================
  
  // アプリ起動時・フォアグラウンド復帰時に行う処理
  @objc func onDidBecomeActive(_ notification: Notification?) {
    print("録画再開")
    startRecording()
  }
  
  // ホームボタンが押された時に行う処理
  @objc func onWillResignActive(_ notification: Notification?) {
    print("強制停止")
    stopRecording()
  }
  
  // アプリが終了される時に行う処理
  @objc func onWillTerminate(_ notification: Notification?) {
    print("アプリ終了・セッション終了")
    if session.isRunning {
      session.stopRunning()
    }
  }
  
  
  // ================================================================================
  // オーバーライドして置いておく系
  // ================================================================================
  
  // 録画完了時の処理
  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    print("録画完了・ココでは何もしない")
  }
}
