import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo
            Image(systemName: "heart.text.square.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to LifeTracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "dollarsign.circle.fill", color: .blue, title: "Finances", subtitle: "Track your income and expenses.")
                FeatureRow(icon: "heart.fill", color: .green, title: "Health", subtitle: "Record your sleep, steps, and measurements.")
                FeatureRow(icon: "person.2.fill", color: .purple, title: "Personal Life", subtitle: "Build habits and track your goals.")
                FeatureRow(icon: "airplane", color: .orange, title: "Travel", subtitle: "Map the world and save your trips.")
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                hasSeenOnboarding = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.light)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
