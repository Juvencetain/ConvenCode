//
//  ColorPickerViewModel.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/16.
//


import SwiftUI
import AppKit
import Combine

@MainActor
class ColorPickerViewModel: ObservableObject {
    @Published var selectedColor: Color = .white
    @Published var hexValue: String = ""
    @Published var rgbValue: String = ""
    @Published var hslValue: String = ""
    @Published var showToast: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFromTextField = false

    init() {
        $selectedColor
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] color in
                guard let self = self, !self.isUpdatingFromTextField else { return }
                self.updateValues(from: color)
            }
            .store(in: &cancellables)
        
        $hexValue
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] hex in
                guard let self = self else { return }
                self.isUpdatingFromTextField = true
                if let color = Color(hex: hex) {
                    self.selectedColor = color
                }
                self.isUpdatingFromTextField = false
            }
            .store(in: &cancellables)

        updateValues(from: selectedColor)
    }

    func updateValues(from color: Color) {
        let nsColor = NSColor(color)
        hexValue = nsColor.toHex() ?? ""
        rgbValue = nsColor.toRgbString() ?? ""
        hslValue = nsColor.toHslString() ?? ""
    }

    func pickColorFromScreen() {
        let colorSampler = NSColorSampler()
        colorSampler.show { [weak self] color in
            if let color = color {
                self?.selectedColor = Color(nsColor: color)
            }
        }
    }
    
    func copyValue(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        showToast = true
    }
}

extension NSColor {
    func toHex() -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(rgbColor.redComponent * 255.0))
        let green = Int(round(rgbColor.greenComponent * 255.0))
        let blue = Int(round(rgbColor.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    func toRgbString() -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(rgbColor.redComponent * 255.0))
        let green = Int(round(rgbColor.greenComponent * 255.0))
        let blue = Int(round(rgbColor.blueComponent * 255.0))
        return "rgb(\(red), \(green), \(blue))"
    }
    
    func toHslString() -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else { return nil }
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        let l: CGFloat = (maxC + minC) / 2
        
        if maxC != minC {
            let d = maxC - minC
            s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
            switch maxC {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            case b: h = (r - g) / d + 4
            default: break
            }
            h /= 6
        }
        
        return "hsl(\(Int(h * 360)), \(Int(s * 100))%, \(Int(l * 100))%)"
    }
}
