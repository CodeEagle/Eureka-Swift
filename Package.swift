// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EurekaSwift",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EurekaSwift",
            targets: ["EurekaSwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.12.0"),
        .package(url: "https://github.com/MihaelIsaev/NIOCronScheduler.git", from:"2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "EurekaSwift",
            dependencies: [
                "OpenCombine",
                .product(name: "OpenCombineFoundation", package: "OpenCombine"),
                .product(name: "OpenCombineDispatch", package: "OpenCombine"),
                "NIOCronScheduler",
            ]),
        .testTarget(
            name: "EurekaSwiftTests",
            dependencies: ["EurekaSwift"]),
    ]
)
