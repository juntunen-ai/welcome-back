import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StoryOfMyLifeEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider

struct StoryOfMyLifeProvider: TimelineProvider {
    func placeholder(in context: Context) -> StoryOfMyLifeEntry {
        StoryOfMyLifeEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StoryOfMyLifeEntry) -> Void) {
        completion(StoryOfMyLifeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StoryOfMyLifeEntry>) -> Void) {
        // Refresh once a day — the content is static
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [StoryOfMyLifeEntry(date: Date())], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct StoryOfMyLifeWidgetView: View {
    let entry: StoryOfMyLifeEntry
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
        .widgetURL(URL(string: "storyofmylife://open"))
    }

    // MARK: - Small (square)

    private var smallLayout: some View {
        VStack(spacing: 6) {
            photoView(size: 72)

            Text("Story of My Life")
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
                Text("Story of My Life")
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
                    Text("Story of My Life")
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
struct StoryOfMyLifeWidget: Widget {
    let kind: String = "StoryOfMyLifeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StoryOfMyLifeProvider()) { entry in
            StoryOfMyLifeWidgetView(entry: entry)
                .containerBackground(
                    Color(red: 0.078, green: 0.094, blue: 0.125),
                    for: .widget
                )
        }
        .configurationDisplayName("Story of My Life")
        .description("Remember who you are.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StoryOfMyLifeWidget()
} timeline: {
    StoryOfMyLifeEntry(date: .now)
}

#Preview(as: .systemMedium) {
    StoryOfMyLifeWidget()
} timeline: {
    StoryOfMyLifeEntry(date: .now)
}

#Preview(as: .systemLarge) {
    StoryOfMyLifeWidget()
} timeline: {
    StoryOfMyLifeEntry(date: .now)
}
