import AppKit
import SwiftUI

private enum XP {
    static let face = Color(red: 236/255, green: 233/255, blue: 216/255)
    static let blue = Color(red: 0/255, green: 84/255, blue: 227/255)
    static let blueLight = Color(red: 60/255, green: 145/255, blue: 255/255)
    static let border = Color(red: 8/255, green: 49/255, blue: 217/255)
    static let shadow = Color(red: 172/255, green: 168/255, blue: 153/255)
    static let mint = Color(red: 45/255, green: 212/255, blue: 143/255)
    static let balloon = Color(red: 1, green: 1, blue: 225/255)
}

struct PetWindowView: View {
    @EnvironmentObject private var model: PetModel
    @State private var renamePresented = false
    @State private var draftName = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            mainWindow
                .frame(width: 242, height: 220)
                .padding(5)

            if model.balloonVisible {
                SpeechBalloon(name: model.petName, text: model.balloonText) {
                    model.balloonVisible = false
                } showActivity: {
                    model.balloonVisible = false
                    model.showStats = true
                }
                .offset(y: -220)
                .transition(.opacity)
                .zIndex(5)
            }

            if model.showStats {
                StatsPanel()
                    .frame(width: 242, height: 220)
                    .padding(5)
                    .zIndex(8)
            }
        }
        .frame(width: 252, height: 320, alignment: .bottom)
        .animation(.easeOut(duration: 0.14), value: model.balloonVisible)
        .alert("강아지 이름", isPresented: $renamePresented) {
            TextField("이름", text: $draftName)
            Button("저장") { model.setPetName(draftName) }
            Button("취소", role: .cancel) { }
        } message: {
            Text("MX의 친구를 뭐라고 부를까요? 최대 8글자까지 저장돼요.")
        }
    }

    private var mainWindow: some View {
        VStack(spacing: 0) {
            titleBar
            VStack(spacing: 3) {
                BatteryGroup()
                    .frame(height: 59)
                petArea
                    .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 7)
            .padding(.top, 3)
            .padding(.bottom, 2)
            .background(XP.face)
            statusBar
        }
        .overlay(Rectangle().stroke(XP.border, lineWidth: 2))
        .background(XP.face)
        .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: -2)
    }

    private var titleBar: some View {
        HStack(spacing: 5) {
            PixelDogIcon().frame(width: 16, height: 16)
            Text("LogiPet - \(model.petName)")
                .font(.custom("Galmuri11", size: 11).weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Button("×") { NSApp.terminate(nil) }
                .buttonStyle(XPTitleButtonStyle())
        }
        .padding(.horizontal, 5)
        .frame(height: 28)
        .background(LinearGradient(colors: [XP.blueLight, XP.blue], startPoint: .top, endPoint: .bottom))
    }

    private var petArea: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(.black.opacity(0.2)).frame(width: 82, height: 10).offset(y: -3)
            PetSpriteView(animation: model.animation, frame: model.frame, facing: model.facing)
                .frame(width: 200, height: 66)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { model.talk() }
                .contextMenu {
                    Button("\(model.petName)에게 말 걸기") { model.talk() }
                    Divider()
                    Button("간식으로 축하") { model.perform("snack") }
                    Button("물 주기") { model.perform("water") }
                    Button("하이파이브") { model.perform("highfive") }
                    Button("같이 스트레칭") { model.perform("stretch") }
                    Button("잠깐 놀기") { model.perform("play") }
                    Divider()
                    Button("오늘 활동") { model.perform("journal") }
                    Button("이름 바꾸기…") {
                        draftName = model.petName
                        renamePresented = true
                    }
                }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 4) {
            Text("L")
                .font(.custom("Galmuri11", size: 7).weight(.bold))
                .frame(width: 11, height: 11)
                .background(model.batteryConnected ? XP.mint : Color.orange)
                .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
            Text(model.batteryConnected ? "MX 연결됨" : "MX 연결 대기")
            Text("·").foregroundStyle(.secondary)
            Text(model.activity.label).foregroundStyle(XP.blue)
                .lineLimit(1)
            Spacer(minLength: 2)
            Divider().frame(height: 14)
            Text(model.clockText).help(model.dateText)
        }
        .font(.custom("Galmuri11", size: 9))
        .padding(.horizontal, 4)
        .frame(height: 22)
        .background(XP.face)
        .overlay(Rectangle().stroke(XP.shadow, lineWidth: 1))
    }
}

private struct BatteryGroup: View {
    @EnvironmentObject private var model: PetModel

    var body: some View {
        XPGroupBox(title: "MX Master 4") {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text("🔋").font(.system(size: 12))
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white)
                            Rectangle().fill(batteryColor).frame(width: geometry.size.width * CGFloat(model.batteryLevel ?? 0) / 100)
                        }
                        .overlay(Rectangle().stroke(XP.shadow, lineWidth: 1))
                    }
                    .frame(height: 13)
                    Text(model.batteryText)
                        .font(.custom("Galmuri11", size: 11).weight(.bold))
                        .foregroundStyle(batteryColor)
                }
                Text(model.speech)
                    .font(.custom("NeoDunggeunmo", size: 10))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .frame(height: 19)
                    .background(.white)
                    .overlay(Rectangle().stroke(XP.shadow, lineWidth: 1))
            }
        }
    }

    private var batteryColor: Color {
        switch model.batteryLevel ?? 0 {
        case 60...: XP.mint
        case 25...: .orange
        default: .red
        }
    }
}

private struct XPGroupBox<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            content.padding(.horizontal, 7).padding(.top, 9).padding(.bottom, 5)
                .overlay(Rectangle().stroke(XP.shadow, lineWidth: 1))
                .padding(.top, 6)
            Text(title)
                .font(.custom("Galmuri11", size: 9))
                .padding(.horizontal, 4)
                .background(XP.face)
                .padding(.leading, 8)
        }
    }
}

private struct SpeechBalloon: View {
    let name: String
    let text: String
    let close: () -> Void
    let showActivity: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).foregroundStyle(Color(red: 0, green: 51/255, blue: 153/255)).fontWeight(.bold)
                    Spacer()
                    Button("×", action: close).buttonStyle(.plain)
                }
                Text(text).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Button("오늘 활동 보기 ▶", action: showActivity)
                    .buttonStyle(.plain).foregroundStyle(.blue).underline()
            }
            .font(.custom("NeoDunggeunmo", size: 10))
            .padding(8)
            .frame(width: 218, alignment: .leading)
            .background(XP.balloon)
            .overlay(Rectangle().stroke(.black, lineWidth: 1))
            Triangle().fill(XP.balloon).frame(width: 18, height: 9)
                .overlay(Triangle().stroke(.black, lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: -2)
    }
}

private struct StatsPanel: View {
    @EnvironmentObject private var model: PetModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("▦  \(model.petName) 상태").foregroundStyle(.white).fontWeight(.bold)
                Spacer()
                Button("×") { model.showStats = false }.buttonStyle(XPTitleButtonStyle())
            }
            .font(.custom("Galmuri11", size: 11))
            .padding(.horizontal, 5).frame(height: 28)
            .background(LinearGradient(colors: [XP.blueLight, XP.blue], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Date().formatted(.dateTime.month().day())).fontWeight(.bold)
                    Spacer()
                    Text("macOS 입력 · 로컬 저장").font(.custom("Galmuri11", size: 8)).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    StatCard(title: "왼쪽 클릭", value: "\(model.state.leftClicks.formatted())번")
                    StatCard(title: "오른쪽 클릭", value: "\(model.state.rightClicks.formatted())번")
                }
                HStack(spacing: 5) {
                    StatCard(title: "휠 클릭", value: "\(model.state.middleClicks.formatted())번")
                    StatCard(title: "Actions Ring", value: "\(model.state.actionRingActions.formatted())번", accent: true)
                }
                StatCard(title: "휠 회전", value: "\(Int(model.state.wheelTurns).formatted())회")
                if !model.inputPermissionGranted {
                    Text("클릭 통계를 위해 시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용에서 LogiPet을 허용해 주세요.")
                        .font(.custom("NeoDunggeunmo", size: 8)).foregroundStyle(.red).lineLimit(2)
                }
            }
            .font(.custom("Galmuri11", size: 9))
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(XP.face)
        }
        .overlay(Rectangle().stroke(XP.border, lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 0, x: 2, y: -2)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).foregroundStyle(.secondary).font(.custom("Galmuri11", size: 8))
            Text(value).font(.custom("Galmuri11", size: 13).weight(.bold)).foregroundStyle(accent ? XP.mint : Color.primary)
        }
        .padding(5).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white).overlay(Rectangle().stroke(XP.shadow, lineWidth: 1))
    }
}

private struct XPTitleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(configuration.isPressed ? Color.red.opacity(0.75) : Color(red: 0.9, green: 0.25, blue: 0.12))
            .overlay(Rectangle().stroke(.white.opacity(0.8), lineWidth: 1))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct PixelDogIcon: View {
    var body: some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 3, y: 6, width: 10, height: 7)), with: .color(Color(red: 201/255, green: 130/255, blue: 53/255)))
            context.fill(Path(CGRect(x: 9, y: 3, width: 5, height: 5)), with: .color(Color(red: 217/255, green: 154/255, blue: 78/255)))
            context.fill(Path(CGRect(x: 13, y: 5, width: 1, height: 1)), with: .color(.black))
            context.fill(Path(CGRect(x: 9, y: 8, width: 5, height: 1)), with: .color(XP.mint))
            context.fill(Path(CGRect(x: 4, y: 12, width: 2, height: 3)), with: .color(.brown))
            context.fill(Path(CGRect(x: 10, y: 12, width: 2, height: 3)), with: .color(.brown))
        }
    }
}

private struct PetSpriteView: View {
    let animation: String
    let frame: Int
    let facing: CGFloat

    var body: some View {
        let sprite = SpriteSheet.frame(animation: animation, index: frame)
        Image(nsImage: sprite.image)
            .interpolation(.none)
            .resizable()
            .frame(width: 200, height: 200)
            .scaleEffect(x: facing, y: 1)
            .offset(x: facing * (50 - sprite.centerX) * 2)
    }
}

private struct SpriteFrame {
    let image: NSImage
    let centerX: CGFloat
}

private enum SpriteSheet {
    private static var cache: [String: SpriteFrame] = [:]

    static func frame(animation: String, index: Int) -> SpriteFrame {
        let key = "\(animation):\(index)"
        if let cached = cache[key] { return cached }
        guard let url = Bundle.module.url(
            forResource: "Golden-Retriever-\(animation)",
            withExtension: "png",
            subdirectory: "Resources/Pets/GoldenRetriever"
        ), let sheet = NSImage(contentsOf: url),
           let cg = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let cropped = cg.cropping(to: CGRect(x: index * 100, y: 0, width: 100, height: 100)) else {
            return SpriteFrame(image: NSImage(size: NSSize(width: 100, height: 100)), centerX: 50)
        }
        let image = NSImage(cgImage: cropped, size: NSSize(width: 100, height: 100))
        let value = SpriteFrame(image: image, centerX: opaqueCenter(cropped))
        cache[key] = value
        return value
    }

    private static func opaqueCenter(_ image: CGImage) -> CGFloat {
        let bitmap = NSBitmapImageRep(cgImage: image)
        var minX = image.width
        var maxX = -1
        for y in 0..<image.height {
            for x in 0..<image.width where bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.02 {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }
        return maxX >= minX ? CGFloat(minX + maxX) / 2 : 50
    }
}
