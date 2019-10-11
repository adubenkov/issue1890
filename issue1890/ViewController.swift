//
//  ViewController.swift
//  issue1890
//
//  Created by Andrey Dubenkov on 10/10/2019.
//  Copyright © 2019 adubenkov. All rights reserved.
//

import UIKit
import AudioKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    func exportFile(file: URL) {
        let viewController = UIActivityViewController(activityItems: [file], applicationActivities: [])
        present(viewController, animated: true)
    }

    func exportAudioFile(audioFile: AKAudioFile,
                         fileName: String,
                         baseDir: AKAudioFile.BaseDirectory) {
        DispatchQueue.global().async {
            audioFile.exportAsynchronously(name: fileName, baseDir: baseDir, exportFormat: .m4a) { file, error in
                DispatchQueue.main.async {
                    guard let error = error else {
                        self.exportFile(file: file!.url)
                        return
                    }
                    print(error.localizedDescription)
                }
            }
        }
    }

    private func setupAudioKitSettings() throws {
        try AKSettings.setSession(category: .playAndRecord, with: [
                    .allowBluetoothA2DP,
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .mixWithOthers
                ])
        AKSettings.sampleRate = 48_000
        AKSettings.playbackWhileMuted = true
        AKSettings.bufferLength = .medium
        AKSettings.useBluetooth = true
        AKSettings.allowAirPlay = true
        AKSettings.defaultToSpeaker = true
        AKSettings.audioInputEnabled = true
        AudioKit.engine.isAutoShutdownEnabled = false
        try AudioKit.start()
    }

    @IBAction func renderButtonPressed(_ sender: Any) {
        do {
            try setupAudioKitSettings()
            // I have reproduced all of the nodes that I have in my app
            let microphone = AKMicrophone()
            let fieldLimiter = AKStereoFieldLimiter(microphone, amount: 0)
            let micMixer = AKMixer(fieldLimiter)
            let micBooster = AKBooster(micMixer)
            let clipRecorder = AKClipRecorder(node: micBooster)

            let writeFile = try AKAudioFile()
            let track1 = try AKAudioFile(readFileName: "click.m4a")
            let track2 = try AKAudioFile(readFileName: "clip.m4a")
            let clip1 = AKFileClip(audioFile: track1)
            let clip2 = AKFileClip(audioFile: track2)
            let player1 = AKClipPlayer()
            let player2 = AKClipPlayer()

            let clipFile = try AKAudioFile()
            let firstClip = AKFileClip(audioFile: clipFile)

            player1.clips.insert(clip1, at: 0)
            player2.clips.insert(clip2, at: 0)
            player1.clips.insert(firstClip, at: 0)
            let mixer = AKMixer([player1, player2])
            let booster = AKBooster(mixer)
            AudioKit.output = booster

            func preRender() {
                player1.play()
                player2.play()
            }

            try AudioKit.renderToFile(writeFile, duration: track1.duration, prerender: preRender)
            exportAudioFile(audioFile: writeFile, fileName: "export.m4a", baseDir: .documents)
        } catch {
            print(error.localizedDescription)
        }
    }

}

