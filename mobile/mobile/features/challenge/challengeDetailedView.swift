// challengeDetailView.swift
// mobile
//
//

import SwiftUI
import SpriteKit

// MARK: - Challenge Detail (UI Model)
// Keep these lightweight so the screen can compile without additional files.
// Later you can replace these with your real Supabase records / ViewModel outputs.
struct ChallengeDetailUIModel {
    let challengeId: UUID
    let title: String
    let description: String
    let startDateText: String   // "2/1"
    let endDateText: String     // "2/28"
    
    // Shared (everyone sees same)
    let overallProgress: Double // 0.0 ~ 1.0
    let dayIndexText: String    // "Day 12 of 30"
    let weekly: [WeeklyDayUI]   // 7 items (Sun~Sat)
    
    // Shared jar content (computed for now)
    let jarItems: [JarItemUI]   // each item = one emoji drop
    
    // Personal (current user)
    var todayTasks: [TodayTaskUI]
}

struct WeeklyDayUI: Identifiable {
    enum Status { case all, partial, none }
    let id = UUID()
    let weekday: String  // "SUN"
    let day: String      // "23"
    let status: Status
    let isToday: Bool
}

struct JarItemUI: Identifiable {
    let id: UUID
    let emoji: String
}

struct TodayTaskUI: Identifiable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    let canAttachProof: Bool // kept for future, not used now
}

// MARK: - View
struct ChallengeDetailView: View {
    // In real usage, you will likely inject a ViewModel.
    // For now, we inject a UI model so this file stays independent.
    @State private var ui: ChallengeDetailUIModel
    
    // Header actions (hook up later)
    var onBack: (() -> Void)? = nil
    var onTapCalendar: (() -> Void)? = nil
    var onTapFavorite: (() -> Void)? = nil
    
    // Local: button enabled when all tasks completed
    private var isDayComplete: Bool {
        ui.todayTasks.allSatisfy { $0.isCompleted }
    }
    
    init(
        ui: ChallengeDetailUIModel,
        onBack: (() -> Void)? = nil,
        onTapCalendar: (() -> Void)? = nil,
        onTapFavorite: (() -> Void)? = nil
    ) {
        _ui = State(initialValue: ui)
        self.onBack = onBack
        self.onTapCalendar = onTapCalendar
        self.onTapFavorite = onTapFavorite
    }
    
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                        .padding(.top, 8)
                    
                    jarSection
                    
                    challengeInfoSection
                    
                    overallProgressSection
                    
                    weeklyProgressSection
                    
                    todaysTaskSection
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Sections
private extension ChallengeDetailView {
    
    var headerSection: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") {
                onBack?()
            }
            
            Spacer()
            
            CircleIconButton(systemName: "star") {
                onTapFavorite?()
            }
        }
    }
    
    var jarSection: some View {
        // Shared section: everyone sees the same jar content.
        ChallengeJarView(
            jarItems: ui.jarItems,
            isSealed: isSealedTodayFromWeekly(ui.weekly)
        )
        .frame(height: 380)
    }
    
    var challengeInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date pill
            Text("\(ui.startDateText) - \(ui.endDateText)")
                .foregroundColor(AppColors.neutral1000)
                .appText(AppFont.labelS)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.green300)
                .cornerRadius(999)
            
            Text(ui.title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.title1)
            
            Text(ui.description)
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.body2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var overallProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Overall Progress")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
                Spacer()
                Text("\(Int(ui.overallProgress * 100))%")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
            }
            
            ProgressBar(value: ui.overallProgress)
            
            HStack {
                Spacer()
                Text(ui.dayIndexText)
                    .foregroundColor(AppColors.neutral300)
                    .appText(AppFont.captionS)
            }
        }
        .padding(.top, 6)
    }
    
    var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Progress")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)
            
            HStack(spacing: 12) {
                ForEach(ui.weekly) { day in
                    WeeklyDayCell(day: day)
                }
            }
        }
        .padding(.top, 6)
    }
    
    var todaysTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)
            
            VStack(spacing: 10) {
                ForEach(ui.todayTasks.indices, id: \.self) { idx in
                    TodayTaskRow(
                        title: ui.todayTasks[idx].title,
                        isCompleted: ui.todayTasks[idx].isCompleted,
                        onToggle: {
                            // TODO: Replace with ViewModel call / Supabase upsert
                            ui.todayTasks[idx].isCompleted.toggle()
                        },
                        showCamera: false, // proof feature later
                        onTapCamera: nil
                    )
                }
                
                Button {
                    // TODO: "Complete Day’s Challenge" action (optional)
                    // This button can be used as a confirm step, or can be removed if completion is automatic.
                } label: {
                    Text("Complete Day’s Challenge")
                        .foregroundColor(AppColors.textWhite)
                        .appText(AppFont.labelL)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isDayComplete ? AppColors.green300 : AppColors.neutral600)
                        .cornerRadius(8)
                }
                .disabled(!isDayComplete)
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(14)
            .background(AppColors.neutral900)
            .cornerRadius(16)
        }
        .padding(.top, 6)
    }
}

// MARK: - Helpers
private extension ChallengeDetailView {
    func isSealedTodayFromWeekly(_ weekly: [WeeklyDayUI]) -> Bool {
        // This is a UI helper only.
        // Real sealed logic should come from shared daily status (computed or stored).
        if let today = weekly.first(where: { $0.isToday }) {
            return today.status == .all
        }
        return false
    }
}

// MARK: - Components

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textWhite)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressBar: View {
    let value: Double // 0...1
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.neutral800)
                Capsule()
                    .fill(AppColors.green300)
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: 10)
    }
}

private struct WeeklyDayCell: View {
    let day: WeeklyDayUI
    
    var body: some View {
        VStack(spacing: 6) {
            Text(day.weekday)
                .foregroundColor(AppColors.neutral400)
                .appText(AppFont.captionXS)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.neutral900)
                    .frame(width: 34, height: 34)
                
                statusIcon(day.status)
            }
            
            Text(day.day)
                .foregroundColor(day.isToday ? AppColors.neutral1000 : AppColors.neutral400)
                .appText(AppFont.captionS)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(day.isToday ? AppColors.green300 : Color.clear)
                .cornerRadius(999)
        }
        .frame(width: 40)
    }
    
    @ViewBuilder
    private func statusIcon(_ status: WeeklyDayUI.Status) -> some View {
        switch status {
        case .all:
            Image(systemName: "checkmark.square.fill")
                .foregroundColor(AppColors.green300)
                .font(.system(size: 18, weight: .semibold))
        case .partial:
            Image(systemName: "minus.square.fill")
                .foregroundColor(AppColors.neutral400)
                .font(.system(size: 18, weight: .semibold))
        case .none:
            Image(systemName: "square")
                .foregroundColor(AppColors.neutral700)
                .font(.system(size: 18, weight: .regular))
        }
    }
}

private struct TodayTaskRow: View {
    let title: String
    let isCompleted: Bool
    let onToggle: () -> Void
    
    let showCamera: Bool
    let onTapCamera: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(AppColors.neutral600, lineWidth: 1)
                        .frame(width: 22, height: 22)
                    
                    if isCompleted {
                        Circle()
                            .fill(AppColors.green300)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.body1)
                .strikethrough(isCompleted, color: AppColors.neutral400)
            
            Spacer()
            
            if showCamera {
                Button(action: { onTapCamera?() }) {
                    Image(systemName: "camera")
                        .foregroundColor(AppColors.neutral300)
                        .font(.system(size: 18, weight: .regular))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Challenge Jar (SpriteKit)
private struct ChallengeJarView: View {
    let jarItems: [JarItemUI]
    let isSealed: Bool
    
    @State private var scene = ShakerScene(size: .zero)
    @State private var didConfigure = false
    
    // Lid visuals match ShakerView ratios
    private let lidHeightRatio: CGFloat = 46.0 / 270.0
    private let lidCornerRatio: CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            
            ZStack {
                Image("jarBase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                // Lid (only visible when sealed, per your rule)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.green300, AppColors.green300.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: jarSize.width, height: jarSize.height * lidHeightRatio)
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(y: -jarSize.height / 2 + jarSize.height * lidTopInsetRatio)
                    .opacity(isSealed ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: isSealed)
                    .allowsHitTesting(false)
                
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                Image("glitchLid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .onAppear {
                if scene.size == .zero {
                    scene = ShakerScene(size: jarSize)
                }
                
                // Challenge jar is always a "full" jar view (motion enabled)
                scene.setEmojiScale(1.0)
                scene.setMotionEnabled(true)
                scene.configureBoundaries(inset: 12, lidHeight: 40)
                scene.setHapticsEnabled(false)
                
                // Populate emojis (computed list)
                syncJarItemsToScene()
                didConfigure = true
            }
            .onChange(of: jarItems.count) { _ in
                guard didConfigure else { return }
                syncJarItemsToScene()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func syncJarItemsToScene() {
        // NOTE:
        // ShakerScene keys emojis by UUID. We use JarItemUI.id to allow multiple emojis.
        // This is "computed mode": you provide jarItems in the desired count.
        for item in jarItems {
            scene.addEmoji(item.emoji, for: item.id)
        }
    }
}

// MARK: - Preview (Optional)
#Preview {
    ChallengeDetailView(
        ui: ChallengeDetailUIModel(
            challengeId: UUID(),
            title: "7-Day Meditation Challenge",
            description: "Meditate for at least 10 minutes daily for 7 consecutive days.",
            startDateText: "2/1",
            endDateText: "2/28",
            overallProgress: 0.67,
            dayIndexText: "Day 12 of 30",
            weekly: [
                WeeklyDayUI(weekday: "SUN", day: "23", status: .all, isToday: false),
                WeeklyDayUI(weekday: "MON", day: "24", status: .none, isToday: false),
                WeeklyDayUI(weekday: "TUE", day: "25", status: .none, isToday: false),
                WeeklyDayUI(weekday: "WED", day: "26", status: .all, isToday: false),
                WeeklyDayUI(weekday: "THU", day: "27", status: .all, isToday: false),
                WeeklyDayUI(weekday: "FRI", day: "28", status: .partial, isToday: true),
                WeeklyDayUI(weekday: "SAT", day: "29", status: .none, isToday: false),
            ],
            jarItems: [
                JarItemUI(id: UUID(), emoji: "🎨"),
                JarItemUI(id: UUID(), emoji: "📚"),
                JarItemUI(id: UUID(), emoji: "🪴"),
                JarItemUI(id: UUID(), emoji: "🧡"),
                JarItemUI(id: UUID(), emoji: "🎨"),
                JarItemUI(id: UUID(), emoji: "📚")
            ],
            todayTasks: [
                TodayTaskUI(id: UUID(), title: "Morning stretching", isCompleted: true, canAttachProof: false),
                TodayTaskUI(id: UUID(), title: "10 minutes meditation", isCompleted: false, canAttachProof: false)
            ]
        ),
        onBack: nil,
        onTapCalendar: nil,
        onTapFavorite: nil
    )
}
