import SwiftUI

struct NotificationsSettingsView: View {

    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    enableSection
                    if appVM.userProfile.notificationsEnabled {
                        timingSection
                        topicsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.2), value: appVM.userProfile.notificationsEnabled)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sections

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Status")

            HStack(spacing: 14) {
                iconBadge("bell.fill", color: .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Notifications")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.onSurface)
                    Text("Daily check-in reminders")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.5))
                }

                Spacer()

                Toggle("", isOn: $appVM.userProfile.notificationsEnabled)
                    .tint(.accentYellow)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Remind Me At")

            VStack(spacing: 0) {
                ForEach(Array(NotificationTime.allCases.enumerated()), id: \.element.id) { index, time in
                    let isSelected = appVM.userProfile.notificationTimes.contains(time)

                    Button {
                        if isSelected {
                            appVM.userProfile.notificationTimes.removeAll { $0 == time }
                        } else {
                            appVM.userProfile.notificationTimes.append(time)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            iconBadge(timeIcon(for: time), color: timeColor(for: time))

                            Text(time.rawValue)
                                .font(.system(size: 15))
                                .foregroundColor(.onSurface)

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .accentYellow : .onSurface.opacity(0.25))
                                .font(.system(size: 20))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)

                    if index < NotificationTime.allCases.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("What to Talk About")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    iconBadge("text.bubble.fill", color: .teal)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Topics & Reminders")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.onSurface)

                        Text("Describe what the daily check-in should focus on — e.g. medication, appointments, memories.")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                TextField("e.g. Ask about today's lunch, remind to take medication at 10am…",
                          text: $appVM.userProfile.notificationTopics,
                          axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface)
                    .lineLimit(5, reservesSpace: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private func timeIcon(for time: NotificationTime) -> String {
        switch time {
        case .morning:   return "sunrise.fill"
        case .noon:      return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening:   return "moon.stars.fill"
        }
    }

    private func timeColor(for time: NotificationTime) -> Color {
        switch time {
        case .morning:   return .orange
        case .noon:      return .yellow
        case .afternoon: return Color(red: 1, green: 0.6, blue: 0.2)
        case .evening:   return .indigo
        }
    }

    private func iconBadge(_ name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.bottom, 4)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
            .environmentObject(AppViewModel())
    }
}
