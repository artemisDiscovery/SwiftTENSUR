// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftTENSUR",
    
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // tags starting with 3 are for debugging
        //.package(url: "git@github.com:artemisDiscovery/SwiftTENSURTools.git" , exact: "1.2.11"),
        .package(url: "git@github.com:artemisDiscovery/SwiftTENSURTools.git" , exact: "2.0.1"),
        .package(url: "git@github.com:artemisDiscovery/MathTools.git" , exact: "1.0.22"),
        //.package(url: "../SwiftTENSURTools" , from: "1.2.11"),
        
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftTENSUR", dependencies:["SwiftTENSURTools", "MathTools"]),
    ]
)
