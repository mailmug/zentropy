#!/usr/bin/env bash
set -e

APP_NAME="zentropy"
OPTIMIZE="-Doptimize=ReleaseFast"

# Define all targets (format: <zig-target> <output-dir>)
targets=(
  "aarch64-macos aarch64-macos"
  "x86_64-macos x86_64-macos"
  "aarch64-linux-gnu aarch64-linux-gnu"
  "x86_64-linux-gnu x86_64-linux-gnu"
)

for entry in "${targets[@]}"; do
  set -- $entry
  target=$1
  out_dir=release/$2

  echo "🔨 Building for $target ..."
  zig build -Dtarget=$target $OPTIMIZE

  mkdir -p $out_dir
  cp zig-out/bin/$APP_NAME $out_dir/$APP_NAME

  echo "✅ Done: $out_dir/$APP_NAME"
done

echo "🎉 All builds complete!"
