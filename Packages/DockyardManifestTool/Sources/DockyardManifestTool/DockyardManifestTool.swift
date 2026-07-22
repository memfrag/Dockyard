import ArgumentParser

@main
struct DockyardManifestTool: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "dockyard-manifest-tool",
        abstract: "Build and publish a Dockyard catalog manifest from a config file by resolving each app's latest GitHub release.",
        subcommands: [Build.self, Publish.self, Add.self, SetToken.self, ClearToken.self],
        defaultSubcommand: Build.self
    )
}
