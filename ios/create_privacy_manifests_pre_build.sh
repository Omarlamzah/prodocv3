#!/bin/bash
# Create privacy manifest files before Xcode build
# This script should be run as a pre-build step in Codemagic UI workflow

set -e

echo "=========================================="
echo "Creating Privacy Manifest Files"
echo "=========================================="

# List of packages that need privacy manifests
PACKAGES="url_launcher_ios sqflite_darwin shared_preferences_foundation path_provider_foundation flutter_secure_storage flutter_local_notifications share_plus"

# Function to create privacy manifest for a package
create_manifest() {
  local pkg=$1
  local base_dir=$2
  
  if [ -z "$pkg" ] || [ -z "$base_dir" ]; then
    return 0
  fi
  
  BUNDLE_DIR="${base_dir}/${pkg}_privacy.bundle"
  MANIFEST_FILE="${BUNDLE_DIR}/${pkg}_privacy"
  
  mkdir -p "$BUNDLE_DIR" || true
  touch "$MANIFEST_FILE" || true
  chmod 644 "$MANIFEST_FILE" || true
  
  if [ -f "$MANIFEST_FILE" ]; then
    echo "✓ Created: $MANIFEST_FILE"
    return 0
  else
    echo "✗ Failed to create: $MANIFEST_FILE"
    return 1
  fi
}

# Create in DerivedData locations (where Xcode looks during archive builds)
DERIVED_DATA_BASE="$HOME/Library/Developer/Xcode/DerivedData"
echo "Checking DerivedData: $DERIVED_DATA_BASE"

if [ -d "$DERIVED_DATA_BASE" ]; then
  # Find all Runner-* directories
  for runner_dir in "$DERIVED_DATA_BASE"/Runner-*; do
    if [ -d "$runner_dir" ]; then
      uninstalled_dir="${runner_dir}/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/iphoneos"
      
      # Create parent directories if they don't exist
      mkdir -p "$uninstalled_dir" || true
      
      echo "Creating manifests in: $uninstalled_dir"
      for pkg in $PACKAGES; do
        create_manifest "$pkg" "$uninstalled_dir"
      done
    fi
  done
  
  # Also create in Runner-template directory (if it exists)
  if [ -d "${DERIVED_DATA_BASE}/Runner-template" ]; then
    template_dir="${DERIVED_DATA_BASE}/Runner-template/Build/Intermediates.noindex/ArchiveIntermediates/Runner/IntermediateBuildFilesPath/UninstalledProducts/iphoneos"
    mkdir -p "$template_dir" || true
    echo "Creating manifests in template: $template_dir"
    for pkg in $PACKAGES; do
      create_manifest "$pkg" "$template_dir"
    done
  fi
else
  echo "⚠ DerivedData directory not found, will create during build"
fi

# Create in build directory (for regular builds)
BUILD_DIR="build/ios/Release-iphoneos"
mkdir -p "$BUILD_DIR" || true
echo "Creating manifests in build directory: $BUILD_DIR"
for pkg in $PACKAGES; do
  create_manifest "$pkg" "$BUILD_DIR"
done

# Also create in Pods directory (so they're part of the project)
PODS_DIR="ios/Pods"
if [ -d "$PODS_DIR" ]; then
  echo "Creating manifests in Pods directory: $PODS_DIR"
  for pkg in $PACKAGES; do
    create_manifest "$pkg" "$PODS_DIR"
  done
fi

echo ""
echo "=========================================="
echo "Privacy Manifest Creation Complete"
echo "=========================================="
