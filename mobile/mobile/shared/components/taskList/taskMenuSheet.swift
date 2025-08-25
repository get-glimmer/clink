import SwiftUI

struct TaskMenuSheet: View {
    let taskTitle: String

    var onDoToday: () -> Void = {}
    var onChangeDate: () -> Void = {}
    var onMakeRoutine: () -> Void = {}
    var onArchive: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ─────────────────────────────────────────────
            HStack(alignment: .center) {
                // Title
                Text(taskTitle)
                    .appFont(AppFont.title3)
                    .foregroundColor(Color("White"))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button(action: onEdit) {
                    Image("pencil")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)

                Button(action: onDelete) {
                    Image("trashcan")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Divider()
                .frame(width: 361)
                .background(Color("Neutral-800"))
                .padding(.top, 16)

            // ── Options ────────────────────────────────────────────
            VStack(spacing: 20) {
                optionRow(
                    systemIcon: "arrow.down",
                    title: "Do it Today",
                    action: onDoToday
                )
                optionRow(
                    systemIcon: "arrow.clockwise",
                    title: "Change Date",
                    action: onChangeDate
                )
                optionRow(
                    systemIcon: "clock",
                    title: "Make it a Routine",
                    action: onMakeRoutine
                )
                optionRow(
                    systemIcon: "folder",
                    title: "Archive a Task",
                    action: onArchive
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 22)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Row factory
    @ViewBuilder
    private func optionRow(systemIcon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {

                ZStack {
                    Circle()
                        .fill(Color("Green-300"))
                        .frame(width: 44, height: 44)
                    Image(systemName: systemIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color("White"))
                }

                Text(title)
                    .appFont(AppFont.labelM)
                    .foregroundColor(Color("White"))

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
