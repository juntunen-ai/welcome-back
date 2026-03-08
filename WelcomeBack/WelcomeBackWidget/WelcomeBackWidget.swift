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
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge, .systemExtraLarge:
                largeLayout
            default:
                largeLayout
            }
        }
        .widgetURL(URL(string: "welcomeback://open"))
    }

    // MARK: - Small (square)

    private var smallLayout: some View {
        VStack(spacing: 6) {
            photoView(size: 72)

            Text("Welcome Back")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Harri")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
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
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Large (tall square)

    private var largeLayout: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Photo fills top 58% of the widget height
                photoView(size: geo.size.width * 0.72)
                    .frame(maxWidth: .infinity)
                    .padding(.top, geo.size.height * 0.06)

                Spacer()

                // Text block anchored to bottom
                VStack(spacing: 6) {
                    Text("Welcome Back")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))

                    Text("Harri")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, geo.size.height * 0.07)
            }
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
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
