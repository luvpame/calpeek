// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "calpeek",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "calpeek",
            exclude: ["Info.plist"],
            // CLI には bundle がないため、Info.plist(カレンダー権限の usage description)を
            // バイナリ本体に埋め込む。詳細は docs/adr/0001 を参照。
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/calpeek/Info.plist",
                ])
            ]
        )
    ]
)
