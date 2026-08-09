import AppKit
import ApplicationServices
import CoreBluetooth
import Foundation
import Network

struct MouseSample {
    var leftClicks = 0
    var rightClicks = 0
    var middleClicks = 0
    var wheelTurns = 0.0
    var movement = 0.0
}

final class MouseInputTracker {
    private let onSample: (MouseSample) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onSample: @escaping (MouseSample) -> Void) {
        self.onSample = onSample
    }

    func start(promptForPermission: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([key: promptForPermission] as CFDictionary)

        let types: [CGEventType] = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
            .tapDisabledByTimeout, .tapDisabledByUserInput
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<MouseInputTracker>.fromOpaque(userInfo).takeUnretainedValue()
                tracker.receive(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: opaque
        )
        guard let eventTap else { return trusted }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return trusted
    }

    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }

        var sample = MouseSample()
        switch type {
        case .leftMouseDown: sample.leftClicks = 1
        case .rightMouseDown: sample.rightClicks = 1
        case .otherMouseDown: sample.middleClicks = 1
        case .scrollWheel:
            sample.wheelTurns = abs(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let dx = event.getDoubleValueField(.mouseEventDeltaX)
            let dy = event.getDoubleValueField(.mouseEventDeltaY)
            sample.movement = hypot(dx, dy)
        default: break
        }
        onSample(sample)
    }
}

final class ActionCommandServer {
    private let onCommand: (String) -> Void
    private let queue = DispatchQueue(label: "LogiPet.ActionServer")
    private var listener: NWListener?

    init(onCommand: @escaping (String) -> Void) { self.onCommand = onCommand }

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: 29473)
            listener?.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            listener?.start(queue: queue)
        } catch {
            NSLog("LogiPet action server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            let command = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !command.isEmpty { self?.onCommand(command) }
        }
    }
}

final class MXBatteryReader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")
    private let onUpdate: (Int?, Bool) -> Void
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    init(onUpdate: @escaping (Int?, Bool) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }

    func start() { central = CBCentralManager(delegate: self, queue: .main) }
    func stop() { central?.stopScan() }
    func refresh() { if central?.state == .poweredOn { findMouse() } }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { onUpdate(nil, false); return }
        findMouse()
    }

    private func findMouse() {
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
        if let mouse = connected.first(where: { isMXMaster($0.name) }) ?? connected.first {
            connect(mouse)
        } else {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard isMXMaster(peripheral.name ?? advertised) else { return }
        central.stopScan()
        connect(peripheral)
    }

    private func connect(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        if peripheral.state == .connected {
            onUpdate(nil, true)
            peripheral.discoverServices([Self.batteryService])
        } else {
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onUpdate(nil, true)
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onUpdate(nil, false)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?.filter { $0.uuid == Self.batteryService }.forEach {
            peripheral.discoverCharacteristics([Self.batteryLevel], for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        service.characteristics?.filter { $0.uuid == Self.batteryLevel }.forEach {
            peripheral.readValue(for: $0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.batteryLevel,
              let first = characteristic.value?.first else { return }
        onUpdate(Int(first), true)
    }

    private func isMXMaster(_ name: String?) -> Bool {
        name?.localizedCaseInsensitiveContains("MX Master") == true
    }
}
