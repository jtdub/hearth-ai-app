import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        TabView {
            onboardingPage(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Welcome to Hearth AI",
                subtitle: "Your private, on-device AI assistant.",
                description: """
                Chat with powerful language models that run entirely \
                on your iPhone. No internet required for conversations.
                """
            )

            onboardingPage(
                icon: "lock.shield.fill",
                iconColor: .green,
                title: "Completely Private",
                subtitle: "Your data never leaves your device.",
                description: """
                All AI processing happens locally. No cloud servers, \
                no data collection, no tracking. Your conversations \
                are yours alone.
                """
            )

            onboardingPage(
                icon: "arrow.down.circle.fill",
                iconColor: .blue,
                title: "Get Started",
                subtitle: "Download a model to begin chatting.",
                description: """
                Head to the Models tab to browse and download an AI model. \
                We recommend starting with a smaller model (0.5-1B parameters) \
                for the best experience.
                """,
                showGetStarted: true
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private func onboardingPage(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        description: String,
        showGetStarted: Bool = false
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(iconColor)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title.bold())
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            if showGetStarted {
                Button {
                    isPresented = false
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            } else {
                Spacer()
                    .frame(height: 96)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
