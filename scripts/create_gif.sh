#!/bin/bash

# Create optimized GIF from numbered JPG sequence
# Usage: ./create_gif.sh [framerate]
# If no framerate given, calculates based on number of images for 2-second total duration

FRAMERATE=$2
IMAGE_DIR=$1

if [ -z "$FRAMERATE" ]; then
    # Count JPG files and calculate framerate for 2-second duration
    IMAGE_COUNT=$(ls $IMAGE_DIR/*.jpg 2>/dev/null | wc -l)
    if [ $IMAGE_COUNT -eq 0 ]; then
        echo "No JPG files found!"
        exit 1
    fi
    FRAMERATE=$(echo "scale=2; $IMAGE_COUNT / 2" | bc)
    echo "Using calculated framerate: $FRAMERATE fps for $IMAGE_COUNT images"
else
    echo "Using specified framerate: $FRAMERATE fps"
fi

ffmpeg -y \
  -framerate $FRAMERATE \
  -i "$IMAGE_DIR/%02d.jpg" \
  -vf "scale=1280:-1:flags=lanczos,palettegen" \
  "$IMAGE_DIR/palette.png"

ffmpeg -y \
  -framerate $FRAMERATE \
  -i "$IMAGE_DIR/%02d.jpg" \
  -i "$IMAGE_DIR/palette.png" \
  -lavfi "scale=1280:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 \
  "$IMAGE_DIR/output.gif"

# Clean up temporary palette file
rm "$IMAGE_DIR/palette.png"

echo "GIF created as output.gif"
