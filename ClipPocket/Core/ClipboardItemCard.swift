//
//  ClipboardItemCard.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit


struct ClipboardItemCard: View {
    @EnvironmentObject var appDelegate: AppDelegate

    let item: ClipboardItem
    @State private var headerColor: Color = .blue
    @State private var isHovered: Bool = false
    @State private var mouseLocation: CGPoint = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            HStack(spacing: 0) {
                if let sourceIcon = item.sourceIcon {
                    Image(nsImage: sourceIcon)
                        .resizable()
                        .offset(x: -10)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 55)
                        .clipped()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.typeDisplayName)
                        .font(.system(size: 14, weight: .bold))
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 12, weight: .thin))
                }
                .padding(.trailing, 12)
            }
            .frame(height: 48)
            .foregroundColor(.white)
            .background(
                ZStack {
                    headerColor

                    // Glass overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            
            // Content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 240, height: 180)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Mouse-following shimmer effect
                if isHovered {
                    LiquidGlassCardShimmer(mouseLocation: mouseLocation)
                }
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isHovered ? 0.4 : 0.2),
                            Color.white.opacity(isHovered ? 0.2 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0), radius: 16, x: 0, y: 8)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .rotation3DEffect(
            .degrees(isHovered ? calculateTiltAngle() : 0),
            axis: calculateTiltAxis(),
            perspective: 0.5
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        .animation(.interpolatingSpring(stiffness: 200, damping: 15), value: mouseLocation)
        .onHover { hovering in
            isHovered = hovering
        }
        .background(
            GeometryReader { geometry in
                MouseTrackingView { location in
                    // Convert to local coordinates
                    self.mouseLocation = location
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        )
        .onAppear {
            if let sourceIcon = item.sourceIcon {
                headerColor = Color(vibrantColorFrom: sourceIcon)
            }
        }
    }

    // Calculate gooey tilt angle based on mouse position
    private func calculateTiltAngle() -> Double {
        let centerX: CGFloat = 120 // Half of card width (240/2)
        let centerY: CGFloat = 90  // Half of card height (180/2)

        let deltaX = mouseLocation.x - centerX
        let deltaY = mouseLocation.y - centerY

        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        return min(distance / 10, 5) // Max 5 degrees tilt
    }

    // Calculate tilt axis for gooey effect
    private func calculateTiltAxis() -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        let centerX: CGFloat = 120
        let centerY: CGFloat = 90

        let deltaX = mouseLocation.x - centerX
        let deltaY = mouseLocation.y - centerY

        // Normalize and invert for natural tilt direction
        let axisX = deltaY / 90
        let axisY = -deltaX / 120

        return (x: axisX, y: axisY, z: 0)
    }

    @ViewBuilder
    var codeView: some View {
        SyntaxHighlightedCodeView(code: item.displayString, sourceIDE: determineSourceIDE(item))
        }
    func determineSourceIDE(_ item: ClipboardItem) -> SourceIDE {
        if (item.displayString.contains("xcode")) {
            return .xcode
        }
        else {
            return .androidStudio
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch item.type {
        case .text:
            Text(item.displayString)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.8))
                .padding(12)
        case .code:
            codeView
        case .url:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                Text(item.displayString)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .email:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.cyan)
                Text(item.displayString)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .phone:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                Text(item.displayString)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .json:
            ScrollView {
                Text(item.displayString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.8))
                    .padding(12)
            }
        case .image:
            if let imageData = item.content as? Data,
               let nsImage = NSImage(data: imageData) {
                GeometryReader { geometry in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width - 24, maxHeight: geometry.size.height - 24)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(12)
                }
            }
        case .color:
            if let colorString = item.content as? String {
                let color = Color(colorString)
                ZStack {
                    color
                    Text(colorString)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color.contrastingTextColor(colorString))
                }
            }
        }
    }
}


class ClipboardItemWrapper: NSObject, NSItemProviderWriting, NSItemProviderReading {
    static var writableTypeIdentifiersForItemProvider: [String] {
            return [UTType.utf8PlainText.identifier, UTType.image.identifier]
        }
        
        static var readableTypeIdentifiersForItemProvider: [String] {
            return [UTType.utf8PlainText.identifier, UTType.image.identifier]
        }
        
        let item: ClipboardItem
        
        required init(_ item: ClipboardItem) {
            self.item = item
            super.init()
        }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {

        switch item.type {
        case .text, .code, .color, .url, .email, .phone, .json:
            if typeIdentifier == UTType.utf8PlainText.identifier,
               let stringContent = item.content as? String,
               let data = stringContent.data(using: .utf8) {
                completionHandler(data, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        case .image:
            if typeIdentifier == UTType.image.identifier,
               let imageData = item.content as? Data {
                completionHandler(imageData, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        }
        return nil
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
            let content: Any
            let type: ClipboardItem.ItemType
            if typeIdentifier == UTType.utf8PlainText.identifier {
                guard let string = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "ClipboardItemError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode text data"])
                }
                content = string
                type = .text // You might want to determine if it's .code or .color based on the content
            } else if typeIdentifier == UTType.image.identifier {
                content = data
                type = .image
            } else {
                throw NSError(domain: "ClipboardItemError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported type identifier"])
            }
            
            let clipboardItem = ClipboardItem(content: content, type: type, timestamp: Date(), sourceApplication: nil)
            return self.init(clipboardItem)
        }
}

// Gooey liquid effect for card hover state
struct LiquidGlassCardShimmer: View {
    let mouseLocation: CGPoint

    var body: some View {
        GeometryReader { geometry in
            let normalizedX = max(0, min(1, mouseLocation.x / geometry.size.width))
            let normalizedY = max(0, min(1, 1 - (mouseLocation.y / geometry.size.height))) // Invert Y

            ZStack {
                // Main gooey spotlight - barely noticeable
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.03),
                        Color.white.opacity(0.01),
                        Color.clear
                    ],
                    center: UnitPoint(x: normalizedX, y: normalizedY),
                    startRadius: 0,
                    endRadius: 60
                )

                // Secondary blob for gooey effect - very subtle
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.015),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: normalizedX + 0.05,
                        y: normalizedY - 0.05
                    ),
                    startRadius: 0,
                    endRadius: 40
                )
                .blur(radius: 8)
            }
            .blur(radius: 4) // Overall blur for gooey effect
        }
        .allowsHitTesting(false)
    }
}

// Mouse tracking view to capture mouse movements
struct MouseTrackingView: NSViewRepresentable {
    var onMouseMoved: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingNSView()
        view.onMouseMoved = onMouseMoved
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let trackingView = nsView as? MouseTrackingNSView {
            trackingView.onMouseMoved = onMouseMoved
        }
    }
}

class MouseTrackingNSView: NSView {
    var onMouseMoved: ((CGPoint) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeAlways,
            .mouseMoved,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onMouseMoved?(location)
    }

    override func mouseEntered(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onMouseMoved?(location)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onMouseMoved?(location)
    }
}

