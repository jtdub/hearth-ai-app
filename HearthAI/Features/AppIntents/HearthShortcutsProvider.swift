import AppIntents

struct HearthShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskHearthIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Chat with \(.applicationName)",
            ],
            shortTitle: "Ask Hearth AI",
            systemImageName: "brain"
        )

        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
            ],
            shortTitle: "Summarize",
            systemImageName: "text.justify.left"
        )

        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
            ],
            shortTitle: "Translate",
            systemImageName: "globe"
        )

        AppShortcut(
            intent: RewriteTextIntent(),
            phrases: [
                "Rewrite with \(.applicationName)",
            ],
            shortTitle: "Rewrite",
            systemImageName: "pencil.line"
        )
    }
}
