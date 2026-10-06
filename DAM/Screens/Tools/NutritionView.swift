import SwiftUI

struct NutritionView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var calories: Int? = nil
    @State private var protein: Int? = nil
    @State private var showGoals = false

    private let calorieColor = Stat.intellect.color
    private let proteinColor = Stat.physical.color
    private let waterColor = Stat.social.color

    var body: some View {
        let today = model.today
        let totals = model.nutritionTotals(on: today)
        let s = model.settings
        let water = model.water(on: today)
        ScreenScroll(spacing: 20) {
            ToolHeader(title: "Fuel.", subtitle: "You can't out-train a bad diet. Hit protein, calories and water for daily XP.", color: calorieColor)

            HStack(spacing: 24) {
                ZStack {
                    NutritionRing(progress: Double(totals.calories) / Double(max(s.calorieGoal, 1)), color: calorieColor, lineWidth: 16)
                        .frame(width: 170, height: 170)
                    NutritionRing(progress: Double(totals.protein) / Double(max(s.proteinGoal, 1)), color: proteinColor, lineWidth: 16)
                        .frame(width: 124, height: 124)
                    VStack(spacing: 0) {
                        Text(totals.calories.grouped).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        MonoLabel("kcal", color: Theme.text2, size: 10)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    legend("Calories", "\(totals.calories.grouped) / \(s.calorieGoal.grouped)", calorieColor)
                    legend("Protein", "\(totals.protein) / \(s.proteinGoal) g", proteinColor)
                    legend("Water", "\(water) / \(s.waterGoal) glasses", waterColor)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                MonoLabel("Water", color: waterColor)
                HStack(spacing: 6) {
                    ForEach(0..<max(s.waterGoal, water), id: \.self) { i in
                        Button {
                            model.setWater(i < water ? i : i + 1)
                            Feedback.tap()
                        } label: {
                            HexIcon(color: waterColor, size: 30, filled: i < water, symbol: i < water ? "drop.fill" : nil, lineWidth: 1.5)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        model.setWater(water + 1)
                        Feedback.tap()
                    } label: {
                        Image(systemName: "plus").foregroundStyle(waterColor).frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard()

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Log a meal", color: Theme.text2)
                TextField("", text: $name, prompt: Text("What did you eat?").foregroundStyle(Theme.text3))
                    .textFieldStyle(.plain)
                    .font(.ui(16))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                HStack(spacing: 10) {
                    numberField("kcal", value: $calories)
                    numberField("protein g", value: $protein)
                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 48, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(calorieColor))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && (calories ?? 0) == 0)
                }
                if !model.recentMeals.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(model.recentMeals) { m in
                                Button {
                                    model.addMeal(name: m.name, calories: m.calories, protein: m.protein)
                                } label: {
                                    Text("\(m.name) · \(m.calories)")
                                        .font(.ui(13))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(Color.white.opacity(0.07)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
            .padding(16)
            .glassCard()

            let meals = model.meals(on: today)
            if !meals.isEmpty {
                SectionHeader("Today")
                ForEach(meals) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name.isEmpty ? "Meal" : m.name).font(.ui(15, .medium)).foregroundStyle(.white)
                            MonoLabel("\(m.calories) kcal · \(m.protein) g protein", size: 10)
                        }
                        Spacer()
                        Button {
                            model.deleteMeal(m)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text3)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .glassCard(radius: 14)
                }
            }

            DisclosureGroup(isExpanded: $showGoals) {
                VStack(spacing: 10) {
                    Stepper("Calories: \(s.calorieGoal.grouped)", value: Binding(get: { s.calorieGoal }, set: { v in model.updateSettings { $0.calorieGoal = v } }), in: 1000...6000, step: 50)
                    Stepper("Protein: \(s.proteinGoal) g", value: Binding(get: { s.proteinGoal }, set: { v in model.updateSettings { $0.proteinGoal = v } }), in: 30...400, step: 5)
                    Stepper("Water: \(s.waterGoal) glasses", value: Binding(get: { s.waterGoal }, set: { v in model.updateSettings { $0.waterGoal = v } }), in: 1...20)
                    Text("Rule of thumb: protein ≈ 1.6–2.2 g per kg of bodyweight. Calories: bodyweight (kg) × 30–35 to maintain.")
                        .font(.ui(12))
                        .foregroundStyle(Theme.text3)
                }
                .padding(.top, 10)
                .font(.ui(15))
                .foregroundStyle(.white)
            } label: {
                Text("Daily goals").font(.ui(16, .semibold)).foregroundStyle(.white)
            }
            .padding(16)
            .glassCard()
        }
        .transparentNavBar()
    }

    private func legend(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8).glow(color, radius: 4, opacity: 1)
                MonoLabel(title, color: color, size: 10)
            }
            Text(value).font(.ui(15, .medium)).foregroundStyle(.white)
        }
    }

    private func numberField(_ placeholder: String, value: Binding<Int?>) -> some View {
        TextField("", value: value, format: .number, prompt: Text(placeholder).foregroundStyle(Theme.text3))
            .numberPad()
            .textFieldStyle(.plain)
            .font(.ui(16))
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        model.addMeal(name: trimmed.isEmpty ? "Meal" : trimmed, calories: calories ?? 0, protein: protein ?? 0)
        name = ""
        calories = nil
        protein = nil
    }
}

private struct NutritionRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.001), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.8), radius: 8)
                .animation(.spring(duration: 0.8), value: progress)
        }
    }
}
