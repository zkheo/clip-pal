import SwiftUI
import AppKit

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else {
            // Fallback to black color if hex is invalid
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let components = nsColor.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - String Extension
extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
    
    func highlighted(searchQuery: String) -> AttributedString {
        var attributed = AttributedString(self)
        
        guard !searchQuery.isEmpty else { return attributed }
        
        let lowercasedSelf = self.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        
        var searchStartIndex = lowercasedSelf.startIndex
        while let range = lowercasedSelf.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedSelf.endIndex) {
            let attributedRange = AttributedString.Index(range.lowerBound, within: attributed)!..<AttributedString.Index(range.upperBound, within: attributed)!
            attributed[attributedRange].backgroundColor = .yellow.opacity(0.3)
            attributed[attributedRange].foregroundColor = .primary
            searchStartIndex = range.upperBound
        }
        
        return attributed
    }
}

// MARK: - Date Extension
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    func formatted(style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - NSImage Extension
extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - Array Extension
extension Array where Element: Identifiable {
    @discardableResult
    mutating func moveToFront(_ element: Element) -> Bool {
        if let index = firstIndex(where: { $0.id == element.id }) {
            let item = remove(at: index)
            insert(item, at: 0)
            return true
        }
        return false
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let clipboardDidChange = Notification.Name("clipboardDidChange")
    static let showPopupWindow = Notification.Name("showPopupWindow")
    static let hidePopupWindow = Notification.Name("hidePopupWindow")
    static let showSettingsWindow = Notification.Name("showSettingsWindow")
    static let storageSaveFailed = Notification.Name("storageSaveFailed")
}
