import SwiftUI
import AVFoundation
import Vision

private struct BlackGlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.black.opacity(0.28))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: .black.opacity(0.32), radius: 14, y: 7)
    }
}

private extension View {
    func blackGlass(cornerRadius: CGFloat = 18) -> some View {
        modifier(BlackGlassCard(cornerRadius: cornerRadius))
    }
}


struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var isShowingProfile = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)

            PoseOverlay(
                points: camera.points,
                jointAngles: camera.jointAngles
            )
            .opacity(camera.isCelebrating ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: camera.isCelebrating)

            LimbGuidanceOverlay(points: camera.points)
                .opacity(camera.isCelebrating ? 0 : 1)

            if camera.isCelebrating {
                ButterflyCelebration()
            }

            LinearGradient(
                colors: [.black.opacity(0.28), .clear, .black.opacity(0.46)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            WorkoutDashboard(
                points: camera.points,
                completedSteps: camera.completedSteps,
                alignmentX: camera.alignmentX,
                isShowingProfile: $isShowingProfile
            )

            if let message = camera.message {
                Text(message)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .blackGlass(cornerRadius: 12)
                    .padding()
            }
        }
        .task {
            // Give SwiftUI one run-loop turn to present the window before camera setup begins.
            await Task.yield()
            camera.start()
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $isShowingProfile) {
            ProfileView()
        }
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
                            with: .color(.red.opacity(0.62)),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                    }

                    for point in scaledPoints.compactMap({ $0 }) {
                        let joint = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                        context.fill(Path(ellipseIn: joint), with: .color(.cyan))
                        context.stroke(
                            Path(ellipseIn: joint),
                            with: .color(.white.opacity(0.75)),
                            lineWidth: 1
                        )
                    }
                }

                ForEach(CameraModel.angleJointIndices, id: \.self) { index in
                    if index < scaledPoints.count,
                       let point = scaledPoints[index],
                       let angle = jointAngles[index] {
                        Text("\(Int(angle.rounded()))°")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.64), in: Capsule())
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

    var body: some View {
        GeometryReader { proxy in
            let scaledPoints = points.map {
                $0.map { CGPoint(x: $0.x * proxy.size.width, y: (1 - $0.y) * proxy.size.height) }
            }

            ForEach(PoseCoach.cues(for: points)) { cue in
                if cue.anchorIndex < scaledPoints.count,
                   let anchor = scaledPoints[cue.anchorIndex] {
                    LimbDirectionCue(cue: cue)
                        .position(
                            x: min(max(anchor.x + cue.offset.width, 82), proxy.size.width - 82),
                            y: min(max(anchor.y + cue.offset.height, 52), proxy.size.height - 52)
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}


private struct ButterflyCelebration: View {
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

                Text("Pose complete")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .blackGlass(cornerRadius: 22)
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
        .accessibilityLabel("Pose complete celebration")
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
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .blackGlass(cornerRadius: 20)
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

private struct PoseCue: Identifiable {
    let id: String
    let anchorIndex: Int
    let symbol: String
    let message: String
    let offset: CGSize

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

private enum PoseCoach {
    static func cues(for points: [CGPoint?]) -> [PoseCue] {
        var cues: [PoseCue] = []

        addWingCue(
            shoulderIndex: 3,
            wristIndex: 5,
            side: .left,
            points: points,
            cues: &cues
        )
        addWingCue(
            shoulderIndex: 6,
            wristIndex: 8,
            side: .right,
            points: points,
            cues: &cues
        )
        addLegCue(kneeIndex: 11, side: .left, points: points, cues: &cues)
        addLegCue(kneeIndex: 14, side: .right, points: points, cues: &cues)

        return Array(cues.prefix(3))
    }

    private static func addWingCue(
        shoulderIndex: Int,
        wristIndex: Int,
        side: HorizontalSide,
        points: [CGPoint?],
        cues: inout [PoseCue]
    ) {
        guard let shoulder = point(at: shoulderIndex, in: points),
              let wrist = point(at: wristIndex, in: points) else {
            return
        }

        if wrist.y < shoulder.y - 0.06 {
            cues.append(
                PoseCue(
                    id: "\(side.rawValue)-raise",
                    anchorIndex: wristIndex,
                    symbol: "arrow.up",
                    message: "Raise (side.rawValue) wing",
                    offset: CGSize(width: 0, height: -54)
                )
            )
        } else if side == .left, wrist.x > shoulder.x - 0.16 {
            cues.append(
                PoseCue(
                    id: "left-open",
                    anchorIndex: wristIndex,
                    symbol: "arrow.left",
                    message: "Open left wing",
                    offset: CGSize(width: -78, height: -14)
                )
            )
        } else if side == .right, wrist.x < shoulder.x + 0.16 {
            cues.append(
                PoseCue(
                    id: "right-open",
                    anchorIndex: wristIndex,
                    symbol: "arrow.right",
                    message: "Open right wing",
                    offset: CGSize(width: 78, height: -14)
                )
            )
        }
    }

    private static func addLegCue(
        kneeIndex: Int,
        side: HorizontalSide,
        points: [CGPoint?],
        cues: inout [PoseCue]
    ) {
        let indices = side == .left ? (10, 11, 12) : (13, 14, 15)
        guard let angle = angle(
            first: point(at: indices.0, in: points),
            vertex: point(at: indices.1, in: points),
            second: point(at: indices.2, in: points)
        ), angle < 155 else {
            return
        }

        cues.append(
            PoseCue(
                id: "\(side.rawValue)-leg",
                anchorIndex: kneeIndex,
                symbol: "arrow.down",
                message: "Lengthen (side.rawValue) leg",
                offset: CGSize(width: 0, height: 54)
            )
        )
    }

    private static func point(at index: Int, in points: [CGPoint?]) -> CGPoint? {
        guard index < points.count else { return nil }
        return points[index]
    }

    private static func angle(first: CGPoint?, vertex: CGPoint?, second: CGPoint?) -> Double? {
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

    private enum HorizontalSide: String {
        case left
        case right
    }
}


private struct FramingGuidanceCard: View {
    let points: [CGPoint?]
    let alignmentX: CGFloat?

    private var feedback: FramingFeedback {
        FramingFeedback(points: points, alignmentX: alignmentX)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: feedback.symbol)
                    .font(.system(size: feedback.isDistant ? 21 : 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(feedback.headline)
                    .font(.system(size: feedback.isDistant ? 19 : 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(feedback.detail)
                .font(.system(size: feedback.isDistant ? 15 : 12))
                .foregroundStyle(.white.opacity(0.75))

            Divider()
                .overlay(.white.opacity(0.18))

            Label(
                "Keep the camera level at chest height, about 6–8 ft away.",
                systemImage: "camera.metering.center.weighted"
            )
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: 330, alignment: .leading)
        .padding(14)
        .blackGlass(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

private struct FramingFeedback {
    let headline: String
    let detail: String
    let symbol: String
    let isDistant: Bool

    init(points: [CGPoint?], alignmentX: CGFloat?) {
        let visiblePoints = points.compactMap { $0 }
        let hasBothFeet = points.indices.contains(12) && points.indices.contains(15)
            && points[12] != nil && points[15] != nil

        guard visiblePoints.count >= 8 else {
            headline = "Step into the frame"
            detail = "Face the camera so it can find your shoulders, hips, and legs."
            symbol = "viewfinder"
            isDistant = false
            return
        }

        guard hasBothFeet else {
            headline = "Step back until both feet are visible"
            detail = "Leave a small margin above your head and below your feet."
            symbol = "arrow.backward"
            isDistant = false
            return
        }

        let top = visiblePoints.map(\.y).max() ?? 1
        let bottom = visiblePoints.map(\.y).min() ?? 0
        let bodyHeight = top - bottom
        isDistant = bodyHeight < 0.55

        if bodyHeight > 0.86 {
            headline = "Step back slightly"
            detail = "Your body fills too much of the view for reliable joint tracking."
            symbol = "arrow.backward"
        } else if bodyHeight < 0.55 {
            headline = "Move a little closer"
            detail = "Fill more of the frame while keeping your entire body visible."
            symbol = "arrow.forward"
        } else if let alignmentX, alignmentX < 0.42 {
            headline = "Move right to center"
            detail = "Keep equal space on each side of your body for better accuracy."
            symbol = "arrow.right"
        } else if let alignmentX, alignmentX > 0.58 {
            headline = "Move left to center"
            detail = "Keep equal space on each side of your body for better accuracy."
            symbol = "arrow.left"
        } else {
            headline = "Whole body framed"
            detail = "Great distance and centering. Hold this position for the most accurate coaching."
            symbol = "checkmark.viewfinder"
        }
    }
}

private struct WorkoutDashboard: View {
    let points: [CGPoint?]
    let completedSteps: Set<Int>
    let alignmentX: CGFloat?
    @Binding var isShowingProfile: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Spacer(minLength: 60)

                ProgressHeader(completedSteps: completedSteps)
                    .frame(maxWidth: 650)

                Spacer(minLength: 16)

                Button {
                    isShowingProfile = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 27))
                        .foregroundStyle(.white, .cyan)
                        .padding(9)
                        .blackGlass(cornerRadius: 22)
                        .accessibilityLabel("Open profile")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)

            FramingGuidanceCard(points: points, alignmentX: alignmentX)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 26)
                .padding(.top, 14)

            Spacer(minLength: 16)

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    PosePostureChecklist(completedSteps: completedSteps)
                        .padding(13)
                        .blackGlass(cornerRadius: 16)

                    FloorAlignmentIndicator(alignmentX: alignmentX)
                }

                Spacer(minLength: 20)

                WorkoutLevelCard(completedSteps: completedSteps)
            }
            .padding(26)
        }
    }
}

private struct ProgressHeader: View {
    let completedSteps: Set<Int>
    private let checkpoints = ["Frame", "Lengthen", "Open wings", "Hold", "Complete"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(checkpoints.enumerated()), id: \.offset) { index, checkpoint in
                let isComplete = index == 4
                    ? completedSteps.isSuperset(of: Set(0...3))
                    : completedSteps.contains(index)

                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(isComplete ? Color.white : Color.white.opacity(0.22))
                            .frame(width: 14, height: 14)

                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }

                    Text(checkpoint)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if index < checkpoints.count - 1 {
                    Rectangle()
                        .fill(completedSteps.contains(index) ? Color.white : Color.white.opacity(0.22))
                        .frame(height: 1)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .blackGlass(cornerRadius: 22)
        .accessibilityLabel("\(completedSteps.count) of 4 coaching steps complete")
    }
}

private struct FloorAlignmentIndicator: View {
    let alignmentX: CGFloat?

    private var status: String {
        guard let alignmentX else { return "Step into view" }
        if alignmentX < 0.42 { return "Move right" }
        if alignmentX > 0.58 { return "Move left" }
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
                .foregroundStyle(.white)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.26))
                        .frame(height: 3)

                    Capsule()
                        .fill(.cyan.opacity(0.7))
                        .frame(width: proxy.size.width * 0.24, height: 3)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    Circle()
                        .fill(status == "Centered — great framing" ? .cyan : .orange)
                        .frame(width: 10, height: 10)
                        .position(x: proxy.size.width * markerPosition, y: proxy.size.height / 2)
                }
            }
            .frame(width: 230, height: 10)

            Text(status)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(15)
        .blackGlass(cornerRadius: 16)
    }
}

private struct WorkoutLevelCard: View {
    let completedSteps: Set<Int>

    private var levelOneComplete: Bool {
        completedSteps.isSuperset(of: Set(0...3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LEVEL 1")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.cyan)

                    Text("Origami Crane · Wings")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Stage 2 of 3 · Stand tall and open your arms wide like crane wings.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 225, alignment: .leading)
                }

                Spacer(minLength: 4)

                OrigamiAchievementPlaceholder()
            }

            CraneLevelPath(isFlightUnlocked: levelOneComplete)

            NextLevelPreview(isUnlocked: levelOneComplete)
        }
        .padding(16)
        .frame(maxWidth: 390, alignment: .leading)
        .blackGlass(cornerRadius: 18)
    }
}

private struct PosePostureChecklist: View {
    let completedSteps: Set<Int>
    private let postures = [
        "Frame your head and both feet.",
        "Lengthen both legs.",
        "Open both arms at shoulder height.",
        "Hold the full crane-wings shape."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Pose checklist")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))

            ForEach(Array(postures.enumerated()), id: \.offset) { index, posture in
                HStack(spacing: 7) {
                    Image(systemName: completedSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(completedSteps.contains(index) ? .white : .white.opacity(0.38))
                    Text(posture)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
    }
}


private struct CraneLevelPath: View {
    let isFlightUnlocked: Bool

    var body: some View {
        HStack(spacing: 5) {
            LevelPathItem(title: "Ground", isComplete: true)
            Capsule()
                .fill(.white.opacity(0.26))
                .frame(height: 1)
            LevelPathItem(title: "Wings", isComplete: true)
            Capsule()
                .fill(isFlightUnlocked ? .white : .white.opacity(0.26))
                .frame(height: 1)
            LevelPathItem(title: "Flight", isComplete: isFlightUnlocked)
        }
        .accessibilityLabel("Crane path: Ground, Wings, Flight")
    }
}

private struct LevelPathItem: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(isComplete ? .white : .white.opacity(0.35))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}


private struct NextLevelPreview: View {
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(isUnlocked ? "LEVEL 2 UNLOCKED" : "NEXT LEVEL")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.68))
                Text("Origami Crane · Flight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: "bird.fill")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(10)
        .blackGlass(cornerRadius: 13)
        .accessibilityLabel(
            isUnlocked
                ? "Level 2 unlocked: Origami Crane Flight"
                : "Next level: Origami Crane Flight, locked"
        )
    }
}

private struct OrigamiAchievementPlaceholder: View {
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(.white.opacity(0.16))
                    .frame(width: 72, height: 72)

                Image(systemName: "bird.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.cyan)
                    .rotationEffect(.degrees(-12))
            }

            Text("Origami Crane")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement placeholder: Origami Crane")
    }
}

private struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.cyan, .blue)

            Text("Your Yoga Profile")
                .font(.title2.weight(.bold))

            VStack(spacing: 12) {
                ProfileStatistic(title: "Expertise", value: "Level 1 · Beginner", symbol: "figure.yoga")
                ProfileStatistic(title: "Level mascot", value: "Origami Crane", symbol: "bird.fill")
                ProfileStatistic(title: "Daily yoga streak", value: "3 days", symbol: "flame.fill")
            }

            Spacer()
        }
        .padding(28)
        .frame(minWidth: 360, minHeight: 420)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [.black, Color(red: 0.03, green: 0.06, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
                .foregroundStyle(.cyan)
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
        .blackGlass(cornerRadius: 13)
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


private struct PoseAssessment {
    let achievedSteps: Set<Int>

    init(points: [CGPoint?], alignmentX: CGFloat?) {
        let hasFeet = points.count > 15 && points[12] != nil && points[15] != nil
        let visible = points.compactMap { $0 }
        let height = (visible.map(\.y).max() ?? 0) - (visible.map(\.y).min() ?? 0)
        let isCentered = alignmentX.map { (0.42...0.58).contains($0) } ?? false
        let isFramed = hasFeet && (0.55...0.86).contains(height) && isCentered

        let leftKnee = Self.angle(first: Self.point(10, in: points), vertex: Self.point(11, in: points), second: Self.point(12, in: points))
        let rightKnee = Self.angle(first: Self.point(13, in: points), vertex: Self.point(14, in: points), second: Self.point(15, in: points))
        let hasLongLegs = (leftKnee ?? 0) > 155 && (rightKnee ?? 0) > 155

        let hasOpenWings = Self.hasOpenWings(points: points)

        var completed: Set<Int> = []
        if isFramed { completed.insert(0) }
        if hasLongLegs { completed.insert(1) }
        if hasOpenWings { completed.insert(2) }
        if isFramed && hasLongLegs && hasOpenWings { completed.insert(3) }
        achievedSteps = completed
    }

    private static func point(_ index: Int, in points: [CGPoint?]) -> CGPoint? {
        guard index < points.count else { return nil }
        return points[index]
    }

    private static func hasOpenWings(points: [CGPoint?]) -> Bool {
        guard let leftShoulder = point(3, in: points),
              let rightShoulder = point(6, in: points),
              let leftWrist = point(5, in: points),
              let rightWrist = point(8, in: points) else {
            return false
        }

        // Compare spans rather than screen-left/screen-right joints so mirrored cameras work reliably.
        let shoulderSpan = abs(rightShoulder.x - leftShoulder.x)
        let wristSpan = abs(rightWrist.x - leftWrist.x)
        let wristsAreLevel = abs(leftWrist.y - leftShoulder.y) < 0.24
            && abs(rightWrist.y - rightShoulder.y) < 0.24
        return shoulderSpan > 0.04 && wristSpan > shoulderSpan * 2.0 && wristsAreLevel
    }

    private static func angle(first: CGPoint?, vertex: CGPoint?, second: CGPoint?) -> Double? {
        guard let first, let vertex, let second else { return nil }

        let firstVector = CGVector(dx: first.x - vertex.x, dy: first.y - vertex.y)
        let secondVector = CGVector(dx: second.x - vertex.x, dy: second.y - vertex.y)
        let denominator = hypot(firstVector.dx, firstVector.dy) * hypot(secondVector.dx, secondVector.dy)
        guard denominator > 0.001 else { return nil }

        let cosine = max(-1, min(1, (firstVector.dx * secondVector.dx + firstVector.dy * secondVector.dy) / denominator))
        return acos(cosine) * 180 / .pi
    }
}


@MainActor
private final class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var points: [CGPoint?] = []
    @Published var jointAngles: [Int: Double] = [:]
    @Published var alignmentX: CGFloat?
    @Published var completedSteps: Set<Int> = []
    @Published var isCelebrating = false
    @Published var message: String?
    private var hasCelebratedCurrentLevel = false
    private let queue = DispatchQueue(label: "camera.frames")
    private var configured = false
    nonisolated(unsafe) private var lastRequest = Date.distantPast

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
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
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

            let achievedSteps = PoseAssessment(points: visible, alignmentX: alignmentX).achievedSteps

            Task { @MainActor in
                self.points = visible
                self.jointAngles = angles
                self.alignmentX = alignmentX
                self.completedSteps.formUnion(achievedSteps)

                if self.completedSteps.isSuperset(of: Set(0...3)), !self.hasCelebratedCurrentLevel {
                    self.hasCelebratedCurrentLevel = true
                    self.isCelebrating = true

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        self.isCelebrating = false
                    }
                }
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
