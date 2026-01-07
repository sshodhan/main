#!/bin/bash
# Sora Image-to-Video Test Script
# Creates a video from a reference image and optional prompt
#
# Usage:
#   export OPENAI_API_KEY="your-api-key"
#   ./sora-image-to-video.sh --image photo.jpg --prompt "Make it come alive"

set -e

# Configuration
API_BASE_URL="https://api.openai.com/v1"
DEFAULT_MODEL="sora-2"
DEFAULT_DURATION="4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check API key
if [ -z "$OPENAI_API_KEY" ]; then
    print_error "OPENAI_API_KEY environment variable is not set"
    echo "Please run: export OPENAI_API_KEY='your-api-key'"
    exit 1
fi

usage() {
    cat << EOF
Sora Image-to-Video Generator

Usage: $0 [options]

Required:
  --image, -i         Path to the reference image (jpg, png, webp)

Optional:
  --prompt, -p        Text prompt describing the desired video motion/action
  --model, -m         Model: sora-2 (fast) or sora-2-pro (quality) [default: sora-2]
  --duration, -d      Duration in seconds: 4, 8, or 12 [default: 4]
  --poll              Auto-poll until video is complete
  --download, -o      Download completed video to this path

Examples:
  # Basic: animate an image
  $0 -i photo.jpg

  # With prompt describing the motion
  $0 -i landscape.png -p "Camera slowly pans across the scene, clouds move gently"

  # High quality with auto-download
  $0 -i portrait.jpg -p "Person smiles and waves" -m sora-2-pro -d 8 --poll -o output.mp4

  # Product video
  $0 -i product.png -p "Product rotates 360 degrees on a pedestal" --poll

EOF
    exit 0
}

# Parse arguments
IMAGE=""
PROMPT=""
MODEL="$DEFAULT_MODEL"
DURATION="$DEFAULT_DURATION"
POLL=false
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --image|-i) IMAGE="$2"; shift 2 ;;
        --prompt|-p) PROMPT="$2"; shift 2 ;;
        --model|-m) MODEL="$2"; shift 2 ;;
        --duration|-d) DURATION="$2"; shift 2 ;;
        --poll) POLL=true; shift ;;
        --download|-o) OUTPUT="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

# Validate image
if [ -z "$IMAGE" ]; then
    print_error "Image is required. Use --image or -i"
    usage
fi

if [ ! -f "$IMAGE" ]; then
    print_error "Image file not found: $IMAGE"
    exit 1
fi

# Display info
print_info "Creating video from image: $IMAGE"
print_info "Model: $MODEL, Duration: ${DURATION}s"
if [ -n "$PROMPT" ]; then
    print_info "Prompt: \"$PROMPT\""
fi

# Build curl command
CURL_ARGS=(
    -s -X POST "${API_BASE_URL}/videos"
    -H "Authorization: Bearer $OPENAI_API_KEY"
    -F "model=$MODEL"
    -F "seconds=$DURATION"
    -F "image=@$IMAGE"
)

if [ -n "$PROMPT" ]; then
    CURL_ARGS+=(-F "prompt=$PROMPT")
fi

# Create video
echo ""
print_info "Submitting request to Sora API..."
RESPONSE=$(curl "${CURL_ARGS[@]}")

# Check for error
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    print_error "API Error:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

VIDEO_ID=$(echo "$RESPONSE" | jq -r '.id')
STATUS=$(echo "$RESPONSE" | jq -r '.status')

print_success "Video created!"
echo "$RESPONSE" | jq '.'

# Poll if requested
if [ "$POLL" = true ]; then
    echo ""
    print_info "Polling for completion (Ctrl+C to cancel)..."

    INTERVAL=10
    TIMEOUT=600
    ELAPSED=0

    while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))

        POLL_RESPONSE=$(curl -s -X GET "${API_BASE_URL}/videos/${VIDEO_ID}" \
            -H "Authorization: Bearer $OPENAI_API_KEY")

        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
        PROGRESS=$(echo "$POLL_RESPONSE" | jq -r '.progress // 0')

        print_info "Status: $STATUS (progress: ${PROGRESS}%, elapsed: ${ELAPSED}s)"

        case $STATUS in
            "completed")
                print_success "Video generation completed!"
                echo "$POLL_RESPONSE" | jq '.'

                # Download if output specified
                if [ -n "$OUTPUT" ]; then
                    echo ""
                    DOWNLOAD_URL=$(echo "$POLL_RESPONSE" | jq -r '.video_url // .url // .download_url // empty')

                    if [ -n "$DOWNLOAD_URL" ]; then
                        print_info "Downloading to: $OUTPUT"
                        curl -s -L "$DOWNLOAD_URL" -o "$OUTPUT"
                        print_success "Video saved to: $OUTPUT"
                    else
                        print_error "Could not extract download URL"
                    fi
                fi
                exit 0
                ;;
            "failed")
                print_error "Video generation failed!"
                echo "$POLL_RESPONSE" | jq '.'
                exit 1
                ;;
        esac
    done

    print_error "Timeout reached after ${TIMEOUT}s"
    exit 1
fi

# Show next steps if not polling
echo ""
echo "Next steps:"
echo "  Check status:  ./sora-video-test.sh status $VIDEO_ID"
echo "  Poll:          ./sora-video-test.sh poll $VIDEO_ID"
echo "  Download:      ./sora-video-test.sh download $VIDEO_ID -o video.mp4"
