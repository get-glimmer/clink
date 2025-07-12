// import Foundation
// import AuthenticationServices
// import Combine
// import Supabase

// class AuthViewModel: NSObject, ObservableObject {
//     @Published var isAuthenticated = false
//     @Published var errorMessage: String?
//     private var cancellables = Set<AnyCancellable>()

//     func signInWithApple() {
//         let request = ASAuthorizationAppleIDProvider().createRequest()
//         request.requestedScopes = [.fullName, .email]
//         let controller = ASAuthorizationController(authorizationRequests: [request])
//         controller.delegate = self
//         controller.presentationContextProvider = self
//         controller.performRequests()
//     }

//     // Example login with Supabase (email/password)
//     func login(email: String, password: String) {
//         guard let client = SupabaseClientManager.shared.client else {
//             errorMessage = "Supabase client not initialized."
//             return
//         }
//         Task {
//             do {
//                 let session = try await client.auth.signIn(email: email, password: password)
//                 DispatchQueue.main.async {
//                     self.isAuthenticated = session.user != nil
//                 }
//             } catch {
//                 DispatchQueue.main.async {
//                     self.errorMessage = error.localizedDescription
//                 }
//             }
//         }
//     }
// }

// extension AuthViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
//     func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
//         if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
//             guard let identityToken = appleIDCredential.identityToken,
//                   let tokenString = String(data: identityToken, encoding: .utf8),
//                   let client = SupabaseClientManager.shared.client else {
//                 self.errorMessage = "Apple identity token missing."
//                 return
//             }
//             let credentials = OpenIDConnectCredentials(provider: .apple, idToken: tokenString, nonce: nil)
//             Task {
//                 do {
//                     let session = try await client.auth.signInWithIdToken(credentials: credentials)
//                     DispatchQueue.main.async {
//                         self.isAuthenticated = session.user != nil
//                     }
//                 } catch {
//                     DispatchQueue.main.async {
//                         self.errorMessage = error.localizedDescription
//                     }
//                 }
//             }
//         }
//     }

//     func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
//         self.errorMessage = error.localizedDescription
//     }

//     func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//         // You may need to adjust this for your app's window
//         return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
//     }
// }

