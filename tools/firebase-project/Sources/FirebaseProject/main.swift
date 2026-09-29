import Foundation
import XcodeProj
import PathKit

// Explicit target selection: the bundled setup helper uses an unordered first target.
let path = Path(CommandLine.arguments[1])
let project = try XcodeProj(path: path)
let pbx = project.pbxproj
let root = try pbx.rootProject()!
let target = pbx.nativeTargets.first { $0.name == "CoastWild" }!
let package = root.remotePackages.first { $0.repositoryURL == "https://github.com/firebase/firebase-ios-sdk" }!
for t in pbx.nativeTargets {
    t.packageProductDependencies?.removeAll { $0.productName.hasPrefix("Firebase") }
    for phase in t.buildPhases.compactMap({ $0 as? PBXFrameworksBuildPhase }) {
        phase.files?.removeAll { $0.product?.productName.hasPrefix("Firebase") == true }
    }
}
let frameworks = target.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }.first!
for name in ["FirebaseCore", "FirebaseAuth", "FirebaseFirestore"] {
    let dependency = XCSwiftPackageProductDependency(productName: name, package: package)
    pbx.add(object: dependency)
    target.packageProductDependencies = (target.packageProductDependencies ?? []) + [dependency]
    let buildFile = PBXBuildFile(product: dependency)
    pbx.add(object: buildFile)
    frameworks.files = (frameworks.files ?? []) + [buildFile]
}
let plist = pbx.fileReferences.first { $0.name == "GoogleService-Info.plist" }!
plist.sourceTree = .sourceRoot
plist.path = "CoastWild/Resources/GoogleService-Info.plist"
let resources = target.buildPhases.compactMap { $0 as? PBXResourcesBuildPhase }.first!
if !(resources.files ?? []).contains(where: { $0.file == plist }) { _ = try resources.add(file: plist) }
// This legacy project uses explicit source membership, not synchronized folders.
let sources = target.buildPhases.compactMap { $0 as? PBXSourcesBuildPhase }.first!
for source in ["CoastWild/Core/PublicContentCache.swift", "CoastWild/App/PublicContentService.swift"] {
    let reference: PBXFileReference
    if let existing = pbx.fileReferences.first(where: { $0.path == source }) { reference = existing }
    else {
        reference = PBXFileReference(sourceTree: .sourceRoot, lastKnownFileType: "sourcecode.swift", path: source)
        pbx.add(object: reference)
        root.mainGroup.children.append(reference)
    }
    if !(sources.files ?? []).contains(where: { $0.file == reference }) { _ = try sources.add(file: reference) }
}
for config in target.buildConfigurationList?.buildConfigurations ?? [] {
    config.buildSettings["OTHER_LDFLAGS"] = ["$(inherited)", "-ObjC"]
}
try project.write(path: path)
print("Firebase linked only to CoastWild; existing signing preserved.")
