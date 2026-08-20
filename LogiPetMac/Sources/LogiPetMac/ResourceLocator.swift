import Foundation

enum ResourceLocator {
    private static let resourceBundleName = "LogiPetMac_LogiPetMac.bundle"

    private static let resourceBundle: Bundle? = {
        var searchRoots: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            searchRoots.append(resourceURL)
        }
        searchRoots.append(Bundle.main.bundleURL)

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            searchRoots.append(executableDirectory)

            var testDirectory = executableDirectory
            while testDirectory.pathExtension != "xctest",
                  testDirectory.path != testDirectory.deletingLastPathComponent().path {
                testDirectory.deleteLastPathComponent()
            }
            if testDirectory.pathExtension == "xctest" {
                searchRoots.append(testDirectory.deletingLastPathComponent())
            }
        }

        var visited = Set<String>()
        for root in searchRoots where visited.insert(root.standardizedFileURL.path).inserted {
            let candidate = root.appendingPathComponent(resourceBundleName, isDirectory: true)
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }
        return nil
    }()

    static func url(forResource name: String, withExtension extensionName: String,
                    subdirectory: String? = nil) -> URL? {
        for bundle in [resourceBundle, Bundle.main].compactMap({ $0 }) {
            if let url = bundle.url(
                forResource: name,
                withExtension: extensionName,
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }
}
