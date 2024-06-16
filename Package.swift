// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTENSUR",
    platforms:[ .macOS(.v14) ],
    products: [
        .library(
          name: "libpmp",
          type: .dynamic,
          targets: ["libpmp"]),
        .executable(
            name: "SwiftTENSUR",
            targets: ["SwiftTENSUR"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "git@github.com:artemisDiscovery/SwiftTENSURTools.git" , exact: "1.0.16"),
        .package(url: "git@github.com:artemisDiscovery/MathTools.git" , from: "1.0.16"),
        
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .binaryTarget( name: "libpmp", path:"build/libpmp.xcframework"),
        .executableTarget(
            name: "SwiftTENSUR", dependencies:["SwiftTENSURTools", "MathTools", "libpmp"]),
    ]
)
