#!/bin/bash
# Sora Video API Test Script
# Based on OpenAI API Reference: https://platform.openai.com/docs/api-reference/videos
#
# Usage:
#   export OPENAI_API_KEY="your-api-key"
#   ./sora-video-test.sh <command> [options]
#
# Commands:
#   create        - Create a new video from a text prompt
#   create-image  - Create a video from an image
#   status        - Check the status of a video generation job
#   list          - List all videos
#   get           - Get details of a specific video
#   download      - Download a completed video
#   delete        - Delete a video
#   remix         - Remix an existing video with a new prompt

set -e

# Configuration
API_BASE_URL="https://api.openai.com/v1"
DEFAULT_MODEL="sora-2"
DEFAULT_DURATION="4"
DEFAULT_SIZE="1280x720"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_api_key() {
    if [ -z "$OPENAI_API_KEY" ]; then
        print_error "OPENAI_API_KEY environment variable is not set"
        echo "Please run: export OPENAI_API_KEY='your-api-key'"
        exit 1
    fi
}

usage() {
    cat << EOF
Sora Video API Test Script

Usage: $0 <command> [options]

Commands:
  create [options]         Create a video from a text prompt
    --prompt, -p          Text prompt describing the video (required)
    --model, -m           Model to use: sora-2 or sora-2-pro (default: sora-2)
    --duration, -d        Duration in seconds: 4, 8, or 12 (default: 4)
    --size, -s            Resolution: 720x1280, 1280x720, 1024x1792, 1792x1024 (default: 1280x720)

  create-image [options]   Create a video from an image
    --image, -i           Path to the input image (required)
    --prompt, -p          Text prompt describing the video
    --model, -m           Model to use (default: sora-2)
    --duration, -d        Duration in seconds (default: 4)

  status <video_id>        Check the status of a video generation job

  list [options]           List all videos
    --limit, -l           Number of videos to return (default: 20)
    --after, -a           Cursor for pagination

  get <video_id>           Get details of a specific video

  download <video_id>      Download a completed video
    --output, -o          Output file path (default: video_<id>.mp4)

  delete <video_id>        Delete a video

  remix <video_id>         Remix an existing video
    --prompt, -p          New prompt for the remix (required)
    --model, -m           Model to use (default: sora-2)

  poll <video_id>          Poll for video completion (waits until done)
    --interval, -i        Polling interval in seconds (default: 10)
    --timeout, -t         Maximum wait time in seconds (default: 600)

Examples:
  # Create a simple video
  $0 create -p "A cat playing piano on a concert stage"

  # Create a high-quality video with sora-2-pro
  $0 create -p "Cinematic shot of a sunset over mountains" -m sora-2-pro -d 8 -s 1792x1024

  # Check video status
  $0 status video_abc123

  # Poll until video is complete
  $0 poll video_abc123

  # Download completed video
  $0 download video_abc123 -o my_video.mp4

  # List recent videos
  $0 list -l 10

  # Remix an existing video
  $0 remix video_abc123 -p "Add fireworks in the background"

EOF
    exit 0
}

# API Functions
create_video() {
    local prompt=""
    local model="$DEFAULT_MODEL"
    local duration="$DEFAULT_DURATION"
    local size="$DEFAULT_SIZE"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --prompt|-p) prompt="$2"; shift 2 ;;
            --model|-m) model="$2"; shift 2 ;;
            --duration|-d) duration="$2"; shift 2 ;;
            --size|-s) size="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$prompt" ]; then
        print_error "Prompt is required. Use --prompt or -p"
        exit 1
    fi

    print_info "Creating video with prompt: \"$prompt\""
    print_info "Model: $model, Duration: ${duration}s, Size: $size"

    curl -s -X POST "${API_BASE_URL}/videos" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "prompt=$prompt" \
        -F "model=$model" \
        -F "seconds=$duration" \
        -F "size=$size" | jq '.'
}

create_video_from_image() {
    local image=""
    local prompt=""
    local model="$DEFAULT_MODEL"
    local duration="$DEFAULT_DURATION"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --image|-i) image="$2"; shift 2 ;;
            --prompt|-p) prompt="$2"; shift 2 ;;
            --model|-m) model="$2"; shift 2 ;;
            --duration|-d) duration="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$image" ]; then
        print_error "Image path is required. Use --image or -i"
        exit 1
    fi

    if [ ! -f "$image" ]; then
        print_error "Image file not found: $image"
        exit 1
    fi

    print_info "Creating video from image: $image"
    print_info "Model: $model, Duration: ${duration}s"

    local curl_args=(
        -s -X POST "${API_BASE_URL}/videos"
        -H "Authorization: Bearer $OPENAI_API_KEY"
        -F "model=$model"
        -F "seconds=$duration"
        -F "image=@$image"
    )

    if [ -n "$prompt" ]; then
        curl_args+=(-F "prompt=$prompt")
    fi

    curl "${curl_args[@]}" | jq '.'
}

get_video_status() {
    local video_id="$1"

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    print_info "Getting status for video: $video_id"

    curl -s -X GET "${API_BASE_URL}/videos/${video_id}" \
        -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.'
}

list_videos() {
    local limit="20"
    local after=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --limit|-l) limit="$2"; shift 2 ;;
            --after|-a) after="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    print_info "Listing videos (limit: $limit)"

    local url="${API_BASE_URL}/videos?limit=${limit}"
    if [ -n "$after" ]; then
        url="${url}&after=${after}"
    fi

    curl -s -X GET "$url" \
        -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.'
}

get_video() {
    local video_id="$1"

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    print_info "Getting details for video: $video_id"

    curl -s -X GET "${API_BASE_URL}/videos/${video_id}" \
        -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.'
}

download_video() {
    local video_id="$1"
    shift
    local output=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --output|-o) output="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    if [ -z "$output" ]; then
        output="video_${video_id}.mp4"
    fi

    print_info "Checking video status: $video_id"

    # First check if video is completed
    local response=$(curl -s -X GET "${API_BASE_URL}/videos/${video_id}" \
        -H "Authorization: Bearer $OPENAI_API_KEY")

    local status=$(echo "$response" | jq -r '.status')

    if [ "$status" != "completed" ]; then
        print_error "Video is not completed. Current status: $status"
        echo "$response" | jq '.'
        exit 1
    fi

    print_info "Downloading video to: $output"

    # Use the /content endpoint to download the video
    curl -s -X GET "${API_BASE_URL}/videos/${video_id}/content" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -o "$output"

    # Check if download succeeded
    if [ -f "$output" ] && [ -s "$output" ]; then
        print_success "Video saved to: $output"
    else
        print_error "Download failed or file is empty"
        exit 1
    fi
}

delete_video() {
    local video_id="$1"

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    print_info "Deleting video: $video_id"

    curl -s -X DELETE "${API_BASE_URL}/videos/${video_id}" \
        -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.'
}

remix_video() {
    local video_id="$1"
    shift
    local prompt=""
    local model="$DEFAULT_MODEL"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --prompt|-p) prompt="$2"; shift 2 ;;
            --model|-m) model="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    if [ -z "$prompt" ]; then
        print_error "Prompt is required for remix. Use --prompt or -p"
        exit 1
    fi

    print_info "Remixing video: $video_id"
    print_info "New prompt: \"$prompt\""

    curl -s -X POST "${API_BASE_URL}/videos/${video_id}/remix" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"prompt\": \"$prompt\",
            \"model\": \"$model\"
        }" | jq '.'
}

poll_video() {
    local video_id="$1"
    shift
    local interval=10
    local timeout=600

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval|-i) interval="$2"; shift 2 ;;
            --timeout|-t) timeout="$2"; shift 2 ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$video_id" ]; then
        print_error "Video ID is required"
        exit 1
    fi

    print_info "Polling video: $video_id (interval: ${interval}s, timeout: ${timeout}s)"

    local elapsed=0
    local status=""

    while [ $elapsed -lt $timeout ]; do
        local response=$(curl -s -X GET "${API_BASE_URL}/videos/${video_id}" \
            -H "Authorization: Bearer $OPENAI_API_KEY")

        status=$(echo "$response" | jq -r '.status')

        print_info "Status: $status (elapsed: ${elapsed}s)"

        case $status in
            "completed")
                print_success "Video generation completed!"
                echo "$response" | jq '.'
                exit 0
                ;;
            "failed")
                print_error "Video generation failed!"
                echo "$response" | jq '.'
                exit 1
                ;;
            "queued"|"in_progress")
                sleep $interval
                elapsed=$((elapsed + interval))
                ;;
            *)
                print_warning "Unknown status: $status"
                echo "$response" | jq '.'
                sleep $interval
                elapsed=$((elapsed + interval))
                ;;
        esac
    done

    print_error "Timeout reached after ${timeout}s. Last status: $status"
    exit 1
}

# Main script
check_api_key

if [ $# -eq 0 ]; then
    usage
fi

command="$1"
shift

case $command in
    create)
        create_video "$@"
        ;;
    create-image)
        create_video_from_image "$@"
        ;;
    status)
        get_video_status "$@"
        ;;
    list)
        list_videos "$@"
        ;;
    get)
        get_video "$@"
        ;;
    download)
        download_video "$@"
        ;;
    delete)
        delete_video "$@"
        ;;
    remix)
        remix_video "$@"
        ;;
    poll)
        poll_video "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: $command"
        usage
        ;;
esac
