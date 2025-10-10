//
//  MonthYearDropdown.swift
//  mobile
//
//  Created by Kristie Lee on 10/9/25.
//

import SwiftUI

public struct MonthYearDropdown: View {
    // Public binding to the month anchor (1st day of the selected month)
    @Binding public var anchorMonth: Date

    // Config
    public var years: [Int] = Array(2010...2035)
    public var months: [Int] = Array(1...12)

    // Internals
    private let calendar = Calendar.current

    public init(anchorMonth: Binding<Date>,
                years: [Int] = Array(2010...2035),
                months: [Int] = Array(1...12)) {
        self._anchorMonth = anchorMonth
        self.years = years
        self.months = months
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            let plate = RoundedRectangle(cornerRadius: 12)

            plate
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.neutral400).opacity(0.7),
                            Color(.neutral600).opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .background(
                    ZStack {
                        DarkBlurView(style: .systemChromeMaterialDark)
                        Color.black.opacity(0.5)
                    }
                    .clipShape(plate)
                )

            // Wheels
            HStack(spacing: 0) {
                // Year wheel
                Picker("Year", selection: Binding(
                    get: { calendar.component(.year, from: anchorMonth) },
                    set: { newYear in
                        anchorMonth = calendar.date(from: DateComponents(
                            year: newYear,
                            month: calendar.component(.month, from: anchorMonth),
                            day: 1
                        )) ?? anchorMonth
                    }
                )) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y))
                            .appFont(AppFont.labelM)
                            .foregroundColor(.white)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity, minHeight: 150)
                
                // Month wheel
                Picker("Month", selection: Binding(
                    get: { calendar.component(.month, from: anchorMonth) },
                    set: { newMonth in
                        anchorMonth = calendar.date(from: DateComponents(
                            year: calendar.component(.year, from: anchorMonth),
                            month: newMonth,
                            day: 1
                        )) ?? anchorMonth
                    }
                )) {
                    ForEach(months, id: \.self) { m in
                        Text(monthName(m))
                            .appFont(AppFont.labelM)
                            .foregroundColor(.white)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity, minHeight: 150)
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 170)
        .shadow(radius: 12)
    }

    // MARK: - Helpers
    private func monthName(_ m: Int) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.monthSymbols[m - 1]
    }
}
