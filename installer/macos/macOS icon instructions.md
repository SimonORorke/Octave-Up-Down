# Creating a macOS icon

On a Mac with Swift and the Apple command-line tools installed, prepare a square PNG with the artwork filling the image. A 1024 × 1024 image is recommended. The image should not already have macOS margins or rounded corners; transparent areas in the source remain transparent.

In Terminal, run the script with the input PNG and the desired output `.icns` path. Quote paths containing spaces:

```sh
swift '/Users/Simon/Documents/Software/Octave Up-Down/make-macos-icon.swift' '/path/to/input.png' '/path/to/output.icns'
```

For this project:

```sh
swift '/Users/Simon/Documents/Software/Octave Up-Down/make-macos-icon.swift' '/Users/Simon/Documents/Rust Projects/octave-up-down/ui/images/Octave Up-Down.png' '/Users/Simon/Documents/Rust Projects/octave-up-down/ui/images/Octave Up-Down.icns'
```

The destination folder must already exist, and the script refuses to overwrite an existing output. Choose a new output name when regenerating, then replace the original if desired.

The script scales the square artwork into a centered 824 × 824 tile on a transparent 1024 × 1024 canvas, clips it to a continuous-corner squircle approximating the macOS icon shape, and produces all standard `.iconset` sizes using `iconutil`. It adds no shadow, gradient, or other shading. Small details near the input corners can be clipped; adjust the original artwork if needed.