import Foundation

enum ResourceLocator {
    private static let resourceBundleName = "LogiPetMac_LogiPetMac.bundle"

    private static let resourceBundle: Bundle? = {
        var searchRoots: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            searchRoots.append(resourceURL)
        }
        let mainBundleURL = Bundle.main.bundleURL
        searchRoots.append(mainBundleURL)
        if mainBundleURL.pathExtension == "xctest" {
            searchRoots.append(mainBundleURL.deletingLastPathComponent())
        }

        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            searchRoots.append(executableDirectory)
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
#if DEBUG
        return Bundle.module.url(
            forResource: name,
            withExtension: extensionName,
            subdirectory: subdirectory
        )
#else
        return nil
#endif
    }

    static var requiredResourcesAvailable: Bool {
        url(
            forResource: "Galmuri11",
            withExtension: "ttf",
            subdirectory: "Resources/Fonts"
        ) != nil && url(
            forResource: "Golden-Retriever-idle",
            withExtension: "png",
            subdirectory: "Resources/Pets/GoldenRetriever"
        ) != nil
    }
}
