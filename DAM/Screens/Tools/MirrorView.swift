import SwiftUI
import AVFoundation

/// The accountability mirror: look yourself in the eye and read your affirmations out loud.
struct MirrorView: View {
    @Environment(AppModel.self) private var model
    @State private var camera = CameraController()
    @State private var cameraOn = true
    @State private var index = 0
    @State private var finished = false
    @State private var editing = false
    @State private var burst = 0

    private let color = Stat.discipline.color

    var body: some View {
        let list = model.data.affirmations.isEmpty ? Affirmations.defaults : model.data.affirmations
        let current = list[min(index, list.count - 1)]
        ScreenScroll(spacing: 18) {
            ToolHeader(title: "Mirror.", subtitle: "Look yourself in the eye. Say each line out loud like you mean it.", color: color)

            ZStack(alignment: .bottom) {
                Group {
                    if cameraOn && camera.authorized {
                        CameraPreview(session: camera.session)
                    } else {
                        ZStack {
                            Theme.card
                            SigilView(stage: model.snap.stage, theme: model.theme, size: 200)
                        }
                    }
                }
                .frame(height: 440)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .allowsHitTesting(false)

                VStack(spacing: 10) {
                    MonoLabel(finished ? "Done for today" : "\(min(index + 1, list.count)) of \(list.count)", color: color)
                    Text(finished ? "Now go prove it." : current)
                        .font(.serif(34))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .glow(radius: 10, opacity: 0.6)
                        .id(finished ? "done" : current)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .padding(24)
            }
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(color.opacity(0.6), lineWidth: 1.5))
            .shadow(color: color.opacity(0.35), radius: 14)
            .overlay { ParticleBurst(trigger: burst, colors: [color, .white], count: 34, spread: 200) }
            .animation(.spring(duration: 0.45), value: index)
            .animation(.spring(duration: 0.45), value: finished)

            if finished {
                Button("Again") {
                    index = 0
                    finished = false
                }
                .buttonStyle(NeonButtonStyle(color: color))
            } else {
                Button(index + 1 >= list.count ? (model.affirmedToday ? "Finish" : "Finish · +15 XP") : "I said it. Next") {
                    if index + 1 >= list.count {
                        finished = true
                        burst += 1
                        model.completeAffirmations()
                    } else {
                        index += 1
                        Feedback.tap()
                    }
                }
                .buttonStyle(NeonButtonStyle(color: color, filled: true))
            }

            HStack {
                Toggle("Camera", isOn: $cameraOn)
                    .toggleStyle(.switch)
                    .font(.ui(14))
                    .foregroundStyle(Theme.text2)
                    .fixedSize()
                Spacer()
                Button("Edit affirmations") { editing = true }
                    .font(.ui(14, .medium))
                    .foregroundStyle(color)
                    .buttonStyle(.plain)
            }
            if cameraOn && camera.denied {
                Text("Camera access is off. Enable it in Settings to use the mirror, or keep going without it.")
                    .font(.ui(12))
                    .foregroundStyle(Theme.text3)
            }
        }
        .transparentNavBar()
        .task(id: cameraOn) {
            if cameraOn { await camera.start() } else { camera.stop() }
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $editing) {
            AffirmationsEditor(list: list)
        }
    }
}

struct AffirmationsEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var list: [String]
    @State private var newLine = ""

    init(list: [String]) {
        _list = State(initialValue: list)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(list, id: \.self) { line in
                        Text(line)
                    }
                    .onDelete { list.remove(atOffsets: $0) }
                    .onMove { list.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Your affirmations")
                } footer: {
                    Text("Short, present tense, first person. \"I am…\", \"I do…\".")
                }
                Section {
                    HStack {
                        TextField("I am…", text: $newLine)
                        Button("Add") {
                            let t = newLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty && !list.contains(t) { list.append(t) }
                            newLine = ""
                        }
                        .disabled(newLine.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    Button("Restore defaults") { list = Affirmations.defaults }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Affirmations")
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.setAffirmations(list.isEmpty ? Affirmations.defaults : list)
                        dismiss()
                    }
                }
            }
        }
        .sheetSize(width: 520, height: 620)
    }
}

// MARK: - Camera

@MainActor
@Observable
final class CameraController {
    let session = AVCaptureSession()
    private(set) var authorized = false
    private(set) var denied = false
    @ObservationIgnored private var configured = false
    @ObservationIgnored private let queue = DispatchQueue(label: "dam.camera")

    func start() async {
        var granted = false
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        authorized = granted
        denied = !granted
        guard granted else { return }
        let session = self.session
        let needsConfig = !configured
        configured = true
        queue.async {
            if needsConfig {
                session.beginConfiguration()
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video)
                if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        let session = self.session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }
}

#if os(iOS)
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
#else
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = CALayer()
            previewLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}
}
#endif
