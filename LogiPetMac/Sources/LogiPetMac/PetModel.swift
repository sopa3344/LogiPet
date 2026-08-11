import AppKit
import Combine
import Foundation

enum CompanionActivity: String, Codable {
    case waiting, walking, running, sitting, resting, sleeping

    var label: String {
        switch self {
        case .walking: "함께 걷는 중"
        case .running: "신나게 달리는 중"
        case .sitting: "옆에서 기다리는 중"
        case .resting: "함께 쉬는 중"
        case .sleeping: "자리를 지키는 중"
        case .waiting: "곁에 있는 중"
        }
    }
}

struct DailyState: Codable {
    var date = Self.todayKey
    var leftClicks = 0
    var rightClicks = 0
    var middleClicks = 0
    var actionRingActions = 0
    var wheelTurns = 0.0

    static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    mutating func ensureToday() {
        guard date != Self.todayKey else { return }
        self = DailyState()
    }
}

@MainActor
final class PetModel: ObservableObject {
    @Published var petName = UserDefaults.standard.string(forKey: "petName") ?? "맥스"
    @Published var state = DailyState()
    @Published var batteryLevel: Int?
    @Published var batteryConnected = false
    @Published var speech = "맥스, 준비 중…"
    @Published var balloonText = "안녕! 오늘도 옆에 있을게."
    @Published var balloonVisible = false
    @Published var showStats = false
    @Published var activity: CompanionActivity = .waiting
    @Published var animation = "idle"
    @Published var frame = 0
    @Published var facing: CGFloat = 1
    @Published var now = Date()
    @Published var inputPermissionGranted = false

    private weak var window: NSWindow?
    private var inputTracker: MouseInputTracker?
    private var batteryReader: MXBatteryReader?
    private var actionServer: ActionCommandServer?
    private var activityTimer: Timer?
    private var spriteTimer: Timer?
    private var balloonTimer: Timer?
    private var lastInput = Date.distantPast
    private var recentMotion = 0.0
    private var recentClicks = 0
    private var talkIndex = 0
    private var animationLocked = false

    private let animationFrames: [String: Int] = [
        "idle": 10, "walk": 8, "run": 8, "bark": 3,
        "licking1": 4, "licking2": 4, "itching": 2,
        "lying-down": 7, "stretching": 10, "sitting": 1, "sleeping": 1
    ]

    var totalClicks: Int { state.leftClicks + state.rightClicks + state.middleClicks }
    var clockText: String { now.formatted(.dateTime.hour().minute()) }
    var dateText: String { now.formatted(.dateTime.year().month().day().weekday(.wide)) }
    var batteryText: String { batteryLevel.map { "\($0)%" } ?? "--%" }

    func attach(window: NSWindow) {
        self.window = window
        window.title = "LogiPet - \(petName)"
    }

    func setPetName(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let value = String(trimmed.prefix(8))
        petName = value
        UserDefaults.standard.set(value, forKey: "petName")
        window?.title = "LogiPet - \(value)"
        say("이제 내 이름은 \(value)야! 잘 부탁해.")
    }

    func openCommunity() {
        guard let url = URL(string: "https://mx-community.com/") else { return }
        if NSWorkspace.shared.open(url) {
            speech = "MX 사용자들의 활용법을 구경하러 가자!"
            balloonVisible = false
        } else {
            say("브라우저를 열지 못했어. 잠시 후 다시 눌러 줘.")
        }
    }

    func start() {
        loadState()
        speech = "\(petName), 준비 중…"
        inputTracker = MouseInputTracker { [weak self] sample in
            Task { @MainActor in self?.record(sample) }
        }
        inputPermissionGranted = inputTracker?.start(promptForPermission: true) ?? false

        batteryReader = MXBatteryReader { [weak self] level, connected in
            Task { @MainActor in
                self?.batteryLevel = level
                self?.batteryConnected = connected
            }
        }
        batteryReader?.start()

        actionServer = ActionCommandServer { [weak self] command in
            Task { @MainActor in self?.handle(command: command) }
        }
        actionServer?.start()

        activityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        say(contextualPhrase())
    }

    func stop() {
        inputTracker?.stop()
        actionServer?.stop()
        batteryReader?.stop()
        activityTimer?.invalidate()
        spriteTimer?.invalidate()
        balloonTimer?.invalidate()
        saveState()
    }

    func talk() {
        say(contextualPhrase())
        play("bark", interval: 0.15, locked: true)
    }

    func perform(_ command: String) {
        switch command {
        case "snack", "feed": sayAndPlay("좋아, 간식으로 축하하자! 냠냠!", "licking1", 0.14)
        case "water": sayAndPlay("물 한 모금 마시고 다시 같이 가자!", "licking2", 0.145)
        case "highfive": sayAndPlay("하이파이브! 오늘도 같이 가자!", "bark", 0.15)
        case "come": sayAndPlay("불렀어? 바로 왔어!", "walk", 0.12)
        case "zoomies", "play": sayAndPlay("갑자기 신나졌어! 제자리에서 달린다!", "run", 0.085)
        case "speak": sayAndPlay("멍! 오늘도 옆에 있을게.", "bark", 0.15)
        case "sit": sayAndPlay("얌전히 앉아서 기다릴게.", "sitting", 1.4)
        case "lie": sayAndPlay("여기서 편하게 쉬고 있을게.", "lying-down", 0.155)
        case "nap": sayAndPlay("잠깐 눈만 붙일게… zZ", "sleeping", 2.2)
        case "scratch": sayAndPlay("간질간질! 한 번 긁고 갈게.", "itching", 0.22)
        case "stretch", "sleep": sayAndPlay("좋아, 같이 한 번 쭉—!", "stretching", 0.11)
        case "journal", "status": showStats = true; say("오늘 우리 발자국을 모아 봤어.")
        case "battery": batteryReader?.refresh()
        default: break
        }
    }

    private func handle(command: String) {
        let counted = ["snack", "water", "highfive", "stretch", "play", "come", "zoomies",
                       "speak", "sit", "lie", "nap", "scratch", "journal", "feed", "sleep", "status"]
        if counted.contains(command) {
            state.ensureToday()
            state.actionRingActions += 1
        }
        perform(command)
        saveState()
    }

    private func record(_ sample: MouseSample) {
        state.ensureToday()
        state.leftClicks += sample.leftClicks
        state.rightClicks += sample.rightClicks
        state.middleClicks += sample.middleClicks
        state.wheelTurns += abs(sample.wheelTurns)
        recentMotion += sample.movement
        recentClicks += sample.leftClicks + sample.rightClicks + sample.middleClicks
        lastInput = Date()
        updateFacing()
    }

    private func tick() {
        now = Date()
        state.ensureToday()
        let idle = Date().timeIntervalSince(lastInput)
        let intensity = recentMotion + Double(recentClicks * 80)
        let next: CompanionActivity
        switch idle {
        case 600...: next = .sleeping
        case 120...: next = .resting
        case 12...: next = .sitting
        case 3...: next = .waiting
        default: next = intensity >= 320 ? .running : .walking
        }
        if next != activity {
            activity = next
            applyActivityAnimation()
        }
        recentMotion *= 0.2
        recentClicks = 0
        updateFacing()
        if Int(now.timeIntervalSince1970) % 15 == 0 { saveState() }
    }

    private func updateFacing() {
        guard let window else { return }
        let mouseX = NSEvent.mouseLocation.x
        facing = mouseX < window.frame.midX ? -1 : 1
    }

    private func applyActivityAnimation() {
        guard !animationLocked else { return }
        switch activity {
        case .running: play("run", interval: 0.088)
        case .walking: play("walk", interval: 0.12)
        case .sitting: play("sitting", interval: 0.5)
        case .resting: play("lying-down", interval: 0.155, repeatAnimation: false)
        case .sleeping: play("sleeping", interval: 0.5)
        case .waiting: play("idle", interval: 0.145)
        }
    }

    private func sayAndPlay(_ text: String, _ name: String, _ interval: TimeInterval) {
        say(text)
        play(name, interval: interval, repeatAnimation: false, locked: true)
    }

    private func play(_ name: String, interval: TimeInterval, repeatAnimation: Bool = true, locked: Bool = false) {
        spriteTimer?.invalidate()
        animation = name
        frame = 0
        animationLocked = locked
        let count = animationFrames[name] ?? 1
        guard count > 1 || locked else { return }
        spriteTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if self.frame + 1 < count {
                    self.frame += 1
                } else if repeatAnimation {
                    self.frame = 0
                } else {
                    timer.invalidate()
                    self.animationLocked = false
                    self.applyActivityAnimation()
                }
            }
        }
    }

    private func say(_ text: String) {
        speech = text
        balloonText = text
        balloonVisible = true
        balloonTimer?.invalidate()
        balloonTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.balloonVisible = false }
        }
    }

    private func contextualPhrase() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let period: String
        switch hour {
        case 5..<11: period = "좋은 아침! 천천히 오늘을 시작하자."
        case 11..<14: period = "점심때네. 손도 잠깐 쉬어 가자."
        case 14..<18: period = "오후도 나란히 같이 가는 중이야."
        case 18..<22: period = "오늘 하루도 거의 다 왔어. 조금만 더 같이 가자."
        default: period = "늦은 시간이야. 너무 무리하지는 말자."
        }
        let phrases = [
            "\(clockText)이야. \(period)",
            totalClicks > 0
                ? "오늘 클릭을 \(totalClicks.formatted())번 했어. 나는 여기서 같이 걷고 있었어!"
                : "아직 오늘의 첫 클릭을 기다리는 중이야. 천천히 시작하자!",
            state.wheelTurns >= 1
                ? "오늘 휠을 약 \(Int(state.wheelTurns).formatted())바퀴 굴렸어. 꽤 멀리 함께 왔네!"
                : "마우스를 움직일 때마다 나도 제자리에서 함께 걷고 있어.",
            "다른 MX 사용자들은 어떻게 쓰는지 궁금해? 커뮤니티에서 활용법을 구경해 봐!"
        ]
        defer { talkIndex += 1 }
        return phrases[talkIndex % phrases.count]
    }

    private static var stateURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LogiPet/state.json")
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: Self.stateURL),
              var saved = try? JSONDecoder().decode(DailyState.self, from: data) else { return }
        saved.ensureToday()
        state = saved
    }

    private func saveState() {
        let url = Self.stateURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
