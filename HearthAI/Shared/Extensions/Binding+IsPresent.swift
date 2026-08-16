import SwiftUI

extension Binding where Value == Bool {
    /// A Boolean binding that is true when the optional has a
    /// value. Set the binding to false to clear the optional.
    /// Use it to present alerts and dialogs from optional state.
    init<T>(isPresent source: Binding<T?>) {
        self.init(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }
}
