#!/bin/bash
# DALL-E to Sora Video Pipeline
# Generates an image with DALL-E, then creates a video with Sora
#
# Usage:
#   export OPENAI_API_KEY="your-api-key"
#   ./dalle-to-sora.sh --image-prompt "A fashion model..." --video-prompt "Model walks forward..."

set -e

# Configuration
API_BASE_URL="https://api.openai.com/v1"
DEFAULT_VIDEO_MODEL="sora-2"
DEFAULT_DURATION="4"
DEFAULT_SIZE="1792x1024"
DEFAULT_DALLE_MODEL="dall-e-3"
DEFAULT_DALLE_SIZE="1792x1024"
DEFAULT_DALLE_QUALITY="hd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${YELLOW}[STEP $1]${NC} $2"; }

# Check API key
if [ -z "$OPENAI_API_KEY" ]; then
    print_error "OPENAI_API_KEY environment variable is not set"
    echo "Please run: export OPENAI_API_KEY='your-api-key'"
    exit 1
fi

usage() {
    cat << EOF
DALL-E to Sora Video Pipeline

Generates an AI image with DALL-E, then animates it with Sora.

Usage: $0 [options]

Required:
  --image-prompt, -ip   Prompt for DALL-E image generation
  --video-prompt, -vp   Prompt for Sora video animation

Optional:
  --video-model, -vm    Sora model: sora-2 or sora-2-pro [default: sora-2]
  --duration, -d        Video duration: 4, 8, or 12 seconds [default: 4]
  --size, -s            Output size: 1792x1024, 1024x1792, 1280x720, 720x1280 [default: 1792x1024]
  --dalle-quality, -dq  DALL-E quality: standard or hd [default: hd]
  --keep-image          Keep the generated image file
  --output, -o          Output video filename [default: output.mp4]

Examples:
  # Fashion model video
  $0 \\
    -ip "Professional fashion photograph of a male model in his late 20s wearing a charcoal sweater, indigo jeans, navy parka, and brown Chelsea boots. Full body shot, studio lighting, white background." \\
    -vp "Model walks forward confidently with natural movement, professional runway lighting" \\
    -vm sora-2-pro -d 8 -o fashion_video.mp4

  # Product showcase
  $0 \\
    -ip "A sleek smartphone floating against a gradient blue background, professional product photography" \\
    -vp "Phone slowly rotates 360 degrees, dramatic lighting" \\
    -d 4 -o product_video.mp4

  # Nature scene
  $0 \\
    -ip "Serene mountain lake at sunset with pine trees, photorealistic landscape" \\
    -vp "Gentle camera pan across the scene, water ripples softly, clouds drift" \\
    -vm sora-2-pro -d 12 -o nature_video.mp4

EOF
    exit 0
}

# Parse arguments
IMAGE_PROMPT=""
VIDEO_PROMPT=""
VIDEO_MODEL="$DEFAULT_VIDEO_MODEL"
DURATION="$DEFAULT_DURATION"
SIZE="$DEFAULT_SIZE"
DALLE_QUALITY="$DEFAULT_DALLE_QUALITY"
KEEP_IMAGE=false
OUTPUT="output.mp4"

while [[ $# -gt 0 ]]; do
    case $1 in
        --image-prompt|-ip) IMAGE_PROMPT="$2"; shift 2 ;;
        --video-prompt|-vp) VIDEO_PROMPT="$2"; shift 2 ;;
        --video-model|-vm) VIDEO_MODEL="$2"; shift 2 ;;
        --duration|-d) DURATION="$2"; shift 2 ;;
        --size|-s) SIZE="$2"; shift 2 ;;
        --dalle-quality|-dq) DALLE_QUALITY="$2"; shift 2 ;;
        --keep-image) KEEP_IMAGE=true; shift ;;
        --output|-o) OUTPUT="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

# Validate required arguments
if [ -z "$IMAGE_PROMPT" ]; then
    print_error "Image prompt is required. Use --image-prompt or -ip"
    usage
fi

if [ -z "$VIDEO_PROMPT" ]; then
    print_error "Video prompt is required. Use --video-prompt or -vp"
    usage
fi

# Map Sora size to DALL-E size
case $SIZE in
    "1792x1024") DALLE_SIZE="1792x1024" ;;
    "1024x1792") DALLE_SIZE="1024x1792" ;;
    "1280x720"|"720x1280")
        # DALL-E doesn't support these exact sizes, use closest
        if [ "$SIZE" = "1280x720" ]; then
            DALLE_SIZE="1792x1024"
        else
            DALLE_SIZE="1024x1792"
        fi
        ;;
    *) DALLE_SIZE="1792x1024" ;;
esac

TEMP_IMAGE="dalle_generated_$(date +%s).png"

echo ""
echo "=============================================="
echo "  DALL-E to Sora Video Pipeline"
echo "=============================================="
echo ""

# Step 1: Generate image with DALL-E
print_step "1/4" "Generating image with DALL-E 3..."
print_info "Prompt: \"$IMAGE_PROMPT\""
print_info "Size: $DALLE_SIZE, Quality: $DALLE_QUALITY"
echo ""

DALLE_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/images/generations" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$DEFAULT_DALLE_MODEL\",
        \"prompt\": \"$IMAGE_PROMPT\",
        \"n\": 1,
        \"size\": \"$DALLE_SIZE\",
        \"quality\": \"$DALLE_QUALITY\",
        \"response_format\": \"url\"
    }")

# Check for errors
if echo "$DALLE_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    print_error "DALL-E API Error:"
    echo "$DALLE_RESPONSE" | jq '.'
    exit 1
fi

IMAGE_URL=$(echo "$DALLE_RESPONSE" | jq -r '.data[0].url')
REVISED_PROMPT=$(echo "$DALLE_RESPONSE" | jq -r '.data[0].revised_prompt // empty')

if [ -z "$IMAGE_URL" ] || [ "$IMAGE_URL" = "null" ]; then
    print_error "Failed to get image URL from DALL-E response"
    echo "$DALLE_RESPONSE" | jq '.'
    exit 1
fi

print_success "Image generated!"
if [ -n "$REVISED_PROMPT" ]; then
    print_info "DALL-E revised prompt: \"$REVISED_PROMPT\""
fi
echo ""

# Step 2: Download the image
print_step "2/4" "Downloading generated image..."

curl -s -L "$IMAGE_URL" -o "$TEMP_IMAGE"

if [ ! -f "$TEMP_IMAGE" ] || [ ! -s "$TEMP_IMAGE" ]; then
    print_error "Failed to download image"
    exit 1
fi

print_success "Image saved to: $TEMP_IMAGE"
echo ""

# Step 3: Resize image if needed (for 1280x720 or 720x1280)
if [ "$SIZE" = "1280x720" ] || [ "$SIZE" = "720x1280" ]; then
    print_step "2.5/4" "Resizing image to match Sora size ($SIZE)..."

    # Extract width and height
    WIDTH=$(echo "$SIZE" | cut -d'x' -f1)
    HEIGHT=$(echo "$SIZE" | cut -d'x' -f2)

    # Check if sips is available (macOS)
    if command -v sips &> /dev/null; then
        sips -z "$HEIGHT" "$WIDTH" "$TEMP_IMAGE" --out "$TEMP_IMAGE" > /dev/null 2>&1
        print_success "Image resized to ${WIDTH}x${HEIGHT}"
    else
        print_error "sips not available. Please resize manually or use 1792x1024 or 1024x1792 size."
        exit 1
    fi
    echo ""
fi

# Step 4: Create video with Sora
print_step "3/4" "Creating video with Sora..."
print_info "Model: $VIDEO_MODEL, Duration: ${DURATION}s, Size: $SIZE"
print_info "Video prompt: \"$VIDEO_PROMPT\""
echo ""

SORA_RESPONSE=$(curl -s -X POST "${API_BASE_URL}/videos" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: multipart/form-data" \
    -F "model=$VIDEO_MODEL" \
    -F "seconds=$DURATION" \
    -F "size=$SIZE" \
    -F "prompt=$VIDEO_PROMPT" \
    -F "input_reference=@$TEMP_IMAGE")

# Check for errors
if echo "$SORA_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    print_error "Sora API Error:"
    echo "$SORA_RESPONSE" | jq '.'
    # Clean up temp image
    if [ "$KEEP_IMAGE" = false ]; then
        rm -f "$TEMP_IMAGE"
    fi
    exit 1
fi

VIDEO_ID=$(echo "$SORA_RESPONSE" | jq -r '.id')
print_success "Video job created: $VIDEO_ID"
echo ""

# Step 5: Poll for completion
print_step "4/4" "Waiting for video generation (this may take a few minutes)..."

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
            echo ""
            print_success "Video generation completed!"

            # Download the video
            print_info "Downloading video to: $OUTPUT"
            curl -s -X GET "${API_BASE_URL}/videos/${VIDEO_ID}/content" \
                -H "Authorization: Bearer $OPENAI_API_KEY" \
                -o "$OUTPUT"

            if [ -f "$OUTPUT" ] && [ -s "$OUTPUT" ]; then
                print_success "Video saved to: $OUTPUT"
            else
                print_error "Download failed or file is empty"
            fi

            # Clean up temp image
            if [ "$KEEP_IMAGE" = false ]; then
                rm -f "$TEMP_IMAGE"
                print_info "Cleaned up temporary image"
            else
                print_info "Generated image kept at: $TEMP_IMAGE"
            fi

            echo ""
            echo "=============================================="
            echo "  Pipeline Complete!"
            echo "=============================================="
            echo "  Video: $OUTPUT"
            if [ "$KEEP_IMAGE" = true ]; then
                echo "  Image: $TEMP_IMAGE"
            fi
            echo "=============================================="
            exit 0
            ;;
        "failed")
            echo ""
            print_error "Video generation failed!"
            echo "$POLL_RESPONSE" | jq '.'
            # Clean up temp image
            if [ "$KEEP_IMAGE" = false ]; then
                rm -f "$TEMP_IMAGE"
            fi
            exit 1
            ;;
    esac
done

print_error "Timeout reached after ${TIMEOUT}s"
# Clean up temp image
if [ "$KEEP_IMAGE" = false ]; then
    rm -f "$TEMP_IMAGE"
fi
exit 1
