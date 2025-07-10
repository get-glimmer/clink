import SwiftUI

struct TrackerView: View {
    @StateObject private var trackerViewModel = TrackerViewModel()
    
    let calendar = Calendar.current
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            Text("Tracker")
                .font(.title)
                .padding()
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(trackerViewModel.days, id: \.self) { date in
                    VStack {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.body)

                        if let progress = trackerViewModel.shakersRecord[trackerViewModel.formattedDate(date)] {
                            Text(String(format: "%.0f%%", progress * 100))
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Spacer().frame(height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .task {
            try? await trackerViewModel.fetchShakers()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TrackerView()   // 여기서 미리볼 뷰를 지정
    }
}
