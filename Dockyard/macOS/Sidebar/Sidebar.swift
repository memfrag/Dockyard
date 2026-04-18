//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox

struct Sidebar: View {

    @State var searchText: String = ""

    @State var selection: SidebarPane? = .today

    @State var isInspectorPresented: Bool = false

    @AppStorage("appearancePreference") private var appearance: AppearancePreference = .system

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                
                Section(header: Text("Dockyard")) {

                    NavigationLink(value: SidebarPane.today) {
                        let day = Calendar.current.component(.day, from: Date())
                        Label("Today", systemImage: "\(day).calendar")
                    }

                    NavigationLink(value: SidebarPane.discover) {
                        Label("Discover", systemImage: "star")
                    }

                    NavigationLink(value: SidebarPane.installed) {
                        Label("Installed", systemImage: "checkmark.app")
                            .imageScale(.large)
                    }
                }

                Section(header: Text("Categories")) {

                    NavigationLink(value: SidebarPane.design) {
                        Label("Design", systemImage: "ellipsis.circle")
                    }

                    NavigationLink(value: SidebarPane.development) {
                        Label("Development", systemImage: "hammer")
                    }

                    NavigationLink(value: SidebarPane.entertainment) {
                        Label("Entertainment", systemImage: "popcorn")
                    }

                    NavigationLink(value: SidebarPane.finance) {
                        Label("Finance", systemImage: "creditcard")
                    }

                    NavigationLink(value: SidebarPane.productivity) {
                        Label("Productivity", systemImage: "paperplane")
                    }
                }

            }
            .listStyle(SidebarListStyle())
            .clipped()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SidebarFooter()
            }
            .searchable(text: $searchText, placement: .sidebar)
            .navigationSplitViewColumnWidth(220)
        } detail: {
            switch selection {
            case .today:
                TodayPane()
            case .discover:
                DiscoverPane()
            case .installed:
                InstalledPane()
            case .design:
                DesignPane()
            case .development:
                DevelopmentPane()
            case .entertainment:
                EntertainmentPane()
            case .finance:
                FinancePane()
            case .productivity:
                ProductivityPane()
            default:
                EmptyPane()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                DownloadsToolbarButton()
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    appearance = appearance.next
                } label: {
                    Label(appearance.label, systemImage: appearance.symbolName)
                }
                .help(appearance.label)
            }
        }
    }
}

#Preview {
    Sidebar()
}
