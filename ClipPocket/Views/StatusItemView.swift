//
//  StatusItemView.swift
//  ClipPocket
//
//  Created by Shaneen on 10/15/24.
//

import Cocoa

class StatusItemView: NSView {
    private let imageView: NSImageView
    weak var delegate: StatusItemViewDelegate?
    private var isHighlighted = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        imageView = NSImageView(frame: .zero)
        imageView.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        imageView.contentTintColor = .labelColor
        imageView.imageScaling = .scaleProportionallyDown

        super.init(frame: frameRect)

        addSubview(imageView)
        setupConstraints()
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.6)
        ])
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        setHighlighted(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHighlighted(false)
    }

    override func mouseDown(with event: NSEvent) {
        setHighlighted(true)
        delegate?.statusItemClicked()
    }

    override func mouseUp(with event: NSEvent) {
        // Check if mouse is still inside bounds
        let locationInView = convert(event.locationInWindow, from: nil)
        setHighlighted(bounds.contains(locationInView))
    }

    private func setHighlighted(_ highlighted: Bool) {
        guard isHighlighted != highlighted else { return }
        isHighlighted = highlighted

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true

            if highlighted {
                // Darken background and scale down slightly
                self.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).cgColor
                self.imageView.animator().alphaValue = 0.7
            } else {
                // Reset to normal
                self.layer?.backgroundColor = NSColor.clear.cgColor
                self.imageView.animator().alphaValue = 1.0
            }
        }
    }

    override var wantsLayer: Bool {
        get { return true }
        set { }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        delegate?.statusItemRightClicked()
    }
    
    func startAnimation() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            
            self.imageView.animator().frameCenterRotation = 10
            self.imageView.animator().setFrameSize(NSSize(width: self.bounds.width * 1.2, height: self.bounds.height * 1.2))
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                
                self.imageView.animator().frameCenterRotation = 0
                self.imageView.animator().setFrameSize(self.bounds.size)
            })
        })
    }
}

protocol StatusItemViewDelegate: AnyObject {
    func statusItemClicked()
    func statusItemRightClicked()
}
