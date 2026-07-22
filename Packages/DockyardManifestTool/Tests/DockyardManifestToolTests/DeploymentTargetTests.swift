import Testing
@testable import DockyardManifestTool

@Suite struct DeploymentTargetTests {

    @Test func extractsTarget() {
        let pbxproj = """
        buildSettings = {
            MACOSX_DEPLOYMENT_TARGET = 13.0;
            SWIFT_VERSION = 6.0;
        };
        """
        #expect(ManifestBuilder.extractDeploymentTarget(from: pbxproj) == "13.0")
    }

    @Test func extractsIntegerTarget() {
        let pbxproj = "MACOSX_DEPLOYMENT_TARGET = 26;"
        #expect(ManifestBuilder.extractDeploymentTarget(from: pbxproj) == "26")
    }

    @Test func missingTargetReturnsNil() {
        #expect(ManifestBuilder.extractDeploymentTarget(from: "SWIFT_VERSION = 6.0;") == nil)
    }
}
