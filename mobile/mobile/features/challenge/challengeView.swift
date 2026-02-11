
import SwiftUI

struct Challenge: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let daysLeft: Int
    let progress: Int
    let frequency: String
    let imageName: String
}

struct ChallengeView: View {
    // TODO: Make an API call to server to fetch challenges
    @State private var challenges: [Challenge] = [
        Challenge(title: "30-Day Reading \nChallenge", subtitle: "Read 15 minutes daily", daysLeft: 5, progress: 70, frequency: "3 days a week", imageName: "jar"),
        Challenge(title: "7-Day Meditation \nChallenge", subtitle: "Daily mindfulness", daysLeft: 7, progress: 40, frequency: "Everyday", imageName: "jar"),
        Challenge(title: "30-Day Reading \nChallenge", subtitle: "Read 15 minutes daily", daysLeft: 5, progress: 70, frequency: "3 days a week", imageName: "jar"),
        Challenge(title: "30-Day Reading \nChallenge", subtitle: "Read 15 minutes daily", daysLeft: 5, progress: 70, frequency: "3 days a week", imageName: "jar")
    ]
    
    @State private var selectedCategory: String = "Challenges"
    @State private var isDropdownPresented: Bool = false
    private let categories = ["Challenges", "My Challenges", "Completed"]
    
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    // Dropdown Button
                    Button(action: {
                        isDropdownPresented.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Text(selectedCategory)
                                .appText(AppFont.title1)
                                .foregroundColor(AppColors.textWhite)
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 10, weight: .bold)) // Adjusted size closer to design
                                .rotationEffect(.degrees(isDropdownPresented ? 180 : 0))
                                .animation(.easeInOut(duration: 0.2), value: isDropdownPresented)
                        }
                    }
                    // Anchor for dropdown positioning
                    .anchorPreference(key: DropdownBoundsPreferenceKey.self, value: .bounds) { $0 }
                    
                    Spacer()
                    
                    // Search Button
                    Button {
                        // Search action
                    } label: {
                         Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(12)
                            .background(AppColors.neutral900)
                            .clipShape(Circle())
                            .foregroundColor(AppColors.textWhite)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .zIndex(1) // Ensure header is above scroll content for dropdown overlay context if needed
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(challenges) { challenge in
                            ChallengeCard(challenge: challenge)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100) // Space for nav bar
                }
            }
        }
        .dropdownOverlay(
            isPresented: $isDropdownPresented,
            options: categories,
            selection: $selectedCategory,
            onSelect: { _ in isDropdownPresented = false },
            labelTitle: { $0 }
        )
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Content
            VStack(alignment: .leading, spacing: 0) {
                
                // Date Pill (Green)
                Text("2/1 - 2/28") // Hardcoded for demo/screenshot match
                    .appText(AppFont.captionS)
                    .foregroundColor(Color.black)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(AppColors.green300)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                
                // Title
                Text(challenge.title)
                    .appText(AppFont.title3)
                    .foregroundColor(AppColors.textWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .padding(.bottom, 12)
                
                // Meta info (Calendar icon + Frequency)
                HStack(spacing: 6) {
                    Image(systemName: "calendar") // Using system symbol for now or "calendar" asset if available
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(AppColors.neutral400)
                    
                    Text(challenge.frequency)
                        .appText(AppFont.captionS)
                        .foregroundColor(AppColors.neutral400)
                }
                .padding(.bottom, 16)
                
                // Participants Pile
                HStack(spacing: -8) {
                     // Using placeholder circles for participants
                     ForEach(0..<4) { i in
                         Circle()
                             .fill(AppColors.neutral300) // Placeholder avatar color
                             .frame(width: 28, height: 28)
                             .overlay(
                                 Image(systemName: "person.fill")
                                     .resizable()
                                     .padding(6)
                                     .foregroundColor(AppColors.neutral800)
                             )
                             .overlay(
                                Circle().stroke(AppColors.neutral900, lineWidth: 2)
                             )
                             .zIndex(Double(4 - i))
                     }
                    
                     // Count Text
                     Text("+2")
                        .appText(AppFont.captionM) // Slightly larger than S
                        .foregroundColor(AppColors.white)
                        .padding(.leading, 12)
                }
            }
            .layoutPriority(1)
            
            Spacer(minLength: 16)
            
            // Right Image
            // In the screenshot, the image is a square/rect on the right with some overlay elements potentialy?
            // It looks like a simple image with rounded corners.
            // Screenshot shows an image with some small badges on it, but let's stick to the main image first.
            // Right Image
            Image(challenge.imageName) // "jar"
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
        }
        .padding(16)
        .background(AppColors.neutral900)
        .cornerRadius(16)
        // No border stroke in the new design description, just dark card on dark bg.
    }
}

//     AppRouter()
//}
