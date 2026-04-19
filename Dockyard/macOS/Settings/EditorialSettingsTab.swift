//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct EditorialSettingsTab: View {

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section {
                Toggle("Enable Editorial Mode", isOn: $appSettings.isEditorialModeEnabled)
                Text("Reveals an Editorial pane in the sidebar for authoring editorial.json files. Your changes are saved locally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}

#Preview {
    EditorialSettingsTab()
        .previewEnvironment()
}
