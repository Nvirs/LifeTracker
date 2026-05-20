import SwiftUI

enum MainTab: Hashable {
    case home
    case finances
    case health
    case personal
    case notes
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)
            
            FinanceView(onBack: { selectedTab = .home })
                .tabItem {
                    Label("Finances", systemImage: "dollarsign.circle.fill")
                }
                .tag(MainTab.finances)
            
            HealthView(onBack: { selectedTab = .home })
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
                .tag(MainTab.health)
            
            PersonalLifeView()
                .tabItem {
                    Label("Personal", systemImage: "person.2.fill")
                }
                .tag(MainTab.personal)
            
            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(MainTab.notes)
        }
        .accentColor(.blue)
        .preferredColorScheme(.light)
    }
}
