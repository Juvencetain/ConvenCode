//
//  MorseCoder.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/14.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Core Logic (Model)
struct MorseCoder {
    enum MorseError: LocalizedError {
        case invalidCharacter(Character)
        case invalidMorseSequence(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidCharacter(let char):
                return "输入包含不支持的字符: '\(char)'"
            case .invalidMorseSequence(let seq):
                return "包含无法识别的摩斯电码序列: '\(seq)'"
            }
        }
    }

    private static let morseMap: [Character: String] = [
        "A": ".-",    "B": "-...",  "C": "-.-.", "D": "-..",   "E": ".",
        "F": "..-.",  "G": "--.",   "H": "....", "I": "..",    "J": ".---",
        "K": "-.-",   "L": ".-..",  "M": "--",   "N": "-.",    "O": "---",
        "P": ".--.",  "Q": "--.-",  "R": ".-.",  "S": "...",   "T": "-",
        "U": "..-",   "V": "...-",  "W": ".--",  "X": "-..-",  "Y": "-.--",
        "Z": "--..",  "1": ".----", "2": "..---","3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...","8": "---..", "9": "----.",
        "0": "-----", ".": ".-.-.-",",": "--..--","?": "..--..", "'": ".----.",
        "!": "-.-.--", "/": "-..-.", "(": "-.--.", ")": "-.--.-", "&": ".-...",
        ":": "---...", ";": "-.-.-.", "=": "-...-", "+": ".-.-.", "-": "-....-",
        "_": "..--.-", "\"": ".-..-.", "$": "...-..-","@": ".--.-."
    ]
    
    private static let charMap: [String: Character] = {
        var map = [String: Character]()
        for (key, value) in morseMap {
            map[value] = key
        }
        return map
    }()

    func encode(text: String) throws -> String {
        var result = ""
        let uppercasedText = text.uppercased()
        
        for (i, char) in uppercasedText.enumerated() {
            if char == " " {
                if !result.hasSuffix("/ ") && !result.isEmpty {
                    result += "/ "
                }
            } else if let morse = MorseCoder.morseMap[char] {
                result += morse
                if i < uppercasedText.count - 1 {
                    let nextIndex = uppercasedText.index(after: uppercasedText.index(uppercasedText.startIndex, offsetBy: i))
                    if nextIndex < uppercasedText.endIndex && uppercasedText[nextIndex] != " " {
                        result += " "
                    }
                }
            } else {
                throw MorseError.invalidCharacter(char)
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func decode(morse: String) throws -> String {
        var result = ""
        let words = morse.split(separator: "/")
        
        for word in words {
            let characters = word.split(separator: " ")
            for morseSequence in characters {
                if let char = MorseCoder.charMap[String(morseSequence)] {
                    result.append(char)
                } else {
                    throw MorseError.invalidMorseSequence(String(morseSequence))
                }
            }
            result.append(" ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}


// MARK: - View Model
@MainActor
class MorseCodeViewModel: ObservableObject {
    enum Mode: String, CaseIterable {
        case encode = "编码"
        case decode = "解码"
    }
    
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var mode: Mode = .encode
    @Published var errorMessage: String?
    @Published var showSuccessToast = false
    @Published var isPlaying = false

    private let coder = MorseCoder()
    private var morsePlayer: MorseAudioPlayer?
    
    func process() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "请输入内容"
            return
        }
        
        errorMessage = nil
        do {
            switch mode {
            case .encode:
                outputText = try coder.encode(text: trimmedInput)
            case .decode:
                outputText = try coder.decode(morse: trimmedInput)
            }
        } catch {
            outputText = ""
            errorMessage = error.localizedDescription
        }
    }
    
    func swap() {
        let temp = inputText
        inputText = outputText
        outputText = temp
        mode = (mode == .encode) ? .decode : .encode
        errorMessage = nil
    }
    
    func clear() {
        inputText = ""
        outputText = ""
        errorMessage = nil
    }
    
    func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        showSuccessToast = true
    }
    
    func playMorseSound() {
        guard !isPlaying, !outputText.isEmpty, mode == .encode else { return }

        if morsePlayer == nil {
            morsePlayer = MorseAudioPlayer()
        }
        
        isPlaying = true
        Task {
            await morsePlayer?.play(morseString: outputText)
            await MainActor.run {
                self.isPlaying = false
            }
        }
    }
}

// MARK: - Main View
struct MorseCodeToolView: View {
    @StateObject private var viewModel = MorseCodeViewModel()
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                headerBar
                
                modeSelector
                
                ModernTextArea(
                    title: "输入",
                    text: $viewModel.inputText,
                    placeholder: viewModel.mode == .encode ? "输入要编码的文本..." : "输入要解码的摩斯电码..."
                )
                
                actionButtons
                
                if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    outputArea
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 560)
        .focusable(false)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }
    }
    
    // MARK: - Subviews
    private var headerBar: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 16))
                .foregroundStyle(.green.gradient)
            Text("摩斯电码工具")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
    }
    
    private var modeSelector: some View {
        HStack(spacing: 10) {
            ForEach(MorseCodeViewModel.Mode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    withAnimation {
                        viewModel.mode = mode
                    }
                }
                .buttonStyle(ModernButtonStyle(style: viewModel.mode == mode ? .accent : .normal))
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.process) {
                Label("转换", systemImage: "arrow.right.arrow.left.circle.fill")
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .disabled(viewModel.inputText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            
            Button(action: viewModel.swap) {
                Label("互换", systemImage: "arrow.up.arrow.down.circle.fill")
            }
            .buttonStyle(ModernButtonStyle())
            .disabled(viewModel.outputText.isEmpty)

            if viewModel.mode == .encode && !viewModel.outputText.isEmpty {
                Button(action: viewModel.playMorseSound) {
                    Label(viewModel.isPlaying ? "播放中..." : "播放",
                          systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(ModernButtonStyle(style: .accent))
                .disabled(viewModel.isPlaying)
            }
            
            Spacer()
            
            Button(action: viewModel.clear) {
                Label("清空", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(ModernButtonStyle(style: .danger))
            .disabled(viewModel.inputText.isEmpty && viewModel.outputText.isEmpty)
        }
    }
    
    private var outputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输出")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !viewModel.outputText.isEmpty {
                    Button(action: viewModel.copyOutput) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .pointingHandCursor()
                }
            }
            
            TextEditor(text: .constant(viewModel.outputText))
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
            Text(message)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(12)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .cornerRadius(10)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var toastView: some View {
        Text("✓ 已复制到剪贴板")
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { viewModel.showSuccessToast = false }
                }
            }
    }
}


// MARK: - Morse Audio Player
actor MorseAudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let audioFormat: AVAudioFormat
    
    private let dotDuration: TimeInterval = 0.08
    private var dashDuration: TimeInterval { dotDuration * 3 }
    private var symbolGap: TimeInterval { dotDuration }
    private var letterGap: TimeInterval { dotDuration * 3 }
    private var wordGap: TimeInterval { dotDuration * 7 }
    
    init?() {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        ) else { return nil }
        
        self.audioFormat = format
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
        
        do {
            try engine.start()
        } catch {
            print("❌ 启动音频引擎失败: \(error)")
            return nil
        }
    }
    
    func play(morseString: String) async {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("❌ 重启音频引擎失败")
                return
            }
        }
        
        player.play()
        
        for char in morseString {
            switch char {
            case ".":
                await playTone(duration: dotDuration)
                await sleep(for: symbolGap)
            case "-":
                await playTone(duration: dashDuration)
                await sleep(for: symbolGap)
            case " ":
                await sleep(for: letterGap - symbolGap)
            case "/":
                await sleep(for: wordGap - letterGap)
            default:
                break
            }
        }
        
        player.stop()
    }
    
    private func playTone(duration: TimeInterval) async {
        guard let buffer = createSineWaveBuffer(duration: duration) else { return }
        await player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }
    
    private func sleep(for duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    private func createSineWaveBuffer(duration: TimeInterval) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(audioFormat.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameCount
        ) else { return nil }
        
        let freq: Float = 600
        let sampleRate = Float(audioFormat.sampleRate)
        
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let channelData = floatChannelData[0]
        
        for frame in 0..<Int(frameCount) {
            let time = Float(frame) / sampleRate
            let value = sin(2 * .pi * freq * time)
            channelData[frame] = value * 0.5
        }
        
        buffer.frameLength = frameCount
        return buffer
    }
    
    deinit {
        engine.stop()
    }
}


// MARK: - 通用文本区域组件
//struct ModernTextArea: View {
//    let title: String
//    @Binding var text: String
//    var placeholder: String = ""
//    var isReadOnly: Bool = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text(title)
//                .font(.system(size: 12, weight: .semibold))
//                .foregroundColor(.secondary)
//            
//            TextEditor(text: $text)
//                .font(.system(size: 13, design: .monospaced))
//                .scrollContentBackground(.hidden)
//                .background(Color.white.opacity(0.05))
//                .cornerRadius(8)
//                .disabled(isReadOnly)
//                .frame(maxHeight: .infinity)
//        }
//    }
//}


#Preview {
    MorseCodeToolView()
}
