# GraphSketcher

A fast, simple graph drawing and data plotting app for OS X and iPad. 

## Apple Silicon version (2026)

This fork brings the Mac app up to date so it runs **natively on Apple Silicon Macs** (macOS 12 or later) and builds with current Xcode (tested with Xcode 27.2 on macOS 27). It no longer needs Rosetta, which Apple is phasing out.

**Download:** a ready-built app is on the [Releases page](https://github.com/KinkanKen/GraphSketcher/releases). It is not signed by a registered Apple developer, so macOS will block it the first time: try to open it, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

### What's changed

- **Apple Silicon build**: updated build settings and small source fixes so GraphSketcher and the Omni frameworks it uses compile with current Xcode. The OmniGroup frameworks are now included in this repository directly rather than as a submodule, since several of the fixes are in them.
- **Text label fixes**: typed label text no longer reverts to "label" when you press Return or click away, and the label box grows as you type.
- **LaTeX-style markup in labels**: type `\alpha`, `\Delta`, `\leq`, `\infty` and so on for symbols, `x_{t}` for subscripts and `e^{rt}` for superscripts. Spacing commands (`\,` `\:` `\;` `\quad`) and `\minus` work too. Markup is converted when you finish editing a label, and the Style inspector shows a label's markup so you can edit it there. Braces are required, so ordinary underscores are left alone, and unknown commands are left as typed.
- **Minus signs**: negative axis numbers use a true minus sign (−), and a hyphen typed in front of a number in a label becomes one.
- **Default fonts**: *File → Make Current Styles Default* now really saves your fonts. Previously the saved font was ignored and Helvetica 12 was always used. The fallback default is now Times New Roman 24.

### Building it yourself

1. Install Xcode from the Mac App Store and open it once to finish setup.
2. Download this repository (green **Code** button → **Download ZIP**, or `git clone`).
3. Double-click `build.command`. After a few minutes, `GraphSketcher (Apple Silicon).app` appears next to it; details are in `build.log`.

The app is signed for local use only ("ad hoc"), which is fine for running it on your own Macs.

---

*The original README follows.*

## Original README

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

Building GraphSketcher requires Xcode 5.1.

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
