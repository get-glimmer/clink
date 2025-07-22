import SwiftUI

struct MonthYearPicker: View {
    // variables used in parent view (trackerView)
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    // temporary variables before users click "done" button.
    @State private var tempMonth = Calendar.current.component(.month, from: Date())
    @State private var tempYear = Calendar.current.component(.year, from: Date())
    
    let years = Array(2010...2035)
    let months = Array(1...12)
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Spacer()
                    Picker("Year", selection: $tempYear) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year))
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    
                    Picker("Month", selection: $tempMonth) {
                        ForEach(months, id: \.self) { month in
                            Text(String(format: "%02d", month))
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    Spacer()
                }
                Spacer()
            }
            .navigationBarTitle("Select Month", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    updateSelectedDate()
                    isPresented = false
                }
            )
        }
        // when the navigation view first appears
        .onAppear {
            tempYear = Calendar.current.component(.year, from: selectedDate)
            tempMonth = Calendar.current.component(.month, from: selectedDate)
        }
    }
    
    // updates "selectedDate" when done button is clicked
    func updateSelectedDate() {
        let components = DateComponents(year: tempYear, month: tempMonth)
        if let newDate = Calendar.current.date(from: components) {
            selectedDate = Calendar.current.startOfMonth(for: newDate)
        }
    }
}
