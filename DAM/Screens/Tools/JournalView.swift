import SwiftUI

struct JournalView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: JournalEntry? = nil

    private let color = Stat.mental.color

    var body: some View {
        let today = model.today
        ScreenScroll(spacing: 20) {
            ToolHeader(title: "Journal.", subtitle: "Guided reflection. Clear head, clear plan. Your entries stay on your devices.", color: color)

            HStack(spacing: 12) {
                ForEach([JournalKind.morning, .evening]) { kind in
                    let done = model.hasJournal(kind, day: today)
                    Button {
                        editing = existing(kind, day: today) ?? newEntry(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: kind.symbol).font(.system(size: 22)).foregroundStyle(kind.stat.color)
                                Spacer()
                                if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(kind.stat.color) }
                            }
                            Text(kind.name).font(.ui(18, .semibold)).foregroundStyle(.white)
                            MonoLabel(done ? "Done · edit" : "+\(kind.xp) \(kind.stat.name) XP", color: done ? kind.stat.color : Theme.text3, size: 10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .neonCard(kind.stat.color, active: done, radius: 18)
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            Button {
                editing = newEntry(.free)
            } label: {
                HStack {
                    Image(systemName: JournalKind.free.symbol)
                    Text("Free write")
                    Spacer()
                    Text(JournalPrompts.prompts(for: .free, day: today).first ?? "")
                        .font(.ui(12))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }
                .font(.ui(15, .medium))
                .foregroundStyle(.white)
                .padding(16)
                .glassCard(radius: 16)
            }
            .buttonStyle(PressableStyle())

            if model.journalEntries.isEmpty {
                Text("No entries yet. Start with a morning entry. It takes two minutes.")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text3)
            } else {
                SectionHeader("Entries")
                ForEach(model.journalEntries) { entry in
                    Button {
                        editing = entry
                    } label: {
                        JournalRow(entry: entry)
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteJournal(entry) }
                    }
                }
            }
        }
        .transparentNavBar()
        .sheet(item: $editing) { entry in
            JournalEditor(entry: entry)
        }
    }

    private func existing(_ kind: JournalKind, day: String) -> JournalEntry? {
        model.journalEntries.first { $0.kind == kind && $0.day == day }
    }

    private func newEntry(_ kind: JournalKind) -> JournalEntry {
        let prompts = JournalPrompts.prompts(for: kind, day: model.today)
        return JournalEntry(kind: kind, day: model.today, date: Date(), prompts: prompts, answers: prompts.map { _ in "" })
    }
}

private struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MoodHex(mood: entry.mood, size: 30, selected: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.kind.name).font(.ui(15, .semibold)).foregroundStyle(.white)
                    Spacer()
                    MonoLabel(Day.short(entry.day), size: 10)
                }
                Text(entry.preview.isEmpty ? "No text" : entry.preview)
                    .font(.ui(14))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(14)
        .glassCard(radius: 16)
    }
}

struct MoodHex: View {
    let mood: Int
    var size: CGFloat = 36
    var selected = false

    static let colors: [Color] = [Stat.discipline.color, Stat.intellect.color, Stat.mental.color, Stat.physical.color, Stat.social.color]
    static let names = ["Rough", "Low", "Okay", "Good", "Great"]

    var body: some View {
        let c = MoodHex.colors[min(max(mood, 1), 5) - 1]
        HexIcon(color: c, size: size, filled: selected)
            .overlay(Text("\(mood)").font(.mono(size * 0.36, .bold)).foregroundStyle(selected ? .black : c))
    }
}

struct JournalEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry

    init(entry: JournalEntry) {
        var e = entry
        while e.answers.count < e.prompts.count { e.answers.append("") }
        _entry = State(initialValue: e)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: entry.kind.symbol).foregroundStyle(entry.kind.stat.color)
                        MonoLabel("\(entry.kind.name) · \(Day.long(entry.day))", color: entry.kind.stat.color)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How do you feel?").font(.serif(26)).foregroundStyle(.white)
                        HStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { m in
                                Button {
                                    entry.mood = m
                                    Feedback.tap()
                                } label: {
                                    VStack(spacing: 6) {
                                        MoodHex(mood: m, size: 40, selected: entry.mood == m)
                                        Text(MoodHex.names[m - 1]).font(.ui(11)).foregroundStyle(entry.mood == m ? .white : Theme.text3)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    ForEach(entry.prompts.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.prompts[i]).font(.serif(26)).foregroundStyle(.white)
                            TextEditor(text: $entry.answers[i])
                                .font(.ui(16))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: entry.kind == .free ? 260 : 100)
                                .padding(10)
                                .glassCard(radius: 14)
                        }
                    }
                }
                .padding(20)
            }
            .background(AppBackground(tint: entry.kind.stat.color))
            .navigationTitle(entry.kind.name)
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.saveJournal(entry)
                        dismiss()
                    }
                }
            }
        }
        .sheetSize(width: 560, height: 720)
    }
}
