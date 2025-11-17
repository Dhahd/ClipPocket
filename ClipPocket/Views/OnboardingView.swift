import SwiftUI
import ServiceManagement
import UserNotifications

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var hasRequestedAccessibility = false
    @State private var hasRequestedNotifications = false

    let pages = [
        OnboardingPage(
            icon: "doc.on.clipboard.fill",
            title: "Welcome to ClipPocket",
            description: "Your powerful clipboard manager that remembers everything you copy",
            color: Color.blue,
            accentIcon: "sparkles"
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Smart Type Detection",
            description: "Automatically recognizes URLs, colors, code, files, images, JSON, emails, and more",
            color: Color.purple,
            accentIcon: "wand.and.stars"
        ),
        OnboardingPage(
            icon: "doc.on.doc.fill",
            title: "Copy Files & Images",
            description: "Copy file references from Finder and paste images seamlessly",
            color: Color.cyan,
            accentIcon: "photo.on.rectangle"
        ),
        OnboardingPage(
            icon: "pin.fill",
            title: "Pin Your Favorites",
            description: "Keep frequently used items always accessible at the top",
            color: Color.orange,
            accentIcon: "star.fill"
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            title: "Instant Search",
            description: "Find anything in your clipboard history with lightning-fast search",
            color: Color.green,
            accentIcon: "bolt.fill"
        ),
        OnboardingPage(
            icon: "command",
            title: "Keyboard Shortcuts",
            description: "Access ClipPocket instantly with ⌘⇧V and paste with quick actions",
            color: Color.indigo,
            accentIcon: "keyboard.fill"
        ),
        OnboardingPage(
            icon: "shield.lefthalf.filled",
            title: "Privacy First",
            description: "Everything stays on your Mac. Use incognito mode or exclude specific apps",
            color: Color.red,
            accentIcon: "lock.fill"
        ),
        OnboardingPage(
            icon: "arrow.down.circle.fill",
            title: "Auto Updates",
            description: "Stay up to date with automatic update checking and one-click installation",
            color: Color.teal,
            accentIcon: "checkmark.seal.fill"
        )
    ]

    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedGradientBackground(color: pages[min(currentPage, pages.count - 1)].color)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isActive: currentPage == index)
                            .tag(index)
                    }

                    // Permissions page
                    PermissionsPageView(
                        hasRequestedAccessibility: $hasRequestedAccessibility,
                        hasRequestedNotifications: $hasRequestedNotifications,
                        onComplete: {
                            completeOnboarding()
                        }
                    )
                    .tag(pages.count)
                }
                .frame(height: 420)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0...pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 8 : 6, height: currentPage == index ? 8 : 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 16)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage -= 1
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if currentPage < pages.count {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = pages.count
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(currentPage == pages.count - 1 ? "Finish" : "Next")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 700, height: 550)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isPresented = false
    }
}

struct AnimatedGradientBackground: View {
    let color: Color
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                color.opacity(0.4),
                color.opacity(0.2),
                color.opacity(0.1)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
        .onChange(of: color) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                animateGradient.toggle()
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let accentIcon: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = 0
    @State private var accentScale: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            // Main icon with accent
            ZStack {
                // Pulsing background circles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(page.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 140 + CGFloat(index * 25), height: 140 + CGFloat(index * 25))
                        .scaleEffect(isActive ? 1.0 : 0.8)
                        .opacity(isActive ? 0.3 : 0)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: isActive
                        )
                }

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                page.color.opacity(0.4),
                                page.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .blur(radius: 15)
                    .scaleEffect(scale)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                page.color.opacity(0.3),
                                page.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(scale)

                // Main icon
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(iconRotation))
                    .scaleEffect(scale)

                // Accent icon
                Image(systemName: page.accentIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(page.color)
                    .offset(x: 50, y: -50)
                    .scaleEffect(accentScale)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(opacity)

                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 50)
                    .opacity(opacity)
            }

            Spacer(minLength: 20)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .onChange(of: isActive) { newValue in
            if newValue {
                // Reset and animate in
                scale = 0.7
                opacity = 0
                iconRotation = -10
                accentScale = 0

                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }

                withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                    iconRotation = 0
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                    accentScale = 1.0
                }
            }
        }
        .onAppear {
            if isActive {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                    accentScale = 1.0
                }
            }
        }
    }
}

struct PermissionsPageView: View {
    @Binding var hasRequestedAccessibility: Bool
    @Binding var hasRequestedNotifications: Bool
    let onComplete: () -> Void

    @State private var accessibilityGranted = false
    @State private var notificationsGranted = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 20)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 10)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Text("Grant Permissions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(opacity)

                Text("ClipPocket needs a few permissions to work properly")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(opacity)
            }

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility Access",
                    description: "Required to monitor clipboard changes",
                    isGranted: accessibilityGranted,
                    color: .blue,
                    action: requestAccessibility
                )
                .opacity(opacity)

                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get notified about updates and clipboard actions",
                    isGranted: notificationsGranted,
                    color: .purple,
                    action: requestNotifications
                )
                .opacity(opacity)
            }
            .padding(.horizontal, 50)

            if accessibilityGranted && notificationsGranted {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        onComplete()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .scaleEffect(scale)
                .opacity(opacity)
            } else {
                Button("Continue Without Permissions") {
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 13))
                .opacity(opacity)
            }

            Spacer(minLength: 20)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .onAppear {
            checkPermissions()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func checkPermissions() {
        // Check accessibility
        accessibilityGranted = AXIsProcessTrusted()

        // Check notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    private func requestAccessibility() {
        hasRequestedAccessibility = true

        // First check if already granted
        if AXIsProcessTrusted() {
            accessibilityGranted = true
            return
        }

        // Open System Settings to Accessibility page
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)

        // Show alert to guide user
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
            System Settings will open to Accessibility permissions.

            Steps to grant permission:
            1. Click the lock icon and enter your password (if locked)
            2. Look for 'ClipPocket' in the list
            3. If ClipPocket is NOT in the list:
               • Click the '+' button at the bottom
               • Navigate to Applications and select ClipPocket
            4. Check the box next to ClipPocket to enable it

            Click 'Done' when you've enabled the permission.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Done")
            alert.addButton(withTitle: "I'll Do This Later")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Check if permission was granted
                if AXIsProcessTrusted() {
                    self.accessibilityGranted = true
                } else {
                    // Start checking periodically
                    self.startAccessibilityCheck()
                }
            }
        }
    }

    private func startAccessibilityCheck() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self.accessibilityGranted = true
                }
                timer.invalidate()
            }
        }
    }

    private func requestNotifications() {
        hasRequestedNotifications = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                notificationsGranted = granted
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.2) : color.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isGranted
                        ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if !isGranted {
                Button(action: action) {
                    Text("Grant")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(7)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isHovered = hovering
                    }
                }
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                    Text("Granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(isHovered && !isGranted ? 0.15 : 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovered && !isGranted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            if !isGranted {
                isHovered = hovering
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
    }
}
