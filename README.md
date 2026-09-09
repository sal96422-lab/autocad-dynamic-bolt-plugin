# Dynamic Bolt Plugin for AutoCAD

A one-click AutoCAD plugin for placing side-view dynamic bolt-and-nut assemblies between two selected plate faces.

## Features

- Preserves the supplied `BOLT19` dynamic block and its grips.
- Uses two picked plate faces to set the head-to-nut grip distance.
- Provides a user-friendly Metric/Imperial size dialog.
- Supports the approved nominal bolt sizes shown below.
- Adds a Bolt button to the existing WELDSYM toolbar when that toolbar is installed.
- Loads automatically for each AutoCAD drawing.

### Metric sizes

M16, M20, M22, M24, M27, M30, and M36.

### Imperial sizes

1/2, 5/8, 3/4, 7/8, 1, 1-1/8, 1-1/4, and 1-1/2 inch.

## Installation

1. Close AutoCAD.
2. Download and run `Dynamic Bolt Plugin Installer.exe` from the repository release or root directory.
3. Restart AutoCAD.
4. Run `IBOLT`, or click the Bolt button on the WELDSYM toolbar.

Windows may display an unsigned-application warning because the installer is locally built and not code-signed.

## Usage

1. Pick the plate face under the bolt head.
2. Pick the opposite plate face beside the nut.
3. Choose Metric or Imperial.
4. Select the nominal bolt size.
5. Click OK to place the dynamic assembly.

## AutoCAD compatibility

The installer detects AutoCAD user Support folders under `%APPDATA%\Autodesk` and installs the files into each detected profile.
