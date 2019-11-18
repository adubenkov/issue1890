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
    
    var musicPlayer: AKClipPlayer?
    var clipPlayer: AKClipPlayer?
    var playerMixer: AKMixer?
    var clipRecorder: AKClipRecorder?
    var mic: AKMicrophone?

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
//        AKSettings.sampleRate = 48_000
        AKSettings.playbackWhileMuted = true
        AKSettings.bufferLength = .medium
        AKSettings.useBluetooth = true
        AKSettings.allowAirPlay = true
        AKSettings.defaultToSpeaker = true
        AKSettings.audioInputEnabled = true
        AudioKit.engine.isAutoShutdownEnabled = false
        try AudioKit.start()
    }

    private func setupPlaybackNodes(withProjectAudioFile projectAudioFile: AKAudioFile) throws {
        let projectTrackPlayer = AKClipPlayer()
        try projectTrackPlayer.setClips(clips: [AKFileClip(audioFile: projectAudioFile)])
        musicPlayer = projectTrackPlayer
        let mixer = AKMixer(projectTrackPlayer)
        playerMixer = mixer
    }

    private func setupTakePlaybackNodes(withTakeAudioFile takeFile: AKAudioFile?) throws {
        let takeTracksPlayer = AKClipPlayer()
        let takeClipsSequence = AKFileClipSequence(clips: [])

        if let audioFile = takeFile {
            let takeFileClip = AKFileClip(audioFile: audioFile)
            try takeTracksPlayer.setClips(clips: [takeFileClip])
            takeClipsSequence.add(clip: takeFileClip)
        }
        clipPlayer = takeTracksPlayer
        playerMixer?.connect(input: takeTracksPlayer)
    }

    private func setupRecordingNodes() throws {
        if let microphone = AKMicrophone() {
            mic = microphone

            // Export is working if you comment this line
            clipRecorder = AKClipRecorder(node: microphone)
        }
    }

    func setupNodes() throws {
        let track1 = try AKAudioFile(readFileName: "click.m4a")
        let track2 = try AKAudioFile(readFileName: "clip.m4a")
        try setupPlaybackNodes(withProjectAudioFile: track1)
        try setupTakePlaybackNodes(withTakeAudioFile: track2)
        try setupRecordingNodes()
        AudioKit.output = playerMixer
    }


    @IBAction func renderButtonPressed(_ sender: Any) {
        do {
            try setupNodes()
            try setupAudioKitSettings()

            func preRender() {
                self.musicPlayer?.play()
                self.clipPlayer?.play()
            }

            let writeFile = try AKAudioFile()

            try AudioKit.renderToFile(writeFile, duration: 20.0, prerender: preRender)
            exportAudioFile(audioFile: writeFile, fileName: "export.m4a", baseDir: .documents)
        } catch {
            print(error.localizedDescription)
        }
    }

}

