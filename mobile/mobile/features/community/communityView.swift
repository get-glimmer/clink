//
//  communityView.swift
//  mobile
//
//  Created by Soohyeuk Choi on 6/17/25.
//

import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showingSearch = false
    
    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Friends Grid
                ScrollView {
                    if viewModel.isLoading {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
                                .scaleEffect(1.2)
                            
                            Text("Loading friends...")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 16))
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 40))
                            
                            Text("Something went wrong")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 18, weight: .medium))
                            
                            Text(errorMessage)
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("Try Again") {
                                viewModel.refreshFriends()
                            }
                            .foregroundColor(Color.blue)
                            .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else if viewModel.friends.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 40))
                            
                            Text("No friends yet")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 18, weight: .medium))
                            
                            Text("Add friends through the search to see them here")
                                .foregroundColor(AppColors.neutral400)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .padding(.top, 40)
                    } else {
                        // Friends grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 20) {
                            ForEach(viewModel.friends) { friend in
                                FriendCardView(
                                    friend: friend, 
                                    isSelected: friend.id == viewModel.selectedFriendId,
                                    viewModel: viewModel
                                ) {
                                    viewModel.selectFriend(friend)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSearch) {
            SearchView()
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Friends Dropdown Button
            Button(action: {
                viewModel.toggleDropdown()
            }) {
                HStack(spacing: 8) {
                    Text(viewModel.selectedCategory)
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 20, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 14, weight: .medium))
                        .rotationEffect(.degrees(viewModel.showingDropdown ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                )
            }
            
            Spacer()
            
            // Search Button
            Button(action: {
                showingSearch = true
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textWhite)
                    .font(.system(size: 20, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .zIndex(99) // Keep header above scroll content but below dropdown
        .overlay(
            // Dropdown Menu
            VStack {
                if viewModel.showingDropdown {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Button(action: {
                                viewModel.selectCategory(category)
                            }) {
                                HStack {
                                    Text(category)
                                        .foregroundColor(AppColors.textWhite)
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Spacer()
                                    
                                    if category == viewModel.selectedCategory {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.textWhite)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                            }
                            
                            // Divider between items (except for last item)
                            if category != viewModel.categories.last {
                                Divider()
                                    .background(AppColors.neutral700)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(AppColors.neutral800)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.neutral600, lineWidth: 1)
                    )
                    .offset(y: 50)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showingDropdown)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.trailing, 60) // Leave space so dropdown doesn't go too wide
            .zIndex(100) // Ensure dropdown appears above other content
        )
    }
}

struct FriendCardView: View {
    let friend: Friend
    let isSelected: Bool
    let viewModel: CommunityViewModel
    let onTap: () -> Void
    @State private var showingMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with profile and menu
            HStack {
                HStack(spacing: 8) {
                    // Profile Image
                    Image(friend.profileImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    
                    // Name
                    Text(friend.name)
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Spacer()
                
                // Menu Button
                Button(action: {
                    showingMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textWhite)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Black Rectangle (placeholder for emoji garden)
            Rectangle()
                .fill(Color.black)
                .frame(height: 120)
                .cornerRadius(12)
                .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AppColors.neutral900)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
        .sheet(isPresented: $showingMenu) {
            FriendMenuSheet(friend: friend, viewModel: viewModel)
        }
    }
}

struct FriendMenuSheet: View {
    let friend: Friend
    let viewModel: CommunityViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AppColors.neutral600)
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 32)
        
        // Friend name
        Text(friend.name)
            .foregroundColor(AppColors.textWhite)
            .font(.system(size: 28, weight: .bold))
            .padding(.bottom, 24)
        
        // Divider line
        Rectangle()
            .fill(AppColors.neutral800)
            .frame(width: 361, height: 1)
            .padding(.bottom, 24)
        
                    // Menu options
            VStack(spacing: 24) {
                // Unfollow option
                Button(action: {
                    handleUnfollow()
                }) {
                    HStack(spacing: 20) {
                        // Circular icon background
                        ZStack {
                            Circle()
                                .fill(AppColors.neutral800)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(AppColors.textWhite)
                                .font(.system(size: 24, weight: .medium))
                        }
                        
                        Text("Unfollow")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 20, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }
                
                // Favorites option (add or remove based on current status)
                Button(action: {
                    handleFavoriteToggle()
                }) {
                    HStack(spacing: 20) {
                        // Circular icon background
                        ZStack {
                            Circle()
                                .fill(AppColors.neutral800)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: friend.isFavorite ? "star.fill" : "star")
                                .foregroundColor(friend.isFavorite ? Color.yellow : AppColors.textWhite)
                                .font(.system(size: 24, weight: .medium))
                        }
                        
                        Text(friend.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                            .foregroundColor(AppColors.textWhite)
                            .font(.system(size: 20, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }
            }
        
        Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.neutral1000)
        .presentationDetents([.height(254)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled()
    }
    
    private func handleUnfollow() {
        viewModel.unfollowFriend(named: friend.name)
        dismiss()
    }
    
    private func handleFavoriteToggle() {
        if friend.isFavorite {
            viewModel.removeFriendFromFavorites(named: friend.name)
        } else {
            viewModel.addFriendToFavorites(named: friend.name)
        }
        dismiss()
    }
}

#Preview {
    CommunityView()
}
