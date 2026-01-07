# Sora Video API - Vercel/React Implementation Guide

This guide explains how to implement OpenAI's Sora video generation API in a Vercel/Next.js application. It addresses common issues like the **405 Method Not Allowed** error and aligns with the Aura Stylist architecture.

## Table of Contents
1. [Understanding the 405 Error](#understanding-the-405-error)
2. [API Overview](#api-overview)
3. [Architecture Overview](#architecture-overview)
4. [Server Actions Implementation](#server-actions-implementation)
5. [Video API Client Service](#video-api-client-service)
6. [React Components](#react-components)
7. [Prompt Structure](#prompt-structure)
8. [Important Limitations](#important-limitations)

---

## Understanding the 405 Error

The 405 error typically occurs due to:

| Cause | Solution |
|-------|----------|
| Calling OpenAI API from browser | Use server actions or API routes |
| Wrong HTTP method | Use POST for `/videos`, GET for status |
| Using JSON instead of FormData | Use `multipart/form-data` for video creation |
| Setting Content-Type manually | Let fetch set it automatically for FormData |
| CORS blocking client requests | Proxy through server-side code |

**Critical Fix:** The Sora `/videos` endpoint requires `multipart/form-data`, NOT `application/json`:

```typescript
// ❌ WRONG - causes 405
const response = await fetch('https://api.openai.com/v1/videos', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',  // ❌ This causes 405!
    'Authorization': `Bearer ${apiKey}`,
  },
  body: JSON.stringify({ prompt, model, seconds, size }),
});

// ✅ CORRECT - use FormData
const formData = new FormData();
formData.append('prompt', prompt);
formData.append('model', model);
formData.append('seconds', seconds.toString());
formData.append('size', size);

const response = await fetch('https://api.openai.com/v1/videos', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    // DO NOT set Content-Type - FormData sets it automatically
  },
  body: formData,
});
```

---

## API Overview

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/videos` | POST | Create a video (requires multipart/form-data) |
| `/v1/videos/{id}` | GET | Get video status |
| `/v1/videos/{id}/content` | GET | Download video file |
| `/v1/videos` | GET | List all videos |
| `/v1/videos/{id}` | DELETE | Delete a video |

### Request Format for Video Creation

```
POST https://api.openai.com/v1/videos
Content-Type: multipart/form-data  (auto-set by FormData)
Authorization: Bearer $OPENAI_API_KEY

Form Fields:
- prompt: string (required) - Text description of the video
- model: string - "sora-2" (fast) or "sora-2-pro" (quality)
- seconds: string - "4", "8", or "12"
- size: string - "1280x720", "720x1280", "1792x1024", "1024x1792"
```

### Response Format

```json
{
  "id": "video_abc123...",
  "object": "video",
  "created_at": 1767817214,
  "status": "queued",
  "model": "sora-2",
  "prompt": "A fashion model walking...",
  "seconds": "4",
  "size": "1280x720"
}
```

### Status Values

- `queued` - Job is waiting to start
- `in_progress` - Video is being generated
- `completed` - Video is ready to download
- `failed` - Generation failed (check error field)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        CLIENT (Browser)                          │
├──────────────────────────────────────────────────────────────────┤
│  components/VisualizeTab.tsx                                     │
│  - Validates prerequisites (outfit, weather, reference)         │
│  - Orchestrates generation flow                                  │
│                           │                                      │
│  components/VideoPlayerModal.tsx                                 │
│  - Displays video with playback controls                        │
│  - Handles download                                              │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                     SERVER (Vercel)                              │
├──────────────────────────────────────────────────────────────────┤
│  app/actions/openai-video-actions.ts                            │
│  - Server-side prompt assembly                                   │
│  - Enforces outfit and reference validation                     │
│  - Applies identity + style constraints                         │
│                           │                                      │
│  services/videoApiClient.ts                                      │
│  - Manages API calls to OpenAI                                  │
│  - Handles retries and polling                                  │
│  - Returns base64 data URL on completion                        │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                     OpenAI Sora API                              │
│  POST /v1/videos → GET /v1/videos/{id} → GET /v1/videos/{id}/content │
└──────────────────────────────────────────────────────────────────┘
```

---

## Server Actions Implementation

### `app/actions/openai-video-actions.ts`

```typescript
'use server';

import { createVideoJob, pollVideoStatus, getVideoContent } from '@/services/videoApiClient';

interface VideoGenerationRequest {
  prompt: string;
  identityBible?: {
    subject: string;
    appearance: string;
    outfit: {
      top: string;
      bottom: string;
      outerwear?: string;
      footwear: string;
    };
  };
  sceneSpec?: {
    location: string;
    weather: string;
    cameraDirection: string;
  };
  model?: 'sora-2' | 'sora-2-pro';
  duration?: 4 | 8 | 12;
  size?: '1280x720' | '720x1280' | '1792x1024' | '1024x1792';
}

interface VideoGenerationResult {
  success: boolean;
  videoUrl?: string;  // base64 data URL
  videoId?: string;
  error?: string;
}

export async function generateVideo(
  request: VideoGenerationRequest
): Promise<VideoGenerationResult> {
  try {
    // Validate required fields
    if (!request.prompt) {
      return { success: false, error: 'Prompt is required' };
    }

    // Assemble enhanced prompt with identity and style constraints
    const enhancedPrompt = assemblePrompt(request);

    // Create video job
    const job = await createVideoJob({
      prompt: enhancedPrompt,
      model: request.model || 'sora-2',
      seconds: request.duration || 4,
      size: request.size || '1280x720',
    });

    if (!job.id) {
      return { success: false, error: 'Failed to create video job' };
    }

    // Poll for completion
    const completedJob = await pollVideoStatus(job.id, {
      interval: 5000,
      timeout: 600000,
    });

    if (completedJob.status !== 'completed') {
      return {
        success: false,
        error: completedJob.error?.message || 'Video generation failed',
        videoId: job.id,
      };
    }

    // Get video content as base64
    const videoContent = await getVideoContent(job.id);

    return {
      success: true,
      videoUrl: videoContent,
      videoId: job.id,
    };
  } catch (error) {
    console.error('Video generation error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

function assemblePrompt(request: VideoGenerationRequest): string {
  const parts: string[] = [];

  // Add identity constraints
  if (request.identityBible) {
    const { subject, appearance, outfit } = request.identityBible;

    parts.push(`SUBJECT: ${subject}`);
    parts.push(`IDENTITY CONSISTENCY: ${appearance} must remain absolutely consistent throughout entire video.`);

    // Add outfit details
    const outfitParts = [
      `TOP: ${outfit.top}`,
      `BOTTOM: ${outfit.bottom}`,
      outfit.outerwear ? `OUTERWEAR: ${outfit.outerwear}` : null,
      `FOOTWEAR: ${outfit.footwear}`,
    ].filter(Boolean);

    parts.push(`EXACT OUTFIT (all pieces must stay visible):\n${outfitParts.join(' | ')}`);
    parts.push('FULL-BODY FRAMING: Keep shoes and hemline visible at all times. No cropping at ankles or waist.');
  }

  // Add scene specification
  if (request.sceneSpec) {
    const { location, weather, cameraDirection } = request.sceneSpec;
    parts.push(`LOCATION: ${location}`);
    parts.push(`WEATHER: ${weather}`);
    parts.push(`CAMERA: ${cameraDirection}`);
  }

  // Add main prompt
  parts.push(`MOTION: ${request.prompt}`);

  // Add cinematography constraints
  parts.push(`CINEMATOGRAPHY:
- Full-body portrait, sharp focus on garments
- Professional lighting with soft shadows
- Smooth camera tracking; avoid cutting off shoes or headroom
- Natural fabric movement, high-resolution quality`);

  return parts.join('\n\n');
}
```

---

## Video API Client Service

### `services/videoApiClient.ts`

```typescript
const OPENAI_API_URL = 'https://api.openai.com/v1';

interface CreateVideoParams {
  prompt: string;
  model: string;
  seconds: number;
  size: string;
}

interface VideoJob {
  id: string;
  status: 'queued' | 'in_progress' | 'completed' | 'failed';
  progress?: number;
  error?: { code: string; message: string };
}

interface PollOptions {
  interval?: number;
  timeout?: number;
}

/**
 * Create a new video generation job
 * CRITICAL: Must use FormData, not JSON
 */
export async function createVideoJob(params: CreateVideoParams): Promise<VideoJob> {
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    throw new Error('OPENAI_API_KEY environment variable is not set');
  }

  // CRITICAL: Use FormData for multipart/form-data
  const formData = new FormData();
  formData.append('prompt', params.prompt);
  formData.append('model', params.model);
  formData.append('seconds', params.seconds.toString());
  formData.append('size', params.size);

  const response = await fetch(`${OPENAI_API_URL}/videos`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      // DO NOT set Content-Type - FormData sets it automatically with boundary
    },
    body: formData,
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || `API error: ${response.status}`);
  }

  return response.json();
}

/**
 * Get the current status of a video job
 */
export async function getVideoStatus(videoId: string): Promise<VideoJob> {
  const apiKey = process.env.OPENAI_API_KEY;

  const response = await fetch(`${OPENAI_API_URL}/videos/${videoId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
    },
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || `API error: ${response.status}`);
  }

  return response.json();
}

/**
 * Poll for video completion with retry logic
 */
export async function pollVideoStatus(
  videoId: string,
  options: PollOptions = {}
): Promise<VideoJob> {
  const { interval = 5000, timeout = 600000 } = options;
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    const status = await getVideoStatus(videoId);

    if (status.status === 'completed' || status.status === 'failed') {
      return status;
    }

    // Wait before next poll
    await new Promise(resolve => setTimeout(resolve, interval));
  }

  throw new Error(`Timeout after ${timeout}ms waiting for video ${videoId}`);
}

/**
 * Download video content and return as base64 data URL
 */
export async function getVideoContent(videoId: string): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;

  const response = await fetch(`${OPENAI_API_URL}/videos/${videoId}/content`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to download video: ${response.status}`);
  }

  // Convert to base64 data URL
  const arrayBuffer = await response.arrayBuffer();
  const base64 = Buffer.from(arrayBuffer).toString('base64');
  return `data:video/mp4;base64,${base64}`;
}
```

---

## React Components

### `components/VisualizeTab.tsx`

```tsx
'use client';

import { useState } from 'react';
import { generateVideo } from '@/app/actions/openai-video-actions';
import { VideoPlayerModal } from './VideoPlayerModal';

interface VisualizeTabProps {
  outfit: {
    top: string;
    bottom: string;
    outerwear?: string;
    footwear: string;
  };
  weather: string;
  referenceImage?: string;
}

export function VisualizeTab({ outfit, weather, referenceImage }: VisualizeTabProps) {
  const [isGenerating, setIsGenerating] = useState(false);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Validate prerequisites
  const canGenerate = outfit.top && outfit.bottom && outfit.footwear;

  const handleGenerate = async () => {
    if (!canGenerate) {
      setError('Please complete the outfit selection (top, bottom, and footwear required)');
      return;
    }

    setIsGenerating(true);
    setError(null);

    try {
      const result = await generateVideo({
        prompt: 'Model walking confidently with natural graceful movement',
        identityBible: {
          subject: 'fashion model',
          appearance: 'Subject appearance',
          outfit,
        },
        sceneSpec: {
          location: 'Fashion runway',
          weather,
          cameraDirection: 'Smooth tracking shot following the model',
        },
        model: 'sora-2-pro',
        duration: 8,
        size: '720x1280',  // Portrait for fashion
      });

      if (result.success && result.videoUrl) {
        setVideoUrl(result.videoUrl);
      } else {
        setError(result.error || 'Failed to generate video');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <div className="p-6">
      <h2 className="text-xl font-bold mb-4">Visualize Outfit</h2>

      {/* Outfit summary */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <h3 className="font-medium mb-2">Current Outfit</h3>
        <ul className="text-sm space-y-1">
          <li>Top: {outfit.top || '(not selected)'}</li>
          <li>Bottom: {outfit.bottom || '(not selected)'}</li>
          {outfit.outerwear && <li>Outerwear: {outfit.outerwear}</li>}
          <li>Footwear: {outfit.footwear || '(not selected)'}</li>
        </ul>
      </div>

      {/* Generate button */}
      <button
        onClick={handleGenerate}
        disabled={!canGenerate || isGenerating}
        className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isGenerating ? 'Generating Video...' : 'Generate Fashion Video'}
      </button>

      {!canGenerate && (
        <p className="mt-2 text-sm text-amber-600">
          ⚠️ Please select top, bottom, and footwear to generate video
        </p>
      )}

      {/* Error display */}
      {error && (
        <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      {/* Video player modal */}
      {videoUrl && (
        <VideoPlayerModal
          videoUrl={videoUrl}
          onClose={() => setVideoUrl(null)}
        />
      )}
    </div>
  );
}
```

### `components/VideoPlayerModal.tsx`

```tsx
'use client';

import { useRef } from 'react';

interface VideoPlayerModalProps {
  videoUrl: string;
  onClose: () => void;
}

export function VideoPlayerModal({ videoUrl, onClose }: VideoPlayerModalProps) {
  const videoRef = useRef<HTMLVideoElement>(null);

  const handleDownload = () => {
    const link = document.createElement('a');
    link.href = videoUrl;
    link.download = `fashion-video-${Date.now()}.mp4`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-4 max-w-2xl w-full mx-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-bold">Generated Video</h3>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700"
          >
            ✕
          </button>
        </div>

        <video
          ref={videoRef}
          src={videoUrl}
          controls
          autoPlay
          loop
          className="w-full rounded-lg"
        />

        <div className="mt-4 flex gap-2">
          <button
            onClick={handleDownload}
            className="flex-1 py-2 bg-green-600 text-white rounded hover:bg-green-700"
          >
            Download Video
          </button>
          <button
            onClick={onClose}
            className="flex-1 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
```

---

## Prompt Structure

The system uses a **locked two-layer prompt approach**:

### Layer 1: Identity + Style Bible (Stable)

```
SUBJECT: [subject type, e.g., "male model in their 26-35"]
IDENTITY CONSISTENCY: Subject appearance must remain absolutely consistent throughout entire video.

EXACT OUTFIT (all pieces must stay visible):
TOP: [top description] | BOTTOM: [bottom description] | OUTERWEAR: [if any] | FOOTWEAR: [footwear]

FULL-BODY FRAMING: Keep shoes and hemline visible at all times. No cropping at ankles or waist.
```

### Layer 2: Scene Specs (Per-request)

```
LOCATION: [location description]
WEATHER: [weather conditions]
CAMERA: [camera direction/movement]
MOTION: [the actual action/movement prompt]

CINEMATOGRAPHY:
- Full-body portrait, sharp focus on garments
- Professional lighting with soft shadows
- Smooth camera tracking
- Natural fabric movement
```

---

## Important Limitations

### 1. Reference Images with People Are BLOCKED

The Sora API **blocks ALL reference images containing people**:
- ❌ Real photos of people
- ❌ AI-generated images of people (DALL-E, Midjourney, etc.)
- ❌ Illustrations with human figures

**Solution:** Use **text-to-video only** for fashion/people videos. Do not use `input_reference` parameter.

### 2. Vercel Function Timeouts

| Plan | Timeout |
|------|---------|
| Hobby | 10 seconds |
| Pro | 60 seconds |
| Enterprise | 900 seconds |

Video generation takes 1-5 minutes. Solutions:

**Option A: Client-side polling (recommended)**
```typescript
// Server action returns job ID immediately
const { videoId } = await startVideoGeneration(params);

// Client polls for completion
await pollUntilComplete(videoId);
```

**Option B: Vercel Pro with streaming**
```typescript
// Use streaming to keep connection alive
export async function POST(request: Request) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      // Send heartbeat while processing
      const heartbeat = setInterval(() => {
        controller.enqueue(encoder.encode('.\n'));
      }, 10000);

      // Generate video...
      clearInterval(heartbeat);
    }
  });

  return new Response(stream);
}
```

### 3. Environment Variables

```bash
# .env.local
OPENAI_API_KEY=sk-your-api-key-here
```

Vercel Dashboard: Project → Settings → Environment Variables

---

## Debugging Checklist

### 405 Error Checklist

| Check | Fix |
|-------|-----|
| Using JSON body? | Switch to FormData |
| Setting Content-Type manually? | Remove it, let FormData set it |
| Calling from browser? | Move to server action/API route |
| Wrong HTTP method? | Use POST for create, GET for status |

### Quick Test

```bash
# Test from command line first
curl -X POST "https://api.openai.com/v1/videos" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=sora-2" \
  -F "prompt=A golden retriever running through a meadow" \
  -F "seconds=4" \
  -F "size=1280x720"
```

If this works but your code doesn't, the issue is in how you're forming the request.

---

## Integration Checklist

- [ ] Environment variable `OPENAI_API_KEY` is set
- [ ] Using FormData (not JSON) for video creation
- [ ] NOT setting Content-Type header manually
- [ ] Input validation blocks incomplete requests
- [ ] Prompts follow the locked schema (Identity + Scene)
- [ ] API flow includes proper timeout/retry handling
- [ ] No reference images with people (text-to-video only)
- [ ] Client-side polling for long-running generation
