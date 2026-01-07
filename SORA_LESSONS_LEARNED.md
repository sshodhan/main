# Sora API Integration - Lessons Learned

This document captures key learnings from testing the OpenAI Sora video generation API, specifically for the Aura Stylist fashion video use case.

---

## Critical Discovery: The 405 Error Fix

### Root Cause
The Sora `/v1/videos` endpoint **requires `multipart/form-data`**, NOT `application/json`.

### Wrong Approach (Causes 405)
```typescript
// ❌ THIS CAUSES 405 ERROR
const response = await fetch('https://api.openai.com/v1/videos', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',  // ❌ WRONG!
    'Authorization': `Bearer ${apiKey}`,
  },
  body: JSON.stringify({
    prompt: 'A fashion model walking...',
    model: 'sora-2',
    seconds: 4,
    size: '1280x720'
  }),
});
```

### Correct Approach (Works)
```typescript
// ✅ THIS WORKS
const formData = new FormData();
formData.append('prompt', 'A fashion model walking...');
formData.append('model', 'sora-2');
formData.append('seconds', '4');  // Note: string, not number
formData.append('size', '1280x720');

const response = await fetch('https://api.openai.com/v1/videos', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    // DO NOT set Content-Type - FormData sets it automatically with boundary
  },
  body: formData,
});
```

### Key Points
1. **Use FormData**, not JSON.stringify()
2. **Do NOT set Content-Type header** - FormData sets it automatically with the correct boundary
3. All values must be **strings** when appending to FormData
4. This must run **server-side** (API route or server action), not in browser

---

## API Endpoints Reference

| Endpoint | Method | Content-Type | Purpose |
|----------|--------|--------------|---------|
| `/v1/videos` | POST | multipart/form-data | Create video |
| `/v1/videos/{id}` | GET | - | Check status |
| `/v1/videos/{id}/content` | GET | - | Download video |
| `/v1/videos` | GET | - | List videos |
| `/v1/videos/{id}` | DELETE | - | Delete video |

---

## Working Request Parameters

### Video Creation (POST /v1/videos)

| Parameter | Type | Values | Default |
|-----------|------|--------|---------|
| `prompt` | string | Required - text description | - |
| `model` | string | `sora-2`, `sora-2-pro` | `sora-2` |
| `seconds` | string | `"4"`, `"8"`, `"12"` | `"4"` |
| `size` | string | See below | `"720x1280"` |

### Available Sizes
- `1280x720` - Landscape 16:9
- `720x1280` - Portrait 9:16 (best for fashion)
- `1792x1024` - Wide landscape
- `1024x1792` - Tall portrait

---

## Response Handling

### Initial Response (queued)
```json
{
  "id": "video_695eb94741f88193b2e5990db8c5d98600a359248b3ac2d9",
  "object": "video",
  "created_at": 1767815495,
  "status": "queued",
  "model": "sora-2",
  "progress": 0,
  "prompt": "A fashion model walking...",
  "seconds": "4",
  "size": "1280x720"
}
```

### Status Values
- `queued` - Waiting to start
- `in_progress` - Generating (check `progress` field for %)
- `completed` - Ready to download
- `failed` - Check `error` field for details

### Polling Strategy
```typescript
async function pollUntilComplete(videoId: string): Promise<VideoStatus> {
  const POLL_INTERVAL = 10000;  // 10 seconds
  const TIMEOUT = 600000;       // 10 minutes
  const startTime = Date.now();

  while (Date.now() - startTime < TIMEOUT) {
    const status = await getVideoStatus(videoId);

    if (status.status === 'completed') return status;
    if (status.status === 'failed') throw new Error(status.error?.message);

    await new Promise(r => setTimeout(r, POLL_INTERVAL));
  }

  throw new Error('Timeout waiting for video');
}
```

---

## Major Limitation: No People in Reference Images

### Discovery
The Sora API **blocks ALL reference images containing people**, including:
- ❌ Real photos of people
- ❌ AI-generated images of people (DALL-E, Midjourney)
- ❌ Illustrations with human figures

### Error Message
```json
{
  "error": {
    "code": "moderation_blocked",
    "message": "Your request was blocked by our moderation system."
  }
}
```

### Solution for Fashion Videos
Use **text-to-video only** (no `input_reference` parameter):

```typescript
// ✅ Works - text only, no reference image
const formData = new FormData();
formData.append('prompt', `
  SUBJECT: male model in their late 20s
  OUTFIT: charcoal sweater, indigo jeans, navy parka, brown Chelsea boots
  MOTION: Walking confidently with natural graceful movement
  CINEMATOGRAPHY: Full-body portrait, 9:16 vertical, professional runway lighting
`);
formData.append('model', 'sora-2-pro');
formData.append('seconds', '8');
formData.append('size', '720x1280');

// No input_reference parameter!
```

---

## Prompt Structure for Fashion Videos

### Two-Layer Approach

**Layer 1: Identity + Style Bible (Stable)**
```
SUBJECT: [subject description, e.g., "male model in their 26-35"]
IDENTITY CONSISTENCY: Subject appearance must remain absolutely consistent throughout entire video.

EXACT OUTFIT (all pieces must stay visible):
TOP: [description] | BOTTOM: [description] | OUTERWEAR: [if any] | FOOTWEAR: [description]

FULL-BODY FRAMING: Keep shoes and hemline visible at all times. No cropping at ankles or waist.
```

**Layer 2: Scene Specs (Per-request)**
```
LOCATION: [location]
WEATHER: [conditions]
CAMERA: [direction/movement]
MOTION: [action description]

CINEMATOGRAPHY:
- Full-body portrait, sharp focus on garments
- Professional lighting with soft shadows
- Smooth camera tracking; avoid cutting off shoes or headroom
- Natural fabric movement, high-resolution quality
```

### Example Complete Prompt
```
SUBJECT: male model in their 26-35
IDENTITY CONSISTENCY: Subject appearance must remain absolutely consistent throughout entire video.

MOTION: Model walking confidently with natural graceful movement
MOVEMENT NOTES: Smooth forward walk with natural graceful stride and confident posture

EXACT OUTFIT (all four pieces must stay visible):
TOP: Heather charcoal gray merino-cotton crewneck sweater | BOTTOM: Dark wash indigo slim-straight denim jeans | OUTERWEAR: Navy blue water-repellent hooded parka | FOOTWEAR: Dark brown leather lug-sole Chelsea boots

FULL-BODY FRAMING: Keep shoes and hemline visible at all times. No cropping at ankles or waist.

CINEMATOGRAPHY:
- Full-body portrait, 9:16 vertical, sharp focus on garments
- Professional fashion runway lighting with soft shadows
- Smooth camera tracking; avoid cutting off shoes or headroom
- Natural fabric movement, high-resolution editorial quality
```

---

## Vercel Implementation Pattern

### File Structure
```
app/
├── actions/
│   └── openai-video-actions.ts    # Server actions
├── api/
│   └── sora/
│       ├── create/route.ts        # POST - create video
│       ├── status/[id]/route.ts   # GET - check status
│       └── download/[id]/route.ts # GET - download video
services/
└── videoApiClient.ts              # API client
components/
├── VisualizeTab.tsx               # UI orchestration
└── VideoPlayerModal.tsx           # Video playback
```

### Server Action Pattern
```typescript
// app/actions/openai-video-actions.ts
'use server';

export async function generateVideo(params: VideoParams) {
  // 1. Validate inputs
  if (!params.prompt) {
    return { success: false, error: 'Prompt required' };
  }

  // 2. Assemble enhanced prompt
  const enhancedPrompt = assemblePrompt(params);

  // 3. Create FormData (CRITICAL!)
  const formData = new FormData();
  formData.append('prompt', enhancedPrompt);
  formData.append('model', params.model || 'sora-2');
  formData.append('seconds', String(params.duration || 4));
  formData.append('size', params.size || '720x1280');

  // 4. Call OpenAI API
  const response = await fetch('https://api.openai.com/v1/videos', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      // NO Content-Type header!
    },
    body: formData,
  });

  // 5. Handle response
  const data = await response.json();

  if (!response.ok) {
    return { success: false, error: data.error?.message };
  }

  return { success: true, videoId: data.id };
}
```

### Video Download (Base64 Data URL)
```typescript
export async function getVideoContent(videoId: string): Promise<string> {
  const response = await fetch(
    `https://api.openai.com/v1/videos/${videoId}/content`,
    {
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      },
    }
  );

  const arrayBuffer = await response.arrayBuffer();
  const base64 = Buffer.from(arrayBuffer).toString('base64');
  return `data:video/mp4;base64,${base64}`;
}
```

---

## Vercel Timeout Handling

### The Problem
- Video generation takes 1-5 minutes
- Vercel Hobby: 10s timeout
- Vercel Pro: 60s timeout

### Solution: Client-Side Polling

```typescript
// Server action - returns immediately with job ID
export async function startVideoGeneration(params) {
  const formData = new FormData();
  // ... append params

  const response = await fetch('https://api.openai.com/v1/videos', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
    body: formData,
  });

  const data = await response.json();
  return { videoId: data.id };  // Return immediately
}

// Client component - polls for completion
const { videoId } = await startVideoGeneration(params);

// Poll from client (avoids server timeout)
while (true) {
  const status = await checkVideoStatus(videoId);
  if (status.status === 'completed') break;
  if (status.status === 'failed') throw new Error(status.error);
  await new Promise(r => setTimeout(r, 10000));
}

// Download when ready
const videoUrl = await downloadVideo(videoId);
```

---

## Testing Checklist

### Before Deploying
- [ ] Test with curl first to verify API key works
- [ ] Confirm using FormData, not JSON
- [ ] Confirm NOT setting Content-Type header
- [ ] Verify environment variable is set in Vercel
- [ ] Test with simple prompt (no people reference)
- [ ] Implement client-side polling for status

### curl Test Command
```bash
export OPENAI_API_KEY="your-key"

curl -X POST "https://api.openai.com/v1/videos" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=sora-2" \
  -F "prompt=A golden retriever running through a sunny meadow" \
  -F "seconds=4" \
  -F "size=1280x720"
```

If curl works but your code doesn't, the issue is in how you're forming the request.

---

## Quick Reference: Working videoApiClient.ts

```typescript
// services/videoApiClient.ts

const API_URL = 'https://api.openai.com/v1';

interface CreateVideoParams {
  prompt: string;
  model?: 'sora-2' | 'sora-2-pro';
  seconds?: 4 | 8 | 12;
  size?: string;
}

export async function createVideo(params: CreateVideoParams) {
  const formData = new FormData();
  formData.append('prompt', params.prompt);
  formData.append('model', params.model || 'sora-2');
  formData.append('seconds', String(params.seconds || 4));
  formData.append('size', params.size || '720x1280');

  const response = await fetch(`${API_URL}/videos`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: formData,
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error?.message || `HTTP ${response.status}`);
  }

  return response.json();
}

export async function getVideoStatus(videoId: string) {
  const response = await fetch(`${API_URL}/videos/${videoId}`, {
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
  });

  return response.json();
}

export async function downloadVideo(videoId: string): Promise<string> {
  const response = await fetch(`${API_URL}/videos/${videoId}/content`, {
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
    },
  });

  const buffer = await response.arrayBuffer();
  const base64 = Buffer.from(buffer).toString('base64');
  return `data:video/mp4;base64,${base64}`;
}
```

---

## Summary: Key Takeaways

1. **405 Error = Wrong Content-Type** → Use FormData, not JSON
2. **No reference images with people** → Text-to-video only for fashion
3. **Vercel timeouts** → Use client-side polling
4. **Don't set Content-Type header** → Let FormData handle it
5. **All FormData values are strings** → Use String() for numbers
