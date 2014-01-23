# GraphSketcher

A fast, simple graph drawing and data plotting app for OS X and iPad. 

## Download 

If you aren't interested in building from source and contributing to the project, head over to the [The Releases Page](https://github.com/graphsketcher/GraphSketcher/releases) to download GraphSketcher for Mac.

## Introduction

GraphSketcher is a simple, elegant tool for quickly sketching graphs and plotting data — but you don’t even need data to get started. It’s perfect for reports, presentations, and problem sets where you need to produce sharp-looking graphs on the fly.

## Setting it Free

Graph Sketcher was created by Robin Stewart in 2007. The Omni Group further developed OmniGraphSketcher for Mac and brought it to the iPad in 2010. All GraphSketcher-related source code was open-sourced in 2014.

## What’s Inside

The Mac app is located inside the `App` folder; the iPad source is in the `iPad` folder. Shared code exists in `Model` and `OmniStyle`.

## How to Build

### Checking out the source

    git clone --recursive git://github.com/graphsketcher/GraphSketcher

### Supported Targets

GraphSketcher requires iOS 7 and Mac OS X 10.8.

### Prerequisites

Building GraphSketcher requires the GM release of Xcode 5.

#### GraphSketch for Mac

GraphSketcher for Mac is sandboxed, and thus must be signed when built. If you are enrolled in the Mac Developer Program, you may already have an appropriate code signing identity in your keychain. 

If you do not have an appropriate Mac code signing identity, please refer to the [Code Signing Guide](https://developer.apple.com/library/mac/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html) for additional information.

#### GraphSketch for iPad

To build GraphSketcher for iPad, you need an appropriate iOS code signing identity in your keychain. If you are enrolled in the iOS Developer program, you should already have an code signing identity in your keychain.

GraphSketcher depends on the OmniGroup frameworks (expressed as a submodule) and auxiliary build tools, and uses its build configurations, which sign all build products by default.

If you are not interested in building the Mac application, and you do not have an appropriate Mac code signing identity in your keychain, you must edit your local copy of "Target-Mac-Common.xcconfig". Change the following line:

    OMNI_MAC_CODE_SIGN_IDENTITY = Mac Developer:

to

    OMNI_MAC_CODE_SIGN_IDENTITY =

### Building GraphSketcher-Mac

Open “GraphSketcher-Mac.xcworkspace”.

Build the “All” scheme.

There is no step 3.

### Building GraphSketcher-iPad

Open “GraphSketcher-iPad.xcworkspace”.

Build the “GraphSketcher-iPad” scheme.

There is no step 3.

## License

MIT-style Omni Source License 2007.

See OmniSourceLicense.html in this package.

Enjoy!
