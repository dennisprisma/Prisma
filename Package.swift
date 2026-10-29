// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Prisma",
    // Lo stesso target compila per il Mac (swift build) e per iPhone e iPad
    // (xcodebuild con il simulatore, vedi .github/workflows/build.yml e Supporto/iOS/).
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "Prisma",
            path: "Sources/Prisma",
            resources: [
                // Icone dell'interfaccia convertite da Design/Icone (PNG 512 px)
                .copy("Risorse")
            ]
        )
    ]
)
