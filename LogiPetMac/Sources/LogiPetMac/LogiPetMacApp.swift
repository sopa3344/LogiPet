import AppKit
import CoreText
import SwiftUI

@main
struct LogiPetMacApp: App {
    @NSApplicationDelegateAdaptor(LogiPetAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class LogiPetAppDelegate: NSObject, NSApplicationDelegate {
    private let model = PetModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerBundledFonts()
        NSApp.setActivationPolicy(.accessory)

        let size = NSSize(width: 252, height: 320)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "LogiPet - \(model.petName)"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: PetWindowView().environmentObject(model))
        window.setContentSize(size)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: visible.maxX - size.width - 14,
                y: visible.minY + 12
            ))
        }

        window.orderFrontRegardless()
        self.window = window
        model.attach(window: window)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}

enum FontRegistry {
    static func registerBundledFonts() {
        for name in ["Galmuri11", "NeoDunggeunmo"] {
            guard let url = ResourceLocator.url(
                forResource: name,
                withExtension: "ttf",
                subdirectory: "Resources/Fonts"
            ) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
