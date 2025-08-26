import SwiftUI
import PhotosUI
import Supabase

struct FinishSignupView: View {
    let phoneNumber: String?
    let email: String?
    let userId: String
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var showDatePicker = false
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var photoItem: PhotosPickerItem?
    @State private var usernameConfirmed: Bool = false
    @State private var usernameStatus: String? = nil
    @State private var usernameStatusColor: Color = .white
    @State private var navigateToSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Header
                    Text("Finish signing up")
                        .font(.title2)
                        .bold()
                        .padding(.top, 20)

                    // MARK: Profile Avatar
//                    PhotosPicker(selection: $photoItem, matching: .images) {
//                        if let profileImage {
//                            Image(uiImage: profileImage)
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 100, height: 100)
//                                .clipShape(Circle())
//                                .padding(.top, 20)
//                        } else {
//                            ZStack {
//                                Circle()
//                                    .fill(Color.gray.opacity(0.3))
//                                    .frame(width: 100, height: 100)
//                                Image(systemName: "camera.fill")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(Color("Neutral-100"))
//                            }
//                            .padding(.top, 20)
//                        }
//                    }
//                    .onChange(of: photoItem) { _, newItem in
//                        Task {
//                            if let data = try? await newItem?.loadTransferable(type: Data.self),
//                               let uiImage = UIImage(data: data) {
//                                profileImage = uiImage
//                            }
//                        }
//                    }

                    // MARK: Full Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your name")
                            .font(.subheadline)
                            .foregroundColor(Color("Neutral-300"))

                        TextField("Full name", text: $fullName)
                            .padding()
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .cornerRadius(12)
                    }

                    // MARK: Username
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundColor(Color("Neutral-300"))

                        HStack(spacing: 8) {
                            TextField("Username", text: $username)
                                .padding()
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                                .cornerRadius(12)
                                .onChange(of: username) {
                                    usernameConfirmed = false
                                    usernameStatus = nil
                                }

                            Button {
                                Task {
                                    if await authViewModel.checkUsername(username) {
                                        usernameStatus = "The username is available."
                                        usernameStatusColor = .white
                                        usernameConfirmed = true
                                    } else {
                                        usernameStatus = "The username is already in use."
                                        usernameStatusColor = .red
                                        usernameConfirmed = false
                                    }
                                }
                            } label: {
                                Text("Confirm")
                                    .frame(maxHeight: .infinity)
                                    .foregroundColor(username.isEmpty ? .white : Color("Neutral-900"))
                                    .padding(.horizontal, 16)
                                    .background(username.isEmpty ? Color("Neutral-800") : Color("Green-300"))
                                    .cornerRadius(12)
                            }
                            .disabled(username.isEmpty)
                        }
                        .frame(height: 55)

                        if let status = usernameStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(usernameStatusColor)
                                .padding(.leading, 4)
                        }
                    }

                    // MARK: Date of Birth
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date of Birth (Optional)")
                            .font(.subheadline)
                            .foregroundColor(Color("Neutral-300"))

                        Button {
                            showDatePicker.toggle()
                        } label: {
                            HStack {
                                Text(dateOfBirth, style: .date)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Color("Neutral-300"))
                            }
                            .padding()
                            .background(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Neutral-600")))
                            .cornerRadius(12)
                        }

                        if showDatePicker {
                            DatePicker(
                                "",
                                selection: $dateOfBirth,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .onChange(of: dateOfBirth) {
                                showDatePicker = false
                            }
                        }

                        Text("Your birthday won't be shared with other people who use Shaka.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }

            // MARK: Continue Button
            Button {
                Task {
                    isLoading = true
                    await authViewModel.saveProfile(
                        userId: userId,
                        phoneNumber: phoneNumber,
                        name: fullName,
                        username: username,
                        dob: dateOfBirth,
                        profileImage: profileImage,
                        email: email
                    )
                    isLoading = false
                    navigateToSuccess = true
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((!usernameConfirmed || fullName.isEmpty) ? Color("Neutral-800") : Color("Green-300"))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .padding()
            }
            .disabled(!usernameConfirmed || fullName.isEmpty)

            // Hidden navigation link to SignupSuccessView
            NavigationLink(
                destination: SignupSuccessView()
                    .environmentObject(authViewModel),
                isActive: $navigateToSuccess,
                label: { EmptyView() }
            )
        }
    }
}
