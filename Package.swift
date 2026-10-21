// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Prisma",
    platforms: [
        .macOS(.v13)
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
