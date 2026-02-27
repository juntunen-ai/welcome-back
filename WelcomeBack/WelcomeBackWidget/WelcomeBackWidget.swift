import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WelcomeBackEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider

struct WelcomeBackProvider: TimelineProvider {
    func placeholder(in context: Context) -> WelcomeBackEntry {
        WelcomeBackEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WelcomeBackEntry) -> Void) {
        completion(WelcomeBackEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WelcomeBackEntry>) -> Void) {
        // Refresh once a day — the content is static
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [WelcomeBackEntry(date: Date())], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct WelcomeBackWidgetView: View {
    let entry: WelcomeBackEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.078, green: 0.094, blue: 0.125)

            // Soft yellow glow in the centre
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )

            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge:
                largeLayout
            default:
                smallLayout
            }
        }
        // Deep link opens the app on tap
        .widgetURL(URL(string: "welcomeback://open"))
    }

    // MARK: - Small (square)

    private var smallLayout: some View {
        VStack(spacing: 6) {
            // Photo in yellow-ringed circle
            photoView(size: 72)

            Text("Welcome Back")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Remember who\nyou are")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
    }

    // MARK: - Medium (wide)

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            photoView(size: 90)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome Back")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Harri")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                Text("Remember who you are")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Large (tall square)

    private var largeLayout: some View {
        VStack(spacing: 0) {
            // Big photo fills the top ~60%
            photoView(size: 220)
                .padding(.top, 24)

            Spacer()

            // Text stacked at the bottom
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Text("Harri")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                Text("Remember who you are")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared photo view

    private func photoView(size: CGFloat) -> some View {
        Group {
            if let uiImage = UIImage(named: "user_harri") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .rotationEffect(.degrees(180))
            } else {
                Color(red: 0.2, green: 0.22, blue: 0.28)
                    .overlay(
                        Text("H")
                            .font(.system(size: size * 0.4, weight: .black))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color(red: 1.0, green: 0.84, blue: 0.0), lineWidth: size * 0.04)
        )
    }
}

// MARK: - Widget Configuration

@main
struct WelcomeBackWidget: Widget {
    let kind: String = "WelcomeBackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WelcomeBackProvider()) { entry in
            WelcomeBackWidgetView(entry: entry)
                .containerBackground(
                    Color(red: 0.078, green: 0.094, blue: 0.125),
                    for: .widget
                )
        }
        .configurationDisplayName("Welcome Back")
        .description("Remember who you are.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    WelcomeBackWidget()
} timeline: {
    WelcomeBackEntry(date: .now)
}

#Preview(as: .systemMedium) {
    WelcomeBackWidget()
} timeline: {
    WelcomeBackEntry(date: .now)
}

#Preview(as: .systemLarge) {
    WelcomeBackWidget()
} timeline: {
    WelcomeBackEntry(date: .now)
}
