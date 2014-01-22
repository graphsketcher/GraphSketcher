# GraphSketcher

A fast, simple graph drawing and data plotting app for OS X and iPad. 

## Download 

If you just want to download and aren't interested in contributing, go to [The Releases Page](https://github.com/graphsketcher/GraphSketcher/releases).

## Introduction

GraphSketcher is a simple, elegant tool for quickly sketching graphs and plotting data — but you don’t even need data to get started. It’s perfect for reports, presentations, and problem sets where you need to produce sharp-looking graphs on the fly.

## Setting it Free

Graph Sketcher was created by Robin Stewart in 2007. The Omni Group further developed OmniGraphSketcher for Mac and brought it to the iPad in 2010. All GraphSketcher-related source code was open-sourced in 2014.

##What’s Inside

The Mac app is located inside the `App` folder; the iPad source is in the `iPad` folder. Shared code exists in `Model` and `OmniStyle`.

##How to Build

### Checking out the source

    git clone --recursive git://github.com/graphsketcher/GraphSketcher

### Supported Targets

- GraphSketcher requires iOS 7 and Mac OS X 10.8.

### Codesigning Identifies

If are are not interested in building the Mac application (which must be signed because it is sandboxed), in your local copy of "Target-Mac-Common.xcconfig" change the following line:

// For Xcode builds, we sign our applications using our individual development certificates ("Mac Developer: [Person]"). For distribution builds, our build scripts will re-sign as "Developer ID Application: [Company]" (for direct downloads) or "3rd Party Mac Developer Application: [Company]" (for Mac App Store submissions).
OMNI_MAC_CODE_SIGN_IDENTITY = Mac Developer:
to

// For Xcode builds, we sign our applications using our individual development certificates ("Mac Developer: [Person]"). For distribution builds, our build scripts will re-sign as "Developer ID Application: [Company]" (for direct downloads) or "3rd Party Mac Developer Application: [Company]" (for Mac App Store submissions).
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
