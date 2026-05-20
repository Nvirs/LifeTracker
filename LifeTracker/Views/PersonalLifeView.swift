import SwiftUI
struct PersonalLifeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                Text("Personal Life Details")
            }
            .navigationTitle("Personal Life")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.purple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}