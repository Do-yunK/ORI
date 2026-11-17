import SwiftUI
import AppKit
import AVFoundation
import Vision

private extension Color {
    /// A color that follows the window's light or dark appearance.
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

/// Shades-of-green palette that adapts to light and dark mode.
private enum Theme {
    static let background = Color.adaptive(
        light: NSColor(red: 0.91, green: 0.92, blue: 0.88, alpha: 1),
        dark: NSColor(red: 0.07, green: 0.09, blue: 0.06, alpha: 1)
    )
    static let surface = Color.adaptive(
        light: NSColor(red: 1, green: 1, blue: 0.99, alpha: 0.93),
        dark: NSColor(red: 0.13, green: 0.16, blue: 0.11, alpha: 0.93)
    )
    /// Primary text.
    static let ink = Color.adaptive(
        light: NSColor(red: 0.13, green: 0.17, blue: 0.10, alpha: 1),
        dark: NSColor(red: 0.92, green: 0.94, blue: 0.89, alpha: 1)
    )
    /// Deep forest green for the current step, selection, and primary buttons.
    static let primary = Color.adaptive(
        light: NSColor(red: 0.18, green: 0.25, blue: 0.11, alpha: 1),
        dark: NSColor(red: 0.58, green: 0.72, blue: 0.42, alpha: 1)
    )
    /// Sage green for completed items and general accents.
    static let accent = Color.adaptive(
        light: NSColor(red: 0.44, green: 0.57, blue: 0.29, alpha: 1),
        dark: NSColor(red: 0.60, green: 0.74, blue: 0.44, alpha: 1)
    )
    static let olive = Color.adaptive(
        light: NSColor(red: 0.55, green: 0.60, blue: 0.27, alpha: 1),
        dark: NSColor(red: 0.72, green: 0.76, blue: 0.43, alpha: 1)
    )
    /// Soft lilac used for the tutorial figure, as a gentle contrast to the greens.
    static let lilac = Color(red: 0.84, green: 0.71, blue: 0.89)
    /// Olive gradient for feature cards such as the tutorial companion.
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.49, green: 0.59, blue: 0.33), Color(red: 0.28, green: 0.39, blue: 0.19)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ThemedCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.ink.opacity(0.06), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct HeroCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.heroGradient)
            )
            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
    }
}

private extension View {
    func themedCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(ThemedCard(cornerRadius: cornerRadius))
    }

    func heroCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(HeroCard(cornerRadius: cornerRadius))
    }
}


// MARK: - App shell

private enum SidebarItem: Hashable {
    case home
    case exercises(Difficulty)
    case profile
}

struct ContentView: View {
    @StateObject private var progress = ProgressStore()
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false
    @State private var selection: SidebarItem? = .home
    @State private var activeExercise: Exercise?

    var body: some View {
        Group {
            if let activeExercise {
                // A running flow takes over the whole window, like the original yoga view.
                WorkoutView(
                    exercise: activeExercise,
                    progress: progress,
                    onEnd: { self.activeExercise = nil }
                )
                .id(activeExercise.id)
            } else {
                menu
            }
        }
        .tint(Theme.primary)
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
    }

    private var menu: some View {
        NavigationSplitView {
            // Rows draw their own forest-green selection instead of the system's blue highlight.
            List {
                BrandHeader()
                    .padding(.vertical, 8)

                SidebarRow(title: "Home", symbol: "house.fill", item: .home, selection: $selection)

                Section("Exercises") {
                    ForEach(Difficulty.allCases) { difficulty in
                        SidebarRow(
                            title: difficulty.title,
                            symbol: difficulty.symbol,
                            item: .exercises(difficulty),
                            selection: $selection
                        )
                    }
                }

                Section("Account") {
                    SidebarRow(
                        title: "Profile",
                        symbol: "person.crop.circle.fill",
                        item: .profile,
                        selection: $selection
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            switch selection ?? .home {
            case .home:
                HomeView(progress: progress, onStart: start)
            case .exercises(let difficulty):
                ExerciseBrowserView(difficulty: difficulty, progress: progress, onStart: start)
            case .profile:
                ProfileView(progress: progress)
            }
        }
    }

    private func start(_ exercise: Exercise) {
        activeExercise = exercise
    }
}

/// A menu row with a forest-green highlight when selected, matching the app theme.
private struct SidebarRow: View {
    let title: String
    let symbol: String
    let item: SidebarItem
    @Binding var selection: SidebarItem?

    private var isSelected: Bool { (selection ?? .home) == item }

    var body: some View {
        Button {
            selection = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Theme.background : Theme.accent)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.background : Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.primary : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shows a flow's origami mascot artwork, or its symbol when there's no artwork yet.
/// Locked mascots are grayed out with a small lock badge.
private struct MascotIcon: View {
    let exercise: Exercise
    let size: CGFloat
    var symbolColor: Color = Theme.accent

    var body: some View {
        if let mascotImage = exercise.mascotImage {
            Image(mascotImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: exercise.symbol)
                .font(.system(size: size * 0.55))
                .foregroundStyle(symbolColor)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// An achievement slot: an empty origami lily pad until earned, then the mascot sitting on it.
private struct AchievementBadge: View {
    let exercise: Exercise
    let isEarned: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            if isEarned, let mascotImage = exercise.mascotImage {
                // Mascot artwork already includes its own lily pad.
                Image(mascotImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image("MascotLilypad")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(isEarned ? 1 : 0.45)

                if isEarned {
                    // No artwork yet: the symbol sits on the lily pad instead.
                    Image(systemName: exercise.symbol)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(y: -size * 0.08)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.2, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// ORI logo and name shown at the top of the menu.
private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("BrandLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text("ORI")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ORI")
    }
}

/// Backdrop shared by the non-camera pages.
private struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.background, Theme.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct HomeView: View {
    @ObservedObject var progress: ProgressStore
    let onStart: (Exercise) -> Void
    @AppStorage("prefersDarkMode") private var prefersDarkMode = false

    private var suggestedExercise: Exercise {
        Exercise.all.first { !progress.isComplete($0) } ?? Exercise.all[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                        Text("Pick a flow and step back from the screen. The coach will guide you pose by pose.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }

                    Spacer()

                    Picker("Appearance", selection: $prefersDarkMode) {
                        Label("Light", systemImage: "sun.max.fill").tag(false)
                        Label("Dark", systemImage: "moon.fill").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                    .accessibilityLabel("Appearance")
                }

                HStack(spacing: 14) {
                    StatCard(
                        title: "Flows completed",
                        value: "\(progress.completedCount) of \(Exercise.all.count)",
                        symbol: "checkmark.seal.fill"
                    )
                    StatCard(title: "Expertise", value: progress.expertise.title, symbol: "figure.yoga")
                    StatCard(title: "Daily yoga streak", value: "3 days", symbol: "flame.fill")
                }

                SuggestedFlowCard(exercise: suggestedExercise, onStart: onStart)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Achievements")
                    AchievementGrid(progress: progress)
                }

                ForEach(Difficulty.allCases) { difficulty in
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(difficulty.title, symbol: difficulty.symbol, tint: difficulty.tint)
                        ExerciseGrid(exercises: Exercise.list(for: difficulty), progress: progress, onStart: onStart)
                    }
                }
            }
            .padding(30)
            .foregroundStyle(Theme.ink)
        }
        .background(PageBackground())
        .navigationTitle("Home")
    }
}

private struct ExerciseBrowserView: View {
    let difficulty: Difficulty
    @ObservedObject var progress: ProgressStore
    let onStart: (Exercise) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: difficulty.symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(difficulty.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(difficulty.title) flows")
                            .font(.system(size: 30, weight: .bold))
                        Text("\(progress.completedCount(for: difficulty)) of \(Exercise.list(for: difficulty).count) completed")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                }

                ExerciseGrid(exercises: Exercise.list(for: difficulty), progress: progress, onStart: onStart)
            }
            .padding(30)
            .foregroundStyle(Theme.ink)
        }
        .background(PageBackground())
        .navigationTitle(difficulty.title)
    }
}

private struct SectionTitle: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.accent

    init(_ title: String, symbol: String? = nil, tint: Color = Theme.accent) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold))
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.65))
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .themedCard(cornerRadius: 16)
    }
}

private struct SuggestedFlowCard: View {
    let exercise: Exercise
    let onStart: (Exercise) -> Void

    var body: some View {
        HStack(spacing: 18) {
            MascotIcon(exercise: exercise, size: 70, symbolColor: .white)
                .frame(width: 80, height: 80)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text("UP NEXT · \(exercise.difficulty.title.uppercased())")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(exercise.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)
                Text(exercise.intro)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.85))
                PoseSequence(exercise: exercise, color: Color.white)
            }

            Spacer()

            Button {
                onStart(exercise)
            } label: {
                Label("Start flow", systemImage: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
        }
        .padding(20)
        .heroCard(cornerRadius: 20)
    }
}

/// The pose names of a flow joined by arrows, e.g. "Mountain → Arms up → Forward fold".
private struct PoseSequence: View {
    let exercise: Exercise
    var color: Color = Theme.ink

    var body: some View {
        Text(exercise.steps.map(\.shortTitle).joined(separator: "  →  "))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ExerciseGrid: View {
    let exercises: [Exercise]
    @ObservedObject var progress: ProgressStore
    let onStart: (Exercise) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
            ForEach(exercises) { exercise in
                ExerciseCard(exercise: exercise, isComplete: progress.isComplete(exercise), onStart: onStart)
            }
        }
    }
}

private struct ExerciseCard: View {
    let exercise: Exercise
    let isComplete: Bool
    let onStart: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                MascotIcon(exercise: exercise, size: 46)
                    .frame(width: 50, height: 50)
                    .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.difficulty.title.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(exercise.difficulty.tint)
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .bold))
                    Text("\(exercise.steps.count) poses")
                        .font(.caption)
                        .foregroundStyle(Theme.ink.opacity(0.65))
                }

                Spacer()

                if isComplete {
                    Label("Done", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Text(exercise.intro)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            PoseSequence(exercise: exercise)

            Button {
                onStart(exercise)
            } label: {
                Label(isComplete ? "Practice again" : "Start flow", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(cornerRadius: 18)
    }
}

/// One badge per flow, lit up once the flow has been completed.
private struct AchievementGrid: View {
    @ObservedObject var progress: ProgressStore

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
            ForEach(Exercise.all) { exercise in
                let isEarned = progress.isComplete(exercise)

                VStack(spacing: 8) {
                    AchievementBadge(exercise: exercise, isEarned: isEarned, size: 80)
                    Text(exercise.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEarned ? Theme.ink : Theme.ink.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .themedCard(cornerRadius: 14)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(exercise.name) achievement, \(isEarned ? "earned" : "locked")")
            }
        }
    }
}

private struct ProfileView: View {
    @ObservedObject var progress: ProgressStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(Theme.accent, Theme.primary)

                Text("Your Yoga Profile")
                    .font(.title2.weight(.bold))

                VStack(spacing: 12) {
                    ProfileStatistic(title: "Expertise", value: progress.expertise.title, symbol: "figure.yoga")
                    ProfileStatistic(
                        title: "Flows completed",
                        value: "\(progress.completedCount) of \(Exercise.all.count)",
                        symbol: "checkmark.seal.fill"
                    )
                    ForEach(Difficulty.allCases) { difficulty in
                        ProfileStatistic(
                            title: "\(difficulty.title) flows",
                            value: "\(progress.completedCount(for: difficulty)) of \(Exercise.list(for: difficulty).count)",
                            symbol: difficulty.symbol
                        )
                    }
                    ProfileStatistic(title: "Daily yoga streak", value: "3 days", symbol: "flame.fill")
                }
                .frame(maxWidth: 520)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Achievements")
                    AchievementGrid(progress: progress)
                }
                .frame(maxWidth: 720)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Theme.ink)
        }
        .background(PageBackground())
        .navigationTitle("Profile")
    }
}

private struct ProfileStatistic: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
            }

            Spacer()
        }
        .padding(14)
        .themedCard(cornerRadius: 13)
    }
}

// MARK: - Workout

private struct WorkoutView: View {
    @StateObject private var camera: CameraModel
    @ObservedObject var progress: ProgressStore
    let onEnd: () -> Void

    init(exercise: Exercise, progress: ProgressStore, onEnd: @escaping () -> Void) {
        _camera = StateObject(wrappedValue: CameraModel(exercise: exercise))
        self.progress = progress
        self.onEnd = onEnd
    }

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)

            PoseOverlay(
                points: camera.points,
                jointAngles: camera.jointAngles
            )
            .opacity(camera.isCelebrating ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: camera.isCelebrating)

            LimbGuidanceOverlay(points: camera.points, cue: camera.currentCue)
                .opacity(camera.isCelebrating ? 0 : 1)

            if camera.isCelebrating {
                ButterflyCelebration(title: camera.celebrationTitle)
            }

            LinearGradient(
                colors: [Theme.background.opacity(0.35), .clear, Theme.background.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            WorkoutDashboard(camera: camera, onEnd: onEnd)

            if let prompt = camera.stepIntoFramePrompt {
                StepIntoFramePrompt(cue: prompt)
                    .transition(.opacity)
            }

            if let message = camera.message {
                Text(message)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .themedCard(cornerRadius: 12)
                    .padding()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: camera.stepIntoFramePrompt)
        .task {
            // Give SwiftUI one run-loop turn to present the window before camera setup begins.
            await Task.yield()
            camera.onExerciseComplete = { [progress] exercise in
                progress.markComplete(exercise)
            }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }
}

private struct ChecklistFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct WorkoutDashboard: View {
    @ObservedObject var camera: CameraModel
    let onEnd: () -> Void
    @State private var checklistFrame: CGRect = .zero

    var body: some View {
        GeometryReader { proxy in
            content(bodyRect: bodyRect(in: proxy.size))
        }
        .coordinateSpace(name: "dashboard")
        .onPreferenceChange(ChecklistFrameKey.self) { checklistFrame = $0 }
    }

    /// Screen area covered by the detected body (using the same mapping as the skeleton overlay),
    /// padded a little so the checklist fades before it touches the user.
    private func bodyRect(in size: CGSize) -> CGRect? {
        let visible = camera.points.compactMap { $0 }
        guard visible.count >= 5,
              let minX = visible.map(\.x).min(), let maxX = visible.map(\.x).max(),
              let minY = visible.map(\.y).min(), let maxY = visible.map(\.y).max() else {
            return nil
        }
        return CGRect(
            x: minX * size.width,
            y: (1 - maxY) * size.height,
            width: (maxX - minX) * size.width,
            height: (maxY - minY) * size.height
        )
        .insetBy(dx: -30, dy: -30)
    }

    /// Fully visible normally, slightly see-through while posing, and faint when it would cover the body.
    private func checklistOpacity(bodyRect: CGRect?) -> Double {
        if let bodyRect, bodyRect.intersects(checklistFrame) {
            return 0.25
        }
        return camera.isUserAway ? 0.85 : 1
    }

    private func content(bodyRect: CGRect?) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Spacer(minLength: 60)

                ProgressHeader(
                    exercise: camera.exercise,
                    completedSteps: camera.completedSteps,
                    currentStepIndex: camera.currentStepIndex,
                    isAway: camera.isUserAway
                )
                .frame(maxWidth: 760)

                Spacer(minLength: 16)

                Button(action: onEnd) {
                    Label("End", systemImage: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .themedCard(cornerRadius: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End workout")
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)

            if camera.stepIntoFramePrompt == nil {
                FramingGuidanceCard(
                    points: camera.points,
                    alignmentX: camera.alignmentX,
                    isAway: camera.isUserAway
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 26)
                .padding(.top, 12)
            }

            Spacer(minLength: 16)

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    PosePostureChecklist(
                        exercise: camera.exercise,
                        completedSteps: camera.completedSteps,
                        currentStepIndex: camera.currentStepIndex,
                        isAway: camera.isUserAway
                    )
                    .padding(camera.isUserAway ? 18 : 15)
                    .themedCard(cornerRadius: 18)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ChecklistFrameKey.self,
                                value: geometry.frame(in: .named("dashboard"))
                            )
                        }
                    )
                    .opacity(checklistOpacity(bodyRect: bodyRect))
                    .animation(.easeInOut(duration: 0.35), value: checklistOpacity(bodyRect: bodyRect))

                    FloorAlignmentIndicator(alignmentX: camera.alignmentX)
                }
                // Grows a little when the user steps back, but stays narrow enough to leave the body visible.
                .frame(maxWidth: camera.isUserAway ? 520 : 480, alignment: .leading)

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 12) {
                    companion
                    WorkoutLevelCard(camera: camera, onEnd: onEnd)
                }
            }
            .padding(26)
        }
        .animation(.easeInOut(duration: 0.45), value: camera.isUserAway)
    }

    /// Demonstrates the move from the previous pose into the current one.
    private var companion: some View {
        let steps = camera.exercise.steps
        let index = camera.currentStepIndex ?? steps.count - 1
        let to = steps[index].figure
        let from = camera.currentStepIndex == nil ? to : (index > 0 ? steps[index - 1].figure : .mountain)

        return TutorialCompanion(from: from, to: to, caption: steps[index].shortTitle, isAway: camera.isUserAway)
            // Restart the demonstration whenever the step changes.
            .id("\(camera.exercise.id)-\(index)")
    }
}

private struct ProgressHeader: View {
    let exercise: Exercise
    let completedSteps: Set<Int>
    let currentStepIndex: Int?
    let isAway: Bool

    var body: some View {
        let checkpoints = exercise.steps.map(\.shortTitle) + ["Complete"]

        HStack(spacing: 0) {
            ForEach(Array(checkpoints.enumerated()), id: \.offset) { index, checkpoint in
                let isComplete = index == exercise.steps.count
                    ? completedSteps.count == exercise.steps.count
                    : completedSteps.contains(index)
                let isCurrent = index == currentStepIndex

                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(isComplete ? Theme.accent : Theme.ink.opacity(0.18))
                            .frame(width: isAway ? 20 : 16, height: isAway ? 20 : 16)

                        if isCurrent {
                            Circle()
                                .stroke(Theme.primary, lineWidth: 2.5)
                                .frame(width: isAway ? 25 : 21, height: isAway ? 25 : 21)
                        }

                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: isAway ? 10 : 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    Text(checkpoint)
                        .font(.system(size: isAway ? 16 : 12, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? Theme.primary : Theme.ink)
                        .lineLimit(1)
                }

                if index < checkpoints.count - 1 {
                    Rectangle()
                        .fill(completedSteps.contains(index) ? Theme.accent : Theme.ink.opacity(0.18))
                        .frame(height: 1)
                        .padding(.bottom, isAway ? 22 : 18)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .themedCard(cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completedSteps.count) of \(exercise.steps.count) poses complete")
    }
}

private struct WorkoutLevelCard: View {
    @ObservedObject var camera: CameraModel
    let onEnd: () -> Void

    private var stageText: String {
        if camera.allExercisesComplete {
            return "Every flow complete · Great practice!"
        }
        guard let index = camera.currentStepIndex else {
            return "Flow complete · Get ready for the next one."
        }
        return "Pose \(index + 1) of \(camera.exercise.steps.count) · \(camera.exercise.steps[index].title)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(camera.exercise.difficulty.title.uppercased())
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(camera.exercise.difficulty.tint)

                    Text(camera.exercise.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)

                    Text(stageText)
                        .font(.caption)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 225, alignment: .leading)
                }

                Spacer(minLength: 4)

                OrigamiAchievementPlaceholder(exercise: camera.exercise)
            }

            DifficultyPath(current: camera.exercise.difficulty)

            NextExercisePreview(camera: camera, onEnd: onEnd)
        }
        .padding(16)
        .frame(maxWidth: 390, alignment: .leading)
        .themedCard(cornerRadius: 18)
    }
}

/// Beginner → Intermediate → Expert, with the current tier highlighted.
private struct DifficultyPath: View {
    let current: Difficulty

    var body: some View {
        let currentIndex = Difficulty.allCases.firstIndex(of: current) ?? 0

        HStack(spacing: 5) {
            ForEach(Array(Difficulty.allCases.enumerated()), id: \.offset) { index, difficulty in
                if index > 0 {
                    Capsule()
                        .fill(index <= currentIndex ? Theme.ink : Theme.ink.opacity(0.26))
                        .frame(height: 1)
                }
                VStack(spacing: 3) {
                    Image(systemName: index < currentIndex
                          ? "checkmark.circle.fill"
                          : (index == currentIndex ? difficulty.symbol : "circle"))
                        .font(.caption)
                        .foregroundStyle(index <= currentIndex ? difficulty.tint : Theme.ink.opacity(0.35))
                    Text(difficulty.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(index == currentIndex ? 1 : 0.7))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(current.title) tier")
    }
}

private struct NextExercisePreview: View {
    @ObservedObject var camera: CameraModel
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if camera.allExercisesComplete {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ALL FLOWS COMPLETE")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.ink.opacity(0.68))
                    Text("Repeat or head back home")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()

                Button("Repeat") { camera.restart() }
                    .buttonStyle(.bordered)
                Button("Home", action: onEnd)
                    .buttonStyle(.bordered)
            } else if let next = camera.exercise.next {
                Image(systemName: "arrow.forward.circle.fill")
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("UP NEXT · \(next.difficulty.title.uppercased())")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.ink.opacity(0.68))
                    Text(next.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()

                MascotIcon(exercise: next, size: 30, symbolColor: Theme.ink.opacity(0.8))
            } else {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FINAL FLOW")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.ink.opacity(0.68))
                    Text("Finish \(camera.exercise.name) to complete every flow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()
            }
        }
        .padding(10)
        .themedCard(cornerRadius: 13)
    }
}

private struct OrigamiAchievementPlaceholder: View {
    let exercise: Exercise

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Theme.ink.opacity(0.16))
                    .frame(width: 72, height: 72)

                MascotIcon(exercise: exercise, size: 66)
            }

            Text(exercise.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement: \(exercise.name)")
    }
}

private struct PoseOverlay: View {
    let points: [CGPoint?]
    let jointAngles: [Int: Double]

    var body: some View {
        GeometryReader { proxy in
            let scaledPoints = points.map {
                $0.map { CGPoint(x: $0.x * proxy.size.width, y: (1 - $0.y) * proxy.size.height) }
            }

            ZStack {
                Canvas { context, _ in
                    for (startIndex, endIndex) in CameraModel.connections {
                        guard startIndex < scaledPoints.count,
                              endIndex < scaledPoints.count,
                              let start = scaledPoints[startIndex],
                              let end = scaledPoints[endIndex] else {
                            continue
                        }

                        var limb = Path()
                        limb.move(to: start)
                        limb.addLine(to: end)
                        context.stroke(
                            limb,
                            with: .color(Theme.accent.opacity(0.85)),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                    }

                    for point in scaledPoints.compactMap({ $0 }) {
                        let joint = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                        context.fill(Path(ellipseIn: joint), with: .color(.white))
                        context.stroke(
                            Path(ellipseIn: joint),
                            with: .color(Theme.accent),
                            lineWidth: 1.5
                        )
                    }
                }

                ForEach(CameraModel.angleJointIndices, id: \.self) { index in
                    if index < scaledPoints.count,
                       let point = scaledPoints[index],
                       let angle = jointAngles[index] {
                        Text("\(Int(angle.rounded()))°")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.surface, in: Capsule())
                            .position(x: point.x + 28, y: point.y - 18)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}


private struct LimbGuidanceOverlay: View {
    let points: [CGPoint?]
    let cue: PoseCue?

    var body: some View {
        GeometryReader { proxy in
            if let cue,
               let anchorIndex = cue.anchorIndex,
               anchorIndex < points.count,
               let anchor = points[anchorIndex] {
                LimbDirectionCue(cue: cue)
                    .id(cue.id)
                    .position(
                        x: min(max(anchor.x * proxy.size.width + cue.offset.width, 110), proxy.size.width - 110),
                        y: min(max((1 - anchor.y) * proxy.size.height + cue.offset.height, 52), proxy.size.height - 52)
                    )
            }
        }
        .allowsHitTesting(false)
    }
}


/// Large arrow prompt shown while nobody is in view, pointing the way back into the frame.
private struct StepIntoFramePrompt: View {
    let cue: PoseCue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var alignment: Alignment {
        switch cue.symbol {
        case "arrow.right": .leading
        case "arrow.left": .trailing
        default: .center
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: cue.symbol)
                .font(.system(size: 54, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .offset(
                    x: isAnimating && !reduceMotion ? cue.motion.width * 1.5 : 0,
                    y: isAnimating && !reduceMotion ? cue.motion.height * 1.5 : 0
                )
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isAnimating)

            Text(cue.message)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .themedCard(cornerRadius: 24)
        .padding(.horizontal, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .allowsHitTesting(false)
        .onAppear { isAnimating = true }
        .accessibilityLabel(cue.message)
    }
}


private struct ButterflyCelebration: View {
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasTakenFlight = false

    private let butterflies: [(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat, delay: Double)] = [
        (-40, -30, -150, -120, 0.00),
        (25, -90, 130, -150, 0.08),
        (70, 20, 190, -50, 0.16),
        (-95, 55, -180, -70, 0.24),
        (0, 45, 20, -190, 0.32),
        (105, -20, 220, -135, 0.40)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(butterflies.enumerated()), id: \.offset) { _, butterfly in
                    Text("🦋")
                        .font(.system(size: 32))
                        .position(
                            x: proxy.size.width / 2 + butterfly.x,
                            y: proxy.size.height / 2 + butterfly.y
                        )
                        .offset(
                            x: hasTakenFlight && !reduceMotion ? butterfly.dx : 0,
                            y: hasTakenFlight && !reduceMotion ? butterfly.dy : 0
                        )
                        .opacity(hasTakenFlight ? 1 : 0)
                        .scaleEffect(hasTakenFlight ? 1 : 0.55)
                        .animation(
                            .spring(response: 1.15, dampingFraction: 0.72)
                                .delay(butterfly.delay),
                            value: hasTakenFlight
                        )
                }

                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .themedCard(cornerRadius: 22)
                    .opacity(hasTakenFlight ? 1 : 0)
                    .scaleEffect(hasTakenFlight ? 1 : 0.85)
                    .animation(.spring(response: 0.5, dampingFraction: 0.78), value: hasTakenFlight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onAppear {
            hasTakenFlight = true
        }
        .accessibilityLabel(title)
    }
}


private struct LimbDirectionCue: View {
    let cue: PoseCue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: cue.symbol)
                .font(.title3.weight(.heavy))
            Text(cue.message)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .themedCard(cornerRadius: 20)
        .offset(
            x: isAnimating && !reduceMotion ? cue.motion.width : 0,
            y: isAnimating && !reduceMotion ? cue.motion.height : 0
        )
        .animation(
            .easeInOut(duration: 0.72).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
        .accessibilityLabel(cue.message)
    }
}

private struct PoseCue: Identifiable, Equatable {
    let id: String
    /// Joint the on-body arrow is drawn next to; nil for whole-body cues such as framing.
    let anchorIndex: Int?
    let symbol: String
    let message: String

    var offset: CGSize {
        switch symbol {
        case "arrow.up":
            CGSize(width: 0, height: -54)
        case "arrow.down":
            CGSize(width: 0, height: 54)
        case "arrow.left":
            CGSize(width: -90, height: -14)
        default:
            CGSize(width: 90, height: -14)
        }
    }

    var motion: CGSize {
        switch symbol {
        case "arrow.up":
            CGSize(width: 0, height: -12)
        case "arrow.down":
            CGSize(width: 0, height: 12)
        case "arrow.left":
            CGSize(width: -12, height: 0)
        default:
            CGSize(width: 12, height: 0)
        }
    }
}


/// Thin one-line framing status.
private struct FramingGuidanceCard: View {
    let points: [CGPoint?]
    let alignmentX: CGFloat?
    let isAway: Bool

    private var feedback: FramingFeedback {
        FramingFeedback(points: points, alignmentX: alignmentX)
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: feedback.symbol)
                .font(.system(size: isAway ? 16 : 13, weight: .semibold))
            Text(feedback.headline)
                .font(.system(size: isAway ? 16 : 13, weight: .semibold))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .themedCard(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}

private struct FramingFeedback {
    let headline: String
    let symbol: String
    let isFramed: Bool

    init(points: [CGPoint?], alignmentX: CGFloat?) {
        let visiblePoints = points.compactMap { $0 }
        let hasBothFeet = points.indices.contains(12) && points.indices.contains(15)
            && points[12] != nil && points[15] != nil

        guard visiblePoints.count >= 8 else {
            headline = "Step into the frame"
            symbol = "viewfinder"
            isFramed = false
            return
        }

        guard hasBothFeet else {
            headline = "Step back until both feet are visible"
            symbol = "arrow.backward"
            isFramed = false
            return
        }

        let top = visiblePoints.map(\.y).max() ?? 1
        let bottom = visiblePoints.map(\.y).min() ?? 0
        let bodyHeight = top - bottom

        if bodyHeight > 0.9 {
            headline = "Step back slightly"
            symbol = "arrow.backward"
            isFramed = false
        } else if bodyHeight < 0.5 {
            headline = "Move a little closer"
            symbol = "arrow.forward"
            isFramed = false
        } else if let alignmentX, alignmentX < 0.4 {
            headline = "Move right to center"
            symbol = "arrow.right"
            isFramed = false
        } else if let alignmentX, alignmentX > 0.6 {
            headline = "Move left to center"
            symbol = "arrow.left"
            isFramed = false
        } else {
            headline = "Whole body framed"
            symbol = "checkmark.viewfinder"
            isFramed = true
        }
    }
}

private struct FloorAlignmentIndicator: View {
    let alignmentX: CGFloat?

    private var status: String {
        guard let alignmentX else { return "Step into view" }
        if alignmentX < 0.4 { return "Move right" }
        if alignmentX > 0.6 { return "Move left" }
        return "Centered — great framing"
    }

    private var markerPosition: CGFloat {
        guard let alignmentX else { return 0.5 }
        return min(max(alignmentX, 0.04), 0.96)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Floor alignment", systemImage: "viewfinder")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ink)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.26))
                        .frame(height: 3)

                    Capsule()
                        .fill(Theme.accent.opacity(0.7))
                        .frame(width: proxy.size.width * 0.24, height: 3)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    Circle()
                        .fill(status == "Centered — great framing" ? Theme.accent : Theme.lilac)
                        .frame(width: 10, height: 10)
                        .position(x: proxy.size.width * markerPosition, y: proxy.size.height / 2)
                }
            }
            .frame(width: 230, height: 10)

            Text(status)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.88))
        }
        .padding(15)
        .themedCard(cornerRadius: 16)
    }
}

private struct PosePostureChecklist: View {
    let exercise: Exercise
    let completedSteps: Set<Int>
    let currentStepIndex: Int?
    let isAway: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isAway ? 10 : 8) {
            HStack {
                Text("Pose checklist")
                    .font(.system(size: isAway ? 18 : 14, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.8))

                Spacer()

                if let currentStepIndex {
                    Text("Step \(currentStepIndex + 1) of \(exercise.steps.count)")
                        .font(.system(size: isAway ? 18 : 14, weight: .bold))
                        .foregroundStyle(Theme.primary)
                }
            }

            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                let isComplete = completedSteps.contains(index)
                let isCurrent = index == currentStepIndex
                let size: CGFloat = isCurrent ? (isAway ? 28 : 20) : (isAway ? 21 : 15)

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: isComplete
                          ? "checkmark.circle.fill"
                          : (isCurrent ? "arrow.right.circle.fill" : "circle"))
                        .foregroundStyle(isComplete ? Theme.accent : (isCurrent ? Theme.primary : Theme.ink.opacity(0.38)))
                    Text(step.title)
                        .foregroundStyle(isComplete || isCurrent ? Theme.ink : Theme.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: size, weight: isCurrent ? .bold : .medium))
                .padding(.horizontal, isCurrent ? 10 : 0)
                .padding(.vertical, isCurrent ? 7 : 0)
                .background {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.primary.opacity(0.18))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}


private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }
}

private final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        AVCaptureVideoPreviewLayer()
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("PreviewView must use an AVCaptureVideoPreviewLayer.")
        }
        return previewLayer
    }
}


// MARK: - Tutorial companion

/// A simple front-facing stick figure, in a 100 × 112 point box.
/// "Left" and "right" here mean the left and right side of the screen.
private struct StickPose {
    var head: CGPoint
    var neck: CGPoint
    var hip: CGPoint
    var leftElbow: CGPoint
    var leftHand: CGPoint
    var rightElbow: CGPoint
    var rightHand: CGPoint
    var leftKnee: CGPoint
    var leftFoot: CGPoint
    var rightKnee: CGPoint
    var rightFoot: CGPoint

    private var joints: [CGPoint] {
        [head, neck, hip, leftElbow, leftHand, rightElbow, rightHand, leftKnee, leftFoot, rightKnee, rightFoot]
    }

    private init(_ joints: [CGPoint]) {
        (head, neck, hip) = (joints[0], joints[1], joints[2])
        (leftElbow, leftHand, rightElbow, rightHand) = (joints[3], joints[4], joints[5], joints[6])
        (leftKnee, leftFoot, rightKnee, rightFoot) = (joints[7], joints[8], joints[9], joints[10])
    }

    private init(
        head: CGPoint = CGPoint(x: 50, y: 18),
        neck: CGPoint = CGPoint(x: 50, y: 30),
        hip: CGPoint = CGPoint(x: 50, y: 64),
        arms: (CGPoint, CGPoint, CGPoint, CGPoint),
        legs: (CGPoint, CGPoint, CGPoint, CGPoint) = StickPose.standingLegs
    ) {
        self.init([head, neck, hip, arms.0, arms.1, arms.2, arms.3, legs.0, legs.1, legs.2, legs.3])
    }

    func interpolated(to other: StickPose, progress: CGFloat) -> StickPose {
        StickPose(zip(joints, other.joints).map { from, to in
            CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
        })
    }

    /// Limb segments (start, end) in drawing order.
    var limbs: [(CGPoint, CGPoint)] {
        [
            (neck, hip),
            (neck, leftElbow), (leftElbow, leftHand),
            (neck, rightElbow), (rightElbow, rightHand),
            (hip, leftKnee), (leftKnee, leftFoot),
            (hip, rightKnee), (rightKnee, rightFoot)
        ]
    }

    // MARK: Building blocks

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static let standingLegs = (p(46, 86), p(45, 108), p(54, 86), p(55, 108))
    private static let wideLegs = (p(38, 86), p(30, 108), p(62, 86), p(70, 108))
    private static let treeLegs = (p(36, 78), p(49, 86), p(52, 86), p(52, 108))
    private static let armsDown = (p(43, 46), p(41, 62), p(57, 46), p(59, 62))
    private static let armsUp = (p(45, 16), p(43, 2), p(55, 16), p(57, 2))
    private static let wings = (p(34, 31), p(18, 31), p(66, 31), p(82, 31))
    private static let palms = (p(41, 44), p(50, 40), p(59, 44), p(50, 40))

    // MARK: Poses

    static let mountain = StickPose(arms: armsDown)
    static let upwardSalute = StickPose(arms: armsUp)
    static let openWings = StickPose(arms: wings)
    static let kneeLiftWings = StickPose(arms: wings, legs: (p(38, 74), p(46, 90), p(52, 86), p(52, 108)))
    static let palmsStanding = StickPose(arms: palms)
    static let treePalms = StickPose(arms: palms, legs: treeLegs)
    static let treeArmsUp = StickPose(arms: armsUp, legs: treeLegs)
    static let wideStance = StickPose(arms: armsDown, legs: wideLegs)
    static let widePalms = StickPose(arms: palms, legs: wideLegs)
    static let star = StickPose(arms: wings, legs: wideLegs)

    static let forwardFold = StickPose(
        head: p(50, 84), neck: p(50, 72), hip: p(50, 58),
        arms: (p(45, 86), p(44, 102), p(55, 86), p(56, 102))
    )

    static let chair = StickPose(
        head: p(50, 30), neck: p(50, 42), hip: p(50, 74),
        arms: (p(45, 28), p(43, 14), p(55, 28), p(57, 14)),
        legs: (p(41, 88), p(45, 108), p(59, 88), p(55, 108))
    )

    static let frogSquat = StickPose(
        head: p(50, 34), neck: p(50, 46), hip: p(50, 80),
        arms: (p(41, 58), p(50, 54), p(59, 58), p(50, 54)),
        legs: (p(32, 82), p(32, 108), p(68, 82), p(68, 108))
    )

    static let warriorTwo = StickPose(
        head: p(50, 26), neck: p(50, 38), hip: p(50, 70),
        arms: (p(34, 39), p(18, 39), p(66, 39), p(82, 39)),
        legs: (p(34, 82), p(30, 108), p(62, 88), p(72, 108))
    )

    static let triangle = StickPose(
        head: p(31, 30), neck: p(37, 40), hip: p(50, 64),
        arms: (p(34, 58), p(32, 76), p(40, 22), p(43, 4)),
        legs: wideLegs
    )

    static let eagle = StickPose(
        head: p(50, 26), neck: p(50, 38), hip: p(50, 72),
        arms: (p(44, 46), p(50, 34), p(56, 46), p(50, 34)),
        legs: (p(55, 86), p(48, 100), p(48, 88), p(52, 108))
    )

    static let handToToe = StickPose(
        arms: (p(36, 44), p(22, 60), p(60, 46), p(55, 62)),
        legs: (p(36, 66), p(20, 62), p(52, 86), p(52, 108))
    )

    static let crescentLunge = StickPose(
        head: p(50, 26), neck: p(50, 38), hip: p(50, 70),
        arms: (p(46, 24), p(45, 10), p(54, 24), p(55, 10)),
        legs: (p(40, 84), p(40, 108), p(60, 96), p(72, 106))
    )
}

/// A small animated stick figure that shows how to move from the previous pose into the current one.
private struct TutorialCompanion: View {
    let from: StickPose
    let to: StickPose
    let caption: String
    let isAway: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    // One demonstration loop: pause on the previous pose, glide into the new one, hold it.
    private let pauseDuration = 0.6
    private let moveDuration = 1.3
    private let holdDuration = 1.8

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let progress = reduceMotion ? 1 : demoProgress(at: timeline.date)
                let pose = from.interpolated(to: to, progress: progress)
                let breathe = 1 + 0.015 * sin(timeline.date.timeIntervalSince(startDate) * 2.4)

                Canvas { context, size in
                    let scale = min(size.width / 100, size.height / 112)
                    let offset = CGPoint(x: (size.width - 100 * scale) / 2, y: (size.height - 112 * scale) / 2)
                    func map(_ point: CGPoint) -> CGPoint {
                        CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale)
                    }

                    // Limbs that change between the two poses are drawn in lilac to show what moves.
                    let fromLimbs = from.limbs
                    let toLimbs = to.limbs
                    for (index, (start, end)) in pose.limbs.enumerated() {
                        let moves = Self.distance(fromLimbs[index].0, toLimbs[index].0)
                            + Self.distance(fromLimbs[index].1, toLimbs[index].1) > 6
                        var path = Path()
                        path.move(to: map(start))
                        path.addLine(to: map(end))
                        context.stroke(
                            path,
                            with: .color(moves ? Theme.lilac : Color.white.opacity(0.92)),
                            style: StrokeStyle(lineWidth: 4.5 * scale, lineCap: .round, lineJoin: .round)
                        )
                    }

                    let headRadius = 7.5 * scale
                    let head = map(pose.head)
                    context.fill(
                        Path(ellipseIn: CGRect(x: head.x - headRadius, y: head.y - headRadius, width: headRadius * 2, height: headRadius * 2)),
                        with: .color(Theme.lilac)
                    )
                }
                .scaleEffect(breathe, anchor: .bottom)
            }
            .frame(width: isAway ? 150 : 110, height: isAway ? 168 : 124)

            Text(caption)
                .font(.system(size: isAway ? 15 : 12, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .padding(12)
        .heroCard(cornerRadius: 18)
        .onAppear { startDate = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial companion demonstrating \(caption)")
    }

    private func demoProgress(at date: Date) -> CGFloat {
        let cycle = pauseDuration + moveDuration + holdDuration
        let t = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: cycle)
        guard t > pauseDuration else { return 0 }
        let linear = min(1, (t - pauseDuration) / moveDuration)
        // Ease in and out so the movement looks natural.
        return CGFloat(linear * linear * (3 - 2 * linear))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

// MARK: - Exercise catalog

private enum Difficulty: String, CaseIterable, Identifiable {
    case beginner, intermediate, expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .expert: "Expert"
        }
    }

    var symbol: String {
        switch self {
        case .beginner: "leaf.fill"
        case .intermediate: "flame.fill"
        case .expert: "bolt.fill"
        }
    }

    var tint: Color {
        switch self {
        case .beginner: Theme.accent
        case .intermediate: Theme.olive
        case .expert: Theme.primary
        }
    }
}

private struct YogaStep {
    let shortTitle: String
    let title: String
    let spoken: String
    /// What the tutorial companion demonstrates for this step.
    let figure: StickPose
    /// Returns nil when the pose is correct, otherwise the correction to show and speak.
    let check: (PoseReader) -> PoseCue?
}

/// A flow of standing poses where each step transitions naturally into the next.
private struct Exercise: Identifiable {
    let id: String
    let name: String
    let difficulty: Difficulty
    let symbol: String
    let intro: String
    let steps: [YogaStep]

    /// Origami mascot artwork in the asset catalog, if this flow has one.
    var mascotImage: String? {
        switch id {
        case "origami-boat": "MascotBoat"
        case "origami-tulip": "MascotTulip"
        case "origami-crane": "MascotCrane"
        default: nil
        }
    }

    static func with(id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    static func list(for difficulty: Difficulty) -> [Exercise] {
        all.filter { $0.difficulty == difficulty }
    }

    /// The following exercise in the full catalog order, if any.
    var next: Exercise? {
        guard let index = Self.all.firstIndex(where: { $0.id == id }), index + 1 < Self.all.count else {
            return nil
        }
        return Self.all[index + 1]
    }
}

private extension YogaStep {
    /// Every flow begins flat and uncreased, like a fresh sheet of origami paper.
    static let flatSheet = YogaStep(
        shortTitle: "Flat sheet",
        title: "Mountain pose: stand tall and flat like a fresh sheet of paper",
        spoken: "Stand facing the camera, about six to eight feet away, with your whole body in view. Stand tall in mountain pose, flat like a fresh sheet of paper, legs straight and arms relaxed by your sides.",
        figure: .mountain,
        check: { $0.framed() ?? $0.legsStraight() ?? $0.armsDown() }
    )
}

private extension Exercise {
    static let all: [Exercise] = [
        // MARK: Beginner
        Exercise(
            id: "sun-fold",
            name: "Origami Sun",
            difficulty: .beginner,
            symbol: "sun.max.fill",
            intro: "Fold a paper sun: stretch your rays up, fold down at sunset, and rise again.",
            steps: [
                .flatSheet,
                YogaStep(
                    shortTitle: "Sun rays",
                    title: "Upward salute: sweep your arms overhead like sun rays",
                    spoken: "Inhale and sweep both arms out and up overhead, like the rays of a paper sun.",
                    figure: .upwardSalute,
                    check: { $0.inView() ?? $0.legsStraight() ?? $0.armsOverhead() }
                ),
                YogaStep(
                    shortTitle: "Sunset fold",
                    title: "Forward fold: hinge at your hips like the setting sun",
                    spoken: "Exhale and fold forward from your hips, like the sun setting. Let your hands hang toward your shins.",
                    figure: .forwardFold,
                    check: { $0.inView() ?? $0.forwardFold() }
                ),
                YogaStep(
                    shortTitle: "Sunrise",
                    title: "Chair pose: bend your knees and rise with arms up",
                    spoken: "Bend your knees, lift your chest, and sweep your arms back up overhead, rising like the morning sun.",
                    figure: .chair,
                    check: { $0.inView() ?? $0.kneesBent(below: 155) ?? $0.armsOverhead() }
                )
            ]
        ),
        Exercise(
            id: "origami-heart",
            name: "Origami Heart",
            difficulty: .beginner,
            symbol: "heart.fill",
            intro: "Fold a paper heart: gather your palms at your heart, lift them high, then open wide.",
            steps: [
                .flatSheet,
                YogaStep(
                    shortTitle: "Heart center",
                    title: "Press your palms together at your heart",
                    spoken: "Keep your legs straight and press your palms together in front of your heart.",
                    figure: .palmsStanding,
                    check: { $0.inView() ?? $0.legsStraight() ?? $0.prayerHands() }
                ),
                YogaStep(
                    shortTitle: "Heart crease",
                    title: "Slide your palms up and reach straight overhead",
                    spoken: "Keeping your palms together, slide them up and reach straight overhead, like the center crease of a paper heart.",
                    figure: .upwardSalute,
                    check: { $0.inView() ?? $0.legsStraight() ?? $0.armsOverhead() }
                ),
                YogaStep(
                    shortTitle: "Open heart",
                    title: "Open your arms wide at shoulder height",
                    spoken: "Float your arms down and out to the sides at shoulder height, opening your heart wide.",
                    figure: .openWings,
                    check: { $0.inView() ?? $0.wingsOpen() }
                )
            ]
        ),

        // MARK: Intermediate
        Exercise(
            id: "origami-boat",
            name: "Origami Boat",
            difficulty: .intermediate,
            symbol: "sailboat.fill",
            intro: "Fold a paper sailboat: set a wide hull, raise the sail, catch the wind, and tilt the mast.",
            steps: [
                .flatSheet,
                YogaStep(
                    shortTitle: "Hull & sail",
                    title: "Five-point star: feet wide like a hull, arms out like a sail",
                    spoken: "Step your feet wide apart like the hull of a boat, and open both arms out at shoulder height like a sail.",
                    figure: .star,
                    check: { $0.inView() ?? $0.wideStance() ?? $0.legsStraight() ?? $0.wingsOpen() }
                ),
                YogaStep(
                    shortTitle: "Catch the wind",
                    title: "Warrior II: bend one knee as the wind fills your sail",
                    spoken: "Turn one foot out and bend that knee deeply into warrior two, as if the wind is filling your sail. Keep your arms long and level.",
                    figure: .warriorTwo,
                    check: { $0.inView() ?? $0.wideStance() ?? $0.oneKneeBent(below: 140) ?? $0.wingsOpen() }
                ),
                YogaStep(
                    shortTitle: "Tilt the mast",
                    title: "Triangle: straighten the leg, one hand down, one up like a mast",
                    spoken: "Straighten your front leg, tilt sideways, and reach one hand down toward your shin while the other arm reaches up like a tall mast.",
                    figure: .triangle,
                    check: { $0.inView() ?? $0.wideStance() ?? $0.legsStraight() ?? $0.triangleArms() }
                )
            ]
        ),
        Exercise(
            id: "origami-frog",
            name: "Origami Frog",
            difficulty: .intermediate,
            symbol: "drop.fill",
            intro: "Fold a paper jumping frog: settle on your lily pad, crouch low, and spring up.",
            steps: [
                YogaStep(
                    shortTitle: "Lily pad",
                    title: "Step your feet wide apart, like a frog on a lily pad",
                    spoken: "Face the camera with your whole body in view, and step your feet wide apart, about twice hip width, like a frog on a lily pad.",
                    figure: .wideStance,
                    check: { $0.framed() ?? $0.wideStance() }
                ),
                YogaStep(
                    shortTitle: "Tuck in",
                    title: "Press your palms together at your chest",
                    spoken: "Keep your feet wide and tuck your hands in, pressing your palms together in front of your chest.",
                    figure: .widePalms,
                    check: { $0.inView() ?? $0.wideStance() ?? $0.prayerHands() }
                ),
                YogaStep(
                    shortTitle: "Crouch",
                    title: "Bend your knees and sink into a low frog squat",
                    spoken: "Keep your palms together, bend both knees, and crouch down into a low frog squat, ready to jump.",
                    figure: .frogSquat,
                    check: { $0.inView() ?? $0.wideStance() ?? $0.kneesBent(below: 145) }
                ),
                YogaStep(
                    shortTitle: "Leap",
                    title: "Spring up and reach both arms overhead",
                    spoken: "Spring up! Straighten your legs and reach both arms overhead, like a paper frog mid leap.",
                    figure: .upwardSalute,
                    check: { $0.inView() ?? $0.legsStraight() ?? $0.armsOverhead() }
                )
            ]
        ),

        // MARK: Expert
        Exercise(
            id: "origami-tulip",
            name: "Origami Tulip",
            difficulty: .expert,
            symbol: "camera.macro",
            intro: "Fold a paper tulip: grow a tall stem, unfold your leaves, and bloom on one leg.",
            steps: [
                .flatSheet,
                YogaStep(
                    shortTitle: "Stem",
                    title: "Grow a tall stem: reach both arms overhead",
                    spoken: "Inhale and reach both arms straight overhead, growing tall like a tulip stem.",
                    figure: .upwardSalute,
                    check: { $0.inView() ?? $0.legsStraight() ?? $0.armsOverhead() }
                ),
                YogaStep(
                    shortTitle: "Leaf",
                    title: "Crescent lunge: step back, bend the front knee, arms up",
                    spoken: "Step one foot far back and bend your front knee into a crescent lunge, keeping your arms high, like a leaf unfolding from the stem.",
                    figure: .crescentLunge,
                    check: { $0.inView() ?? $0.oneKneeBent(below: 130) ?? $0.armsOverhead() }
                ),
                YogaStep(
                    shortTitle: "Open leaves",
                    title: "Warrior II: keep the knee bent, spread your arms wide",
                    spoken: "Open your hips to the side and lower your arms to shoulder height for warrior two, spreading your leaves wide.",
                    figure: .warriorTwo,
                    check: { $0.inView() ?? $0.oneKneeBent(below: 140) ?? $0.wingsOpen() }
                ),
                YogaStep(
                    shortTitle: "Bloom",
                    title: "Tree pose: stand on one leg, arms overhead in bloom",
                    spoken: "Step your feet together, lift one foot onto your standing leg, and reach both arms overhead to bloom into tree pose.",
                    figure: .treeArmsUp,
                    check: { $0.kneeLifted() ?? $0.armsOverhead() }
                )
            ]
        ),
        Exercise(
            id: "origami-crane",
            name: "Origami Crane",
            difficulty: .expert,
            symbol: "bird.fill",
            intro: "Fold the classic paper crane: spread your wings, balance, fold your wings in, then take flight.",
            steps: [
                .flatSheet,
                YogaStep(
                    shortTitle: "Spread wings",
                    title: "Open both arms out at shoulder height",
                    spoken: "Lift both arms out to the sides at shoulder height, spreading your crane wings.",
                    figure: .openWings,
                    check: { $0.inView() ?? $0.wingsOpen() }
                ),
                YogaStep(
                    shortTitle: "Balance",
                    title: "Keep wings open and lift one knee",
                    spoken: "Keep your wings open, shift your weight onto one foot, and slowly lift the other knee toward your hip.",
                    figure: .kneeLiftWings,
                    check: { $0.wingsOpen() ?? $0.kneeLifted() }
                ),
                YogaStep(
                    shortTitle: "Fold wings",
                    title: "Eagle pose: cross your leg and wrap your arms",
                    spoken: "Cross your lifted leg over your standing leg and wrap your arms, palms together in front of your face, folding your wings in.",
                    figure: .eagle,
                    check: { $0.inView() ?? $0.kneeLifted() ?? $0.eagleArms() }
                ),
                YogaStep(
                    shortTitle: "Take flight",
                    title: "Hand-to-toe: unwrap and extend one leg to hip height",
                    spoken: "Unwrap, straighten your standing leg, and extend your lifted leg forward toward hip height as your crane takes flight.",
                    figure: .handToToe,
                    check: { $0.legHighLift() }
                )
            ]
        )
    ]
}

/// Remembers which exercises the user has completed, across launches.
@MainActor
private final class ProgressStore: ObservableObject {
    private static let key = "completedExerciseIDs"

    @Published private(set) var completedIDs: Set<String>

    init() {
        completedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.key) ?? [])
    }

    func isComplete(_ exercise: Exercise) -> Bool {
        completedIDs.contains(exercise.id)
    }

    func markComplete(_ exercise: Exercise) {
        guard !completedIDs.contains(exercise.id) else { return }
        completedIDs.insert(exercise.id)
        UserDefaults.standard.set(Array(completedIDs), forKey: Self.key)
    }

    /// Counts only flows that still exist, so flows removed in earlier versions don't inflate totals.
    var completedCount: Int {
        Exercise.all.filter(isComplete).count
    }

    func completedCount(for difficulty: Difficulty) -> Int {
        Exercise.list(for: difficulty).filter(isComplete).count
    }

    /// The highest tier where the user has finished at least one exercise.
    var expertise: Difficulty {
        Difficulty.allCases.last { completedCount(for: $0) > 0 } ?? .beginner
    }
}

// MARK: - Pose checks

/// Reads one frame of joints and reports what, if anything, the user needs to fix.
///
/// Joint indices: 0 nose, 3/4/5 left shoulder/elbow/wrist, 6/7/8 right shoulder/elbow/wrist,
/// 10/11/12 left hip/knee/ankle, 13/14/15 right hip/knee/ankle. Coordinates are normalized
/// with y pointing up. "Left" and "right" are the user's own sides.
private struct PoseReader {
    let points: [CGPoint?]
    let alignmentX: CGFloat?

    private struct Side {
        let name: String
        let shoulder, wrist, hip, knee, ankle: Int
    }

    private static let sides = [
        Side(name: "left", shoulder: 3, wrist: 5, hip: 10, knee: 11, ankle: 12),
        Side(name: "right", shoulder: 6, wrist: 8, hip: 13, knee: 14, ankle: 15)
    ]

    func point(_ index: Int) -> CGPoint? {
        guard index < points.count else { return nil }
        return points[index]
    }

    var visibleCount: Int { points.compactMap { $0 }.count }
    var hasPerson: Bool { visibleCount >= 5 }
    var hasBothFeet: Bool { point(12) != nil && point(15) != nil }

    var shoulderSpan: CGFloat? {
        guard let left = point(3), let right = point(6) else { return nil }
        return abs(right.x - left.x)
    }

    private var bodyMidX: CGFloat {
        if let left = point(3), let right = point(6) { return (left.x + right.x) / 2 }
        return alignmentX ?? 0.5
    }

    private func outward(from x: CGFloat) -> String {
        x < bodyMidX ? "arrow.left" : "arrow.right"
    }

    private func cue(_ id: String, _ message: String, _ symbol: String, at anchor: Int? = nil) -> PoseCue {
        PoseCue(id: id, anchorIndex: anchor, symbol: symbol, message: message)
    }

    // Whole body visible, at a good distance, and centered.
    func framed() -> PoseCue? {
        let feedback = FramingFeedback(points: points, alignmentX: alignmentX)
        return feedback.isFramed ? nil : cue("frame", feedback.headline, feedback.symbol)
    }

    // Looser check for later steps: the body just needs to stay in view.
    func inView() -> PoseCue? {
        visibleCount >= 8 && hasBothFeet
            ? nil
            : cue("in-view", "Step back so both feet are visible", "arrow.backward")
    }

    func legsStraight() -> PoseCue? {
        for side in Self.sides {
            guard let angle = Self.angle(point(side.hip), point(side.knee), point(side.ankle)) else {
                return cue("legs-visible", "Keep both legs in view", "arrow.backward")
            }
            if angle < 155 {
                return cue("\(side.name)-straighten", "Straighten your \(side.name) leg", "arrow.down", at: side.knee)
            }
        }
        return nil
    }

    func armsDown() -> PoseCue? {
        for side in Self.sides {
            guard let shoulder = point(side.shoulder), let wrist = point(side.wrist) else {
                return cue("hands-visible", "Keep both hands in view", "viewfinder")
            }
            let hipY = point(side.hip)?.y ?? shoulder.y - 0.2
            if wrist.y > hipY + 0.06 {
                return cue("\(side.name)-lower", "Lower your \(side.name) arm to your side", "arrow.down", at: side.wrist)
            }
        }
        return nil
    }

    func armsOverhead() -> PoseCue? {
        for side in Self.sides {
            guard let shoulder = point(side.shoulder), let wrist = point(side.wrist) else {
                return cue("hands-visible", "Keep both hands in view", "viewfinder")
            }
            if wrist.y < max(point(0)?.y ?? 0, shoulder.y + 0.15) {
                return cue("\(side.name)-overhead", "Raise your \(side.name) arm overhead", "arrow.up", at: side.wrist)
            }
        }
        return nil
    }

    func wingsOpen() -> PoseCue? {
        let span = max(shoulderSpan ?? 0, 0.05)
        for side in Self.sides {
            guard let shoulder = point(side.shoulder), let wrist = point(side.wrist) else {
                return cue("hands-visible", "Keep both hands in view", "viewfinder")
            }
            let rise = wrist.y - shoulder.y
            if rise < -0.12 {
                return cue("\(side.name)-wing-up", "Raise your \(side.name) arm to shoulder height", "arrow.up", at: side.wrist)
            }
            if rise > 0.12 {
                return cue("\(side.name)-wing-down", "Lower your \(side.name) arm to shoulder height", "arrow.down", at: side.wrist)
            }
            if abs(wrist.x - shoulder.x) < span {
                return cue("\(side.name)-wing-out", "Reach your \(side.name) arm further out", outward(from: wrist.x), at: side.wrist)
            }
        }
        return nil
    }

    func kneeLifted() -> PoseCue? {
        guard let leftAnkle = point(12), let rightAnkle = point(15) else {
            return cue("feet-visible", "Keep both feet in view", "arrow.backward")
        }
        let kneeGap = point(11).flatMap { left in point(14).map { abs(left.y - $0.y) } } ?? 0
        if abs(leftAnkle.y - rightAnkle.y) > 0.07 || kneeGap > 0.06 {
            return nil
        }
        return cue("knee-lift", "Lift one knee up toward your hip", "arrow.up", at: 11)
    }

    func feetDown() -> PoseCue? {
        guard let leftAnkle = point(12), let rightAnkle = point(15) else {
            return cue("feet-visible", "Keep both feet in view", "arrow.backward")
        }
        guard abs(leftAnkle.y - rightAnkle.y) > 0.05 else { return nil }
        let raised = leftAnkle.y > rightAnkle.y ? 12 : 15
        return cue("foot-down", "Lower your foot to the floor", "arrow.down", at: raised)
    }

    func handsOnHips() -> PoseCue? {
        for side in Self.sides {
            guard let hip = point(side.hip), let wrist = point(side.wrist) else {
                return cue("hands-visible", "Keep both hands in view", "viewfinder")
            }
            if wrist.y > hip.y + 0.1 {
                return cue("\(side.name)-hip-down", "Lower your \(side.name) hand to your hip", "arrow.down", at: side.wrist)
            }
            if wrist.y < hip.y - 0.1 {
                return cue("\(side.name)-hip-up", "Raise your \(side.name) hand to your hip", "arrow.up", at: side.wrist)
            }
            if abs(wrist.x - hip.x) > 0.12 {
                let toward = wrist.x < hip.x ? "arrow.right" : "arrow.left"
                return cue("\(side.name)-hip-in", "Bring your \(side.name) hand in to your hip", toward, at: side.wrist)
            }
        }
        return nil
    }

    func wideStance() -> PoseCue? {
        guard let leftAnkle = point(12), let rightAnkle = point(15),
              let leftHip = point(10), let rightHip = point(13) else {
            return cue("feet-visible", "Keep both feet in view", "arrow.backward")
        }
        let hipSpan = max(abs(leftHip.x - rightHip.x), 0.04)
        if abs(leftAnkle.x - rightAnkle.x) > hipSpan * 2 {
            return nil
        }
        return cue("wide-stance", "Step your feet wider apart", outward(from: leftAnkle.x), at: 12)
    }

    func prayerHands() -> PoseCue? {
        guard let leftWrist = point(5), let rightWrist = point(8),
              let leftShoulder = point(3), let rightShoulder = point(6) else {
            return cue("hands-visible", "Keep both hands in view", "viewfinder")
        }
        let gap = hypot(leftWrist.x - rightWrist.x, leftWrist.y - rightWrist.y)
        if gap > max((shoulderSpan ?? 0) * 0.6, 0.06) {
            let toward = leftWrist.x < rightWrist.x ? "arrow.right" : "arrow.left"
            return cue("palms-together", "Bring your palms together", toward, at: 5)
        }
        let handsY = (leftWrist.y + rightWrist.y) / 2
        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let hipY = [point(10), point(13)].compactMap { $0?.y }.max() ?? shoulderY - 0.25
        if handsY > shoulderY + 0.03 {
            return cue("palms-lower", "Lower your hands to your chest", "arrow.down", at: 5)
        }
        if handsY < hipY {
            return cue("palms-raise", "Raise your hands to your chest", "arrow.up", at: 5)
        }
        return nil
    }

    /// Both knees bent past `maxAngle` degrees (chair pose, frog squat).
    func kneesBent(below maxAngle: Double) -> PoseCue? {
        for side in Self.sides {
            guard let angle = Self.angle(point(side.hip), point(side.knee), point(side.ankle)) else {
                return cue("legs-visible", "Keep both legs in view", "arrow.backward")
            }
            if angle > maxAngle {
                return cue("\(side.name)-bend", "Bend your \(side.name) knee and sink lower", "arrow.down", at: side.knee)
            }
        }
        return nil
    }

    /// At least one knee deeply bent, as in a lunge or warrior pose.
    func oneKneeBent(below maxAngle: Double) -> PoseCue? {
        let angles = Self.sides.map { Self.angle(point($0.hip), point($0.knee), point($0.ankle)) }
        guard let left = angles[0], let right = angles[1] else {
            return cue("legs-visible", "Keep both legs in view", "arrow.backward")
        }
        if min(left, right) < maxAngle {
            return nil
        }
        let side = left <= right ? Self.sides[0] : Self.sides[1]
        return cue("front-knee", "Bend your front knee deeper", "arrow.down", at: side.knee)
    }

    /// Torso folded down over the legs with hands low.
    func forwardFold() -> PoseCue? {
        guard let leftHip = point(10) ?? point(13), let leftKnee = point(11) ?? point(14) else {
            return cue("legs-visible", "Keep your hips and legs in view", "arrow.backward")
        }
        let hipY = [point(10), point(13)].compactMap { $0?.y }.max() ?? leftHip.y
        let shoulderY = [point(3), point(6)].compactMap { $0?.y }.max()
        if let shoulderY, shoulderY > hipY + 0.08 {
            return cue("fold", "Fold forward from your hips", "arrow.down", at: point(3) != nil ? 3 : 6)
        }
        let wristY = [point(5), point(8)].compactMap { $0?.y }.min()
        if let wristY, wristY > leftKnee.y + 0.05 {
            return cue("fold-hands", "Let your hands hang toward your shins", "arrow.down", at: point(5) != nil ? 5 : 8)
        }
        return nil
    }

    /// One hand reaching down toward the shin while the other reaches up (triangle pose).
    func triangleArms() -> PoseCue? {
        guard let leftWrist = point(5), let rightWrist = point(8),
              let leftShoulder = point(3), let rightShoulder = point(6) else {
            return cue("hands-visible", "Keep both hands in view", "viewfinder")
        }
        // Whichever hand is lower is the one reaching down.
        let leftIsLow = leftWrist.y < rightWrist.y
        let lowWrist = leftIsLow ? leftWrist : rightWrist
        let highWrist = leftIsLow ? rightWrist : leftWrist
        let highShoulder = leftIsLow ? rightShoulder : leftShoulder
        let lowKnee = point(leftIsLow ? 11 : 14)
        let lowSide = leftIsLow ? "left" : "right"
        let highSide = leftIsLow ? "right" : "left"

        if let lowKnee, lowWrist.y > lowKnee.y + 0.08 {
            return cue("triangle-down", "Tilt sideways and reach your \(lowSide) hand toward your shin", "arrow.down", at: leftIsLow ? 5 : 8)
        }
        if highWrist.y < highShoulder.y + 0.12 {
            return cue("triangle-up", "Reach your \(highSide) arm up to the sky", "arrow.up", at: leftIsLow ? 8 : 5)
        }
        return nil
    }

    /// Forearms wrapped with hands together in front of the face (eagle arms).
    func eagleArms() -> PoseCue? {
        guard let leftWrist = point(5), let rightWrist = point(8),
              let leftShoulder = point(3), let rightShoulder = point(6) else {
            return cue("hands-visible", "Keep both hands in view", "viewfinder")
        }
        let gap = hypot(leftWrist.x - rightWrist.x, leftWrist.y - rightWrist.y)
        if gap > max((shoulderSpan ?? 0) * 0.7, 0.07) {
            let toward = leftWrist.x < rightWrist.x ? "arrow.right" : "arrow.left"
            return cue("eagle-wrap", "Cross your arms and press your palms together", toward, at: 5)
        }
        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        if (leftWrist.y + rightWrist.y) / 2 < shoulderY + 0.02 {
            return cue("eagle-lift", "Lift your wrapped hands in front of your face", "arrow.up", at: 5)
        }
        return nil
    }

    /// One leg lifted to about hip height, above the standing knee (hand-to-toe pose).
    func legHighLift() -> PoseCue? {
        guard let leftAnkle = point(12), let rightAnkle = point(15),
              let leftKnee = point(11), let rightKnee = point(14) else {
            return cue("legs-visible", "Keep both legs in view", "arrow.backward")
        }
        let leftIsRaised = leftAnkle.y > rightAnkle.y
        let raisedAnkle = leftIsRaised ? leftAnkle : rightAnkle
        let standingKnee = leftIsRaised ? rightKnee : leftKnee
        if raisedAnkle.y > standingKnee.y + 0.04 {
            return nil
        }
        return cue("leg-high", "Lift your leg higher, toward hip height", "arrow.up", at: leftIsRaised ? 12 : 15)
    }

    private static func angle(_ first: CGPoint?, _ vertex: CGPoint?, _ second: CGPoint?) -> Double? {
        guard let first, let vertex, let second else { return nil }

        let firstVector = CGVector(dx: first.x - vertex.x, dy: first.y - vertex.y)
        let secondVector = CGVector(dx: second.x - vertex.x, dy: second.y - vertex.y)
        let denominator = hypot(firstVector.dx, firstVector.dy) * hypot(secondVector.dx, secondVector.dy)
        guard denominator > 0.001 else { return nil }

        let cosine = max(-1, min(1, (firstVector.dx * secondVector.dx + firstVector.dy * secondVector.dy) / denominator))
        return acos(cosine) * 180 / .pi
    }
}

// MARK: - Audio

/// Speaks directions and plays completion sounds.
@MainActor
private final class VoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-US")
    private(set) var lastSpokenAt = Date.distantPast

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func say(_ text: String, delay: TimeInterval = 0) {
        lastSpokenAt = Date()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.47
        utterance.preUtteranceDelay = delay
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func playStepComplete() { play("Glass") }
    func playLevelComplete() { play("Hero") }

    private func play(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.stop()
        sound.play()
    }
}

// MARK: - Camera and coaching

@MainActor
private final class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var points: [CGPoint?] = []
    @Published var jointAngles: [Int: Double] = [:]
    @Published var alignmentX: CGFloat?
    @Published var message: String?
    @Published private(set) var exercise: Exercise
    @Published private(set) var completedSteps: Set<Int> = []
    @Published private(set) var currentCue: PoseCue?
    @Published private(set) var stepIntoFramePrompt: PoseCue?
    @Published private(set) var isUserAway = false
    @Published private(set) var isCelebrating = false
    @Published private(set) var celebrationTitle = ""
    @Published private(set) var allExercisesComplete = false
    /// Called once when the user finishes every step of an exercise.
    var onExerciseComplete: ((Exercise) -> Void)?

    var currentStepIndex: Int? {
        guard !allExercisesComplete else { return nil }
        return exercise.steps.indices.first { !completedSteps.contains($0) }
    }

    private let firstExercise: Exercise
    private let voiceCoach = VoiceCoach()
    private var hasBegun = false
    private var poseHeldSince: Date?
    private var lastPersonSeenAt = Date()
    private var lastSeenAlignmentX: CGFloat?
    private var lastStepIntoFrameSpokenAt = Date.distantPast
    // How long a pose must stay correct before the step counts.
    private let holdDuration: TimeInterval = 1.0
    // Silence before the coach repeats the current direction or correction.
    private let reminderInterval: TimeInterval = 10
    private let queue = DispatchQueue(label: "camera.frames")
    private var configured = false
    nonisolated(unsafe) private var lastRequest = Date.distantPast

    init(exercise: Exercise) {
        self.exercise = exercise
        self.firstExercise = exercise
        super.init()
    }

    static let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (0, 17), (17, 18), (0, 16),
        (16, 3), (3, 4), (4, 5), (16, 6), (6, 7), (7, 8),
        (3, 10), (10, 11), (11, 12), (6, 13), (13, 14), (14, 15),
        (10, 13)
    ]

    static let angleJointIndices = [4, 7, 11, 14]
    nonisolated private static let angleDefinitions = [
        (3, 4, 5), (6, 7, 8), (10, 11, 12), (13, 14, 15)
    ]

    func restart() {
        exercise = firstExercise
        completedSteps = []
        allExercisesComplete = false
        poseHeldSince = nil
        announceExercise(greeting: "Let's go again.")
    }

    private func beginCoaching() {
        guard !hasBegun else { return }
        hasBegun = true
        lastPersonSeenAt = Date()
        announceExercise(greeting: "Welcome.")
    }

    // MARK: Frame processing

    private func process(points: [CGPoint?], alignmentX: CGFloat?) {
        let now = Date()
        let reader = PoseReader(points: points, alignmentX: alignmentX)

        updateDistance(reader)
        guard hasBegun, !isCelebrating else { return }

        if reader.hasPerson {
            lastPersonSeenAt = now
            if let alignmentX { lastSeenAlignmentX = alignmentX }
            if stepIntoFramePrompt != nil {
                // The user is back: clear the arrow and repeat what to do next.
                stepIntoFramePrompt = nil
                announceCurrentStep()
            }
        } else if now.timeIntervalSince(lastPersonSeenAt) > 1.5 {
            let prompt = makeStepIntoFramePrompt()
            if stepIntoFramePrompt != prompt { stepIntoFramePrompt = prompt }
            if now.timeIntervalSince(lastStepIntoFrameSpokenAt) > 12 {
                lastStepIntoFrameSpokenAt = now
                voiceCoach.say("\(prompt.message).")
            }
        }

        guard let stepIndex = currentStepIndex else { return }
        let step = exercise.steps[stepIndex]
        let fix = reader.hasPerson ? step.check(reader) : nil
        if currentCue != fix { currentCue = fix }

        guard reader.hasPerson else {
            poseHeldSince = nil
            return
        }

        if fix == nil {
            let since = poseHeldSince ?? now
            poseHeldSince = since
            if now.timeIntervalSince(since) >= holdDuration {
                completeStep(stepIndex)
            }
            return
        }
        poseHeldSince = nil

        if !voiceCoach.isSpeaking, now.timeIntervalSince(voiceCoach.lastSpokenAt) > reminderInterval {
            voiceCoach.say(fix.map { "\($0.message)." } ?? step.spoken)
        }
    }

    /// Points toward where the user was last seen, so they know which way to walk back in.
    private func makeStepIntoFramePrompt() -> PoseCue {
        guard let lastSeenAlignmentX else {
            return PoseCue(id: "enter", anchorIndex: nil, symbol: "arrow.down", message: "Step into the frame")
        }
        if lastSeenAlignmentX < 0.5 {
            return PoseCue(id: "enter-right", anchorIndex: nil, symbol: "arrow.right", message: "Step into the frame, move right")
        }
        return PoseCue(id: "enter-left", anchorIndex: nil, symbol: "arrow.left", message: "Step into the frame, move left")
    }

    /// Seeing both feet means the user has walked back into position; a wide close-up of the
    /// shoulders means they're back at the computer. In between, keep the current size.
    private func updateDistance(_ reader: PoseReader) {
        if reader.visibleCount >= 8, reader.hasBothFeet {
            if !isUserAway { isUserAway = true }
        } else if let span = reader.shoulderSpan, span > 0.25 {
            if isUserAway { isUserAway = false }
        }
    }

    // MARK: Progress

    private func completeStep(_ index: Int) {
        completedSteps.insert(index)
        poseHeldSince = nil
        currentCue = nil

        if currentStepIndex == nil {
            completeExercise()
        } else {
            voiceCoach.playStepComplete()
            let praise = ["Nice.", "Great.", "Perfect.", "Well done."].randomElement() ?? "Nice."
            announceCurrentStep(prefix: "\(praise) Flow into ", delay: 0.6)
        }
    }

    private func completeExercise() {
        let finished = exercise
        let next = finished.next
        onExerciseComplete?(finished)
        voiceCoach.playLevelComplete()
        celebrationTitle = "\(finished.name) complete"
        isCelebrating = true

        if let next {
            voiceCoach.say("\(finished.name), complete! Next up, \(next.name), a \(next.difficulty.title.lowercased()) flow.", delay: 0.8)
        } else {
            voiceCoach.say("\(finished.name), complete! You've finished every flow.", delay: 0.8)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            self.isCelebrating = false
            self.poseHeldSince = nil
            if let next {
                self.exercise = next
                self.completedSteps = []
                self.announceExercise(greeting: nil)
            } else {
                self.allExercisesComplete = true
            }
        }
    }

    private func announceExercise(greeting: String?) {
        let opening = greeting.map { "\($0) " } ?? ""
        announceCurrentStep(
            prefix: "\(opening)\(exercise.difficulty.title) flow: \(exercise.name). \(exercise.intro) Begin with "
        )
    }

    private func announceCurrentStep(prefix: String = "", delay: TimeInterval = 0) {
        guard let index = currentStepIndex else { return }
        voiceCoach.say(
            "\(prefix)step \(index + 1) of \(exercise.steps.count). \(exercise.steps[index].spoken)",
            delay: delay
        )
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.configureAndRun()
                    } else {
                        self.message = "Allow camera access in System Settings → Privacy & Security → Camera."
                    }
                }
            }
        default:
            message = "Allow camera access in System Settings → Privacy & Security → Camera."
        }
    }

    private func configureAndRun() {
        guard !configured else {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            message = "No available camera found."
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            message = "Could not start camera."
            return
        }

        session.addOutput(output)
        session.commitConfiguration()
        configured = true
        message = nil
        session.startRunning()
        beginCoaching()
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        voiceCoach.stop()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard Date().timeIntervalSince(lastRequest) > 0.08 else { return }
        lastRequest = Date()

        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up).perform([request])
            let recognized = try request.results?.first?.recognizedPoints(.all) ?? [:]
            let names: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .leftEye, .leftEar, .leftShoulder, .leftElbow, .leftWrist,
                .rightShoulder, .rightElbow, .rightWrist, .root, .leftHip,
                .leftKnee, .leftAnkle, .rightHip, .rightKnee, .rightAnkle,
                .neck, .rightEye, .rightEar
            ]

            let visible: [CGPoint?] = names.map { name in
                guard let point = recognized[name], point.confidence > 0.2 else { return nil }
                return CGPoint(x: point.location.x, y: point.location.y)
            }

            let angles = Self.angleDefinitions.reduce(into: [Int: Double]()) { result, definition in
                guard let angle = Self.angle(
                    first: visible[definition.0],
                    vertex: visible[definition.1],
                    second: visible[definition.2]
                ) else {
                    return
                }
                result[definition.1] = angle
            }

            let alignmentX: CGFloat?
            if let leftHip = visible[10], let rightHip = visible[13] {
                alignmentX = (leftHip.x + rightHip.x) / 2
            } else {
                alignmentX = visible[9]?.x
            }

            Task { @MainActor in
                self.points = visible
                self.jointAngles = angles
                self.alignmentX = alignmentX
                self.process(points: visible, alignmentX: alignmentX)
            }
        } catch {
            // A frame can fail during camera reconfiguration; the next frame retries.
        }
    }

    nonisolated private static func angle(
        first: CGPoint?,
        vertex: CGPoint?,
        second: CGPoint?
    ) -> Double? {
        guard let first, let vertex, let second else { return nil }

        let firstVector = CGVector(dx: first.x - vertex.x, dy: first.y - vertex.y)
        let secondVector = CGVector(dx: second.x - vertex.x, dy: second.y - vertex.y)
        let firstLength = hypot(firstVector.dx, firstVector.dy)
        let secondLength = hypot(secondVector.dx, secondVector.dy)
        guard firstLength > 0.001, secondLength > 0.001 else { return nil }

        let cosine = max(
            -1,
            min(1, (firstVector.dx * secondVector.dx + firstVector.dy * secondVector.dy) / (firstLength * secondLength))
        )
        return acos(cosine) * 180 / .pi
    }
}
