import WidgetKit
import SwiftUI

struct ShakerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShakerEntry {
        ShakerEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (ShakerEntry) -> Void) {
        completion(ShakerEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShakerEntry>) -> Void) {
        completion(Timeline(entries: [ShakerEntry(date: Date())], policy: .never))
    }
}

struct ShakerEntry: TimelineEntry {
    let date: Date
}

struct ShakerWidgetEntryView: View {
    var entry: ShakerEntry

    var body: some View {
        VStack(spacing: 8) {
            // Test A: asset catalog with .original rendering mode
            Image("jarBase")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .border(Color.red)

            // Test B: load PNG directly from bundle, skip asset catalog
            if let path = Bundle.main.path(forResource: "jarBase2x", ofType: "png"),
               let uiImg = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .border(Color.green)
            } else {
                Text("file not found")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }
}

struct GlimmerShakerWidget: Widget {
    let kind: String = "GlimmerShakerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShakerProvider()) { entry in
            ShakerWidgetEntryView(entry: entry)
                .containerBackground(Color.gray, for: .widget)
        }
        .configurationDisplayName("Clink Shaker")
        .description("Your shaker jar.")
        .supportedFamilies([.systemSmall])
    }
}
