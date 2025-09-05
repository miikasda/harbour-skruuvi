#!/bin/bash

# Initialize variables
REMOTE_HOST=""
SOURCE_DIR=""
REMOTE_SOURCE_DIR=""
REMOTE_BUILD_DIR=""
BUILD_TARGET=""
DEVICE_IP=""
DEPLOY=true  # As default deploy to phone


usage() {
    echo "Usage: $0 -r <remote_host> -s <source_dir> -S <remote_source_dir> -B <remote_build_dir> -t <build_target> -d <device_ip> [--local-install]"
    echo
    echo "All options are required:"
    echo "  -r  Remote SSH host (e.g., user@host)"
    echo "  -s  Local source directory"
    echo "  -S  Remote source directory"
    echo "  -B  Remote build directory"
    echo "  -t  Build target (e.g., SailfishOS-5.0.0.62-aarch64)"
    echo "  -d  Device IP address"
    echo "  -h  Show this help message"
    echo "  --local-install  Skip deploying to device, install RPM locally instead"
    exit "${1:-1}"  # default to exit code 1 if none is given

}

# Parse options
while getopts "r:s:S:B:t:d:h" opt; do
    case $opt in
        r) REMOTE_HOST="$OPTARG" ;;
        s) SOURCE_DIR="$OPTARG" ;;
        S) REMOTE_SOURCE_DIR="$OPTARG" ;;
        B) REMOTE_BUILD_DIR="$OPTARG" ;;
        t) BUILD_TARGET="$OPTARG" ;;
        d) DEVICE_IP="$OPTARG" ;;
        h) usage 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Shift out parsed arguments
shift $((OPTIND -1))
# Look for --local-install in remaining arguments
for arg in "$@"; do
    if [ "$arg" = "--local-install" ]; then
        DEPLOY=false
        break
    fi
done

# Validate required arguments depending on DEPLOY
if [ "$DEPLOY" = true ]; then
    # Deploy mode: all flags including -d required
    if [ -z "$REMOTE_HOST" ] || [ -z "$SOURCE_DIR" ] || [ -z "$REMOTE_SOURCE_DIR" ] || \
       [ -z "$REMOTE_BUILD_DIR" ] || [ -z "$BUILD_TARGET" ] || [ -z "$DEVICE_IP" ]; then
        echo "Error: Missing required arguments for deployment." >&2
        usage
    fi
else
    # Local install mode: same except -d (DEVICE_IP) not required
    if [ -z "$REMOTE_HOST" ] || [ -z "$SOURCE_DIR" ] || [ -z "$REMOTE_SOURCE_DIR" ] || \
       [ -z "$REMOTE_BUILD_DIR" ] || [ -z "$BUILD_TARGET" ]; then
        echo "Error: Missing required arguments for local install." >&2
        usage
    fi
fi

# Debug arguments
echo "Remote host:        $REMOTE_HOST"
echo "Local source dir:   $SOURCE_DIR"
echo "Remote source dir:  $REMOTE_SOURCE_DIR"
echo "Remote build dir:   $REMOTE_BUILD_DIR"
echo "Build target:       $BUILD_TARGET"
echo "Device IP:          $DEVICE_IP"
echo "Deploy:             $DEPLOY"
echo


# Step 1: Parse architecture from BUILD_TARGET
ARCHITECTURE=$(echo "$BUILD_TARGET" | grep -oE '[^-]+$')


# Step 2: Sync source directory to remote host
echo "Syncing $SOURCE_DIR to $REMOTE_HOST:$REMOTE_SOURCE_DIR..."
rsync -avz "$SOURCE_DIR/" "$REMOTE_HOST:$REMOTE_SOURCE_DIR"
echo


# Step 3: Execute build command on remote host
echo "Building on remote host..."
ssh "$REMOTE_HOST" "/home/miika/SailfishOS/bin/sfdk config --push target $BUILD_TARGET && cd $REMOTE_BUILD_DIR && /home/miika/SailfishOS/bin/sfdk build $REMOTE_SOURCE_DIR"
if [ $? -eq 0 ]; then
    echo "  ✅ Build succeeded."
else
    echo "  ❌ Build failed."
    exit 1
fi
echo


# Step 4: Fetch the RPM file from remote build directory
echo "Fetching built RPM file..."
RPM_FILE=$(ssh "$REMOTE_HOST" "find $REMOTE_BUILD_DIR/RPMS -name '*$ARCHITECTURE.rpm' -type f -print0 | xargs -0 ls -t | head -n 1")

if [ -z "$RPM_FILE" ]; then
    echo "Error: No RPM file found for architecture $ARCHITECTURE."
    exit 1
fi

echo "Found RPM file: $RPM_FILE"
LOCAL_RPM_FILE=$(basename "$RPM_FILE")
rsync -avz "$REMOTE_HOST:$RPM_FILE" "./$LOCAL_RPM_FILE"
echo


# Step 5: Install the RPM
if [ "$DEPLOY" = true ]; then
    echo "Deploying RPM to device at $DEVICE_IP..."
    rsync -avz "./$LOCAL_RPM_FILE" "defaultuser@$DEVICE_IP:$LOCAL_RPM_FILE"
    ssh "defaultuser@$DEVICE_IP" "devel-su pkcon install-local ./$LOCAL_RPM_FILE --noninteractive"
    # Cleanup
    ssh "defaultuser@$DEVICE_IP" "rm ./$LOCAL_RPM_FILE"
    rm "./$LOCAL_RPM_FILE"
else
    echo "Installing $LOCAL_RPM_FILE..."
    devel-su pkcon install-local "./$LOCAL_RPM_FILE"
    rm "./$LOCAL_RPM_FILE"
fi

echo
echo "Build completed successfully!"
