import SwiftUI

/// Describes how an `AppCard` / `LargeAppCard` should render its icon.
public enum AppIconSource: Sendable, Equatable {

    /// An SF Symbol rendered on a solid-color rounded rectangle.
    case symbol(name: String, background: Color, foreground: Color = .white)

    /// A local image file — typically a PNG resolved via `IconCache`.
    case file(URL)
}
