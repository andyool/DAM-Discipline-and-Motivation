import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(SyncService.self) private var sync

    @State private var exporting = false
    @State private var importing = false
    @State private var pickingFolder = false
    @State private var exportDoc: BackupDocument? = nil
    @State private var confirmReset = false
    @State private var resetText = ""
    @State private var newProgram = false
    @State private var message: String? = nil
    @State private var notificationsAllowed = true

    var body: some View {
        let s = model.settings
        Form {
            Section {
                TextField("Name", text: Binding(get: { model.profile.name }, set: { v in model.updateProfile { $0.name = v } }))
                Picker("Evolution path", selection: Binding(get: { model.theme }, set: { v in model.updateProfile { $0.theme = v } })) {
                    ForEach(EvolutionTheme.allCases) { Text($0.name).tag($0) }
                }
                DatePicker("Wake-up time", selection: Binding(get: { date(minutes: model.profile.wakeMinutes) },
                                                             set: { v in model.updateProfile { $0.wakeMinutes = minutes(of: v) } }),
                           displayedComponents: .hourAndMinute)
            } header: {
                Text("You")
            } footer: {
                Text("Wake-up time is used when a new program is built.")
            }

            Section {
                Picker("Streak counts when you complete", selection: binding(\.streakRule)) {
                    ForEach(StreakRule.allCases) { Text($0.name).tag($0) }
                }
                Toggle("Hardcore mode", isOn: binding(\.hardcore))
                    .tint(Stat.physical.color)
            } header: {
                Text("Rules")
            } footer: {
                Text("Every 7-day streak earns a shield (max 2) that saves you from one missed day. Hardcore mode costs 10 XP per task left undone on a missed day.")
            }

            Section {
                Toggle("Sounds", isOn: binding(\.soundOn))
                    .tint(Stat.physical.color)
                Toggle("Haptics", isOn: binding(\.hapticsOn))
                    .tint(Stat.physical.color)
            } header: {
                Text("Feedback")
            }

            Section {
                Toggle("Morning lock-in", isOn: binding(\.morningReminder))
                    .tint(Stat.physical.color)
                if s.morningReminder {
                    DatePicker("Time", selection: minutesBinding(\.morningMinutes), displayedComponents: .hourAndMinute)
                }
                Toggle("Evening check-in", isOn: binding(\.eveningReminder))
                    .tint(Stat.physical.color)
                if s.eveningReminder {
                    DatePicker("Time", selection: minutesBinding(\.eveningMinutes), displayedComponents: .hourAndMinute)
                }
                if !notificationsAllowed {
                    Button("Allow notifications") {
                        Task {
                            notificationsAllowed = await Reminders.requestAuthorization()
                            await Reminders.reschedule(model)
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Per-task reminders are set when you edit a task.")
            }

            Section {
                Stepper("Calories: \(s.calorieGoal.grouped)", value: binding(\.calorieGoal), in: 1000...6000, step: 50)
                Stepper("Protein: \(s.proteinGoal) g", value: binding(\.proteinGoal), in: 30...400, step: 5)
                Stepper("Water: \(s.waterGoal) glasses", value: binding(\.waterGoal), in: 1...20)
                Picker("Weight unit", selection: binding(\.weightUnit)) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Fuel & lift")
            }

            Section {
                if let p = model.data.program {
                    LabeledContent("Current", value: "#\(p.number) · \(p.intensity.name)\(p.ended ? " · done" : "")")
                }
                Button("Start a new 60-day program…") { newProgram = true }
            } header: {
                Text("Program")
            }

            Section {
                if let folder = sync.folderName {
                    LabeledContent("Folder", value: folder)
                    if let last = sync.lastSync {
                        LabeledContent("Last synced", value: last.formatted(date: .omitted, time: .shortened))
                    }
                    Button(sync.syncing ? "Syncing…" : "Sync now") { Task { await sync.sync(model) } }
                        .disabled(sync.syncing)
                    Button("Stop syncing", role: .destructive) { sync.disconnect(model) }
                } else {
                    Button("Choose sync folder…") { pickingFolder = true }
                }
                if let error = sync.lastError {
                    Text(error).font(.ui(12)).foregroundStyle(Stat.discipline.color)
                }
            } header: {
                Text("Sync iPhone ↔ Mac")
            } footer: {
                Text("Free sync with no developer account needed: create a folder in iCloud Drive (e.g. \"DAM\") and choose that same folder here on every device. DAM merges changes from both sides.")
            }

            Section {
                Button("Export backup…") {
                    if let data = try? model.exportData() {
                        exportDoc = BackupDocument(data: data)
                        exporting = true
                    }
                }
                Button("Import backup…") { importing = true }
                if let message {
                    Text(message).font(.ui(12)).foregroundStyle(Theme.text2)
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Everything is stored on this device. DAM also keeps 7 days of automatic backups. Importing merges the backup with what's here.")
            }

            Section {
                Button("Reset everything", role: .destructive) { confirmReset = true }
            } footer: {
                Text("DAM. Discipline & Motivation · free and offline. Fonts: Instrument Serif (SIL OFL).")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Settings")
        .transparentNavBar()
        .task { notificationsAllowed = await Reminders.isAuthorized() }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: "DAM-backup-\(model.today)") { result in
            if case .success = result { message = "Backup exported." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try model.importData(data, merge: true)
                message = "Backup imported and merged."
            } catch {
                message = "That file couldn't be read as a DAM backup."
            }
        }
        .background {
            Color.clear
                .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                    guard case .success(let url) = result else { return }
                    Task { await sync.connect(url, model: model) }
                }
        }
        .alert("Reset everything?", isPresented: $confirmReset) {
            TextField("Type RESET", text: $resetText)
            Button("Cancel", role: .cancel) { resetText = "" }
            Button("Reset", role: .destructive) {
                if resetText == "RESET" { model.resetAll() }
                resetText = ""
            }
        } message: {
            Text("This deletes all your progress on this device. Type RESET to confirm.")
        }
        .sheet(isPresented: $newProgram) { NewProgramSheet() }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { v in model.updateSettings { $0[keyPath: keyPath] = v } })
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<Settings, Int>) -> Binding<Date> {
        Binding(get: { date(minutes: model.settings[keyPath: keyPath]) },
                set: { v in model.updateSettings { $0[keyPath: keyPath] = minutes(of: v) } })
    }

    private func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
