import SwiftUI


struct CalendarView: View {
    let days: [CalendarDay]
    let startOfMonth: Date
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    init(shakers: [Shaker]) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let range = calendar.range(of: .day, in: .month, for: start)!
        var tempDays: [CalendarDay] = []
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                let matchedShaker = shakers.first { calendar.isDate($0.date, inSameDayAs: date) }
                tempDays.append(CalendarDay(date: date, shaker: matchedShaker))
            }
        }

        self.days = tempDays
        self.startOfMonth = start
    }

    
    var body: some View {
        VStack {
            Text("\(startOfMonth.formatted(.dateTime.month(.wide).year()))")
                .font(.system(size: 16, weight: .bold))
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text(formattedDay(day.date))
                            .font(.system(size: 16, weight: .bold))
                        
                        if let shaker = day.shaker {
                            let progress = Double(shaker.completed_tasks.count) / Double(shaker.total_tasks)
                            Text(String(format: "%.0f%%", progress * 100))
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        } else {
                            Text("")  // Empty cell
                        }
                    }
                    .frame(width: 42, height: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        
    }

    func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}


// View that fetches Shaker table from supabase
struct ShakerView: View {
  @State var shakers: [Shaker] = []

  var body: some View {
    List(shakers) { shaker in
        let progress = Double(shaker.completed_tasks.count) / Double(shaker.total_tasks)
        Text("\(shaker.id) \n completed tasks: \(shaker.completed_tasks.count) \n total tasks: \(shaker.total_tasks)")
        Text("progress = \(progress)")
    }
    .overlay {
      if shakers.isEmpty {
        ProgressView()
      }
    }
    .task {
      do {
          shakers = try await supabase.from("shaker").select().execute().value
//          print("Response: ", shakers)

      } catch {
        dump(error)
      }
    }
  }
}



