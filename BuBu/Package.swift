// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BuBu",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // 使用可执行产品，供上层 iOS App 工程引用
        .executable(
            name: "BuBu",
            targets: ["AppModule"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)

