// swift-tools-version: 6.0
import PackageDescription

// El dominio se prueba sin depender del simulador ni de servicios externos.
let package = Package(
    name: "BoardingPassCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BoardingPassCore", targets: ["BoardingPassCore"])],
    targets: [
        .target(name: "BoardingPassCore", path: "BoardingPass/Core"),
        .testTarget(name: "BoardingPassCoreTests", dependencies: ["BoardingPassCore"], path: "Tests/BoardingPassCoreTests")
    ]
)
