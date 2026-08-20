import AppKit
import CoreText
import QuartzCore
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

        if ProcessInfo.processInfo.environment["LOGIPET_RESOURCE_SMOKE_TEST"] == "1" {
            guard ResourceLocator.requiredResourcesAvailable else {
                FileHandle.standardError.write(Data("Required LogiPet resources are missing.\n".utf8))
                NSApp.terminate(nil)
                return
            }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSView(frame: .zero)
            window.orderFrontRegardless()
            self.window = window
            return
        }

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
        let hostingView = PixelHostingView(rootView: PetWindowView().environmentObject(model))
        window.contentView = hostingView
        window.setContentSize(size)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let desiredFrame = NSRect(origin: NSPoint(
                x: visible.maxX - size.width - 14,
                y: visible.minY + 12
            ), size: size)
            let alignedFrame = screen.backingAlignedRect(
                desiredFrame,
                options: [.alignAllEdgesNearest]
            )
            window.setFrame(alignedFrame, display: false)
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

final class PixelHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateBackingScale()
    }

    private func updateBackingScale() {
        wantsLayer = true
        layer?.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layerContentsRedrawPolicy = .onSetNeedsDisplay
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
