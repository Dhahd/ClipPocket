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
    
    override init(frame frameRect: NSRect) {
        imageView = NSImageView(frame: .zero)
        imageView.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        imageView.contentTintColor = .labelColor
        imageView.imageScaling = .scaleProportionallyDown
        
        super.init(frame: frameRect)
        
        addSubview(imageView)
        setupConstraints()
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
    
    override func mouseDown(with event: NSEvent) {
        delegate?.statusItemClicked()
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
