#!/bin/bash

# Script to prepend a 0.5-second black screen and append a 1-second black screen to each video in videos_raw folder

# ===== CONFIGURATION PATHS =====
# Input directory containing videos to process
INPUT_DIR="../data_saumya/data_study4-c/Study-4c-video-set-1/"

# Output directory for processed videos
OUTPUT_DIR="../data_saumya/data_study4-c/processed-videos/videos-set-1"

# Temporary directory for intermediate files
TEMP_DIR="/tmp"
# ===============================

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Counter for processed videos
count=0

# Process each video file
for video in "$INPUT_DIR"/*.{mp4,MP4,avi,AVI,mov,MOV,mkv,MKV}; do
    # Skip if no files match the pattern
    [ -e "$video" ] || continue
    # Get the filename without path
    filename=$(basename "$video")
    filename_no_ext="${filename%.*}"
    extension="${filename##*.}"

    # Output file path
    output="$OUTPUT_DIR/${filename_no_ext}.${extension}"

    echo "Processing: $filename"

    # Get video properties (width, height, fps)
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video")
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$video")

    # Detect audio stream in source video
    has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$video")

    # Create temporary black screen videos
    temp_black_before="$TEMP_DIR/temp_black_before_${filename_no_ext}.mp4"
    temp_black_after="$TEMP_DIR/temp_black_after_${filename_no_ext}.mp4"

    if [ -n "$has_audio" ]; then
        # Generate black screens with silent audio to match source streams
        ffmpeg -f lavfi -i color=c=black:s=${width}x${height}:r=${fps}:d=0.5 \
               -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
               -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
               "$temp_black_before" -y 2>&1 | grep -v "^frame=" || true

        ffmpeg -f lavfi -i color=c=black:s=${width}x${height}:r=${fps}:d=1 \
               -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
               -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
               "$temp_black_after" -y 2>&1 | grep -v "^frame=" || true
    else
        # Generate video-only black screens
        ffmpeg -f lavfi -i color=c=black:s=${width}x${height}:r=${fps}:d=0.5 \
               -c:v libx264 -pix_fmt yuv420p "$temp_black_before" -y 2>&1 | grep -v "^frame=" || true

        ffmpeg -f lavfi -i color=c=black:s=${width}x${height}:r=${fps}:d=1 \
               -c:v libx264 -pix_fmt yuv420p "$temp_black_after" -y 2>&1 | grep -v "^frame=" || true
    fi

    # Create concat file with absolute paths
    concat_file="$TEMP_DIR/temp_concat_${filename_no_ext}.txt"
    echo "file '$temp_black_before'" > "$concat_file"
    echo "file '$(realpath "$video")'" >> "$concat_file"
    echo "file '$temp_black_after'" >> "$concat_file"

    # Re-encode output to fix DTS/timestamp issues that arise when concatenating
    # independently-encoded clips (using -c copy causes non-monotonic DTS errors)
    if [ -n "$has_audio" ]; then
        ffmpeg -f concat -safe 0 -i "$concat_file" \
               -c:v libx264 -pix_fmt yuv420p -c:a aac \
               "$output" -y 2>&1 | grep -v "^frame=" || true
    else
        ffmpeg -f concat -safe 0 -i "$concat_file" \
               -c:v libx264 -pix_fmt yuv420p -an \
               "$output" -y 2>&1 | grep -v "^frame=" || true
    fi

    # Clean up temporary files
    rm -f "$temp_black_before" "$temp_black_after" "$concat_file"

    echo "✓ Saved to: $output"
    ((count++))
done

echo ""
echo "Processed $count video(s)"
echo "Output files are in: $OUTPUT_DIR"
