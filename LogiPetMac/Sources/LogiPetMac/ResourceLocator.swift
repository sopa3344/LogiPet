import Foundation

enum ResourceLocator {
    private static let bundles: [Bundle] = {
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

        var result = [Bundle.main]
        var visited = Set<String>()

        for root in searchRoots where visited.insert(root.standardizedFileURL.path).inserted {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension == "bundle" {
                guard let bundle = Bundle(url: url),
                      result.allSatisfy({ $0.bundleURL.standardizedFileURL != bundle.bundleURL.standardizedFileURL })
                else { continue }
                result.append(bundle)
            }
        }

        return result
    }()

    static func url(forResource name: String, withExtension extensionName: String,
                    subdirectory: String? = nil) -> URL? {
        for bundle in bundles {
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
