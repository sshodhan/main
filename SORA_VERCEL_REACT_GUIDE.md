# Sora Video API - Vercel/React Implementation Guide

This guide explains how to implement OpenAI's Sora video generation API in a Vercel/Next.js application. It addresses common issues like the **405 Method Not Allowed** error.

## Table of Contents
1. [Understanding the 405 Error](#understanding-the-405-error)
2. [API Overview](#api-overview)
3. [Implementation Architecture](#implementation-architecture)
4. [API Route Examples](#api-route-examples)
5. [React Frontend Components](#react-frontend-components)
6. [Important Limitations](#important-limitations)

---

## Understanding the 405 Error

The 405 error typically occurs due to:

| Cause | Solution |
|-------|----------|
| Calling OpenAI API from browser | Use server-side API routes |
| Wrong HTTP method | Use POST for `/videos`, GET for status |
| Missing/wrong Content-Type | Use `multipart/form-data` for video creation |
| CORS blocking client requests | Proxy through your API routes |

**Key Rule:** Never call `api.openai.com` directly from the browser. Always proxy through your Vercel API routes.

---

## API Overview

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/videos` | POST | Create a video |
| `/v1/videos/{id}` | GET | Get video status |
| `/v1/videos/{id}/content` | GET | Download video file |
| `/v1/videos` | GET | List all videos |
| `/v1/videos/{id}` | DELETE | Delete a video |

### Request Format for Video Creation

```
POST https://api.openai.com/v1/videos
Content-Type: multipart/form-data
Authorization: Bearer $OPENAI_API_KEY

Form Fields:
- prompt: string (required) - Text description of the video
- model: string - "sora-2" (fast) or "sora-2-pro" (quality)
- seconds: number - 4, 8, or 12
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
  "prompt": "A golden retriever running...",
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

## Implementation Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  React Client   │────▶│  Vercel API     │────▶│  OpenAI API     │
│  (Browser)      │     │  Routes         │     │  (Sora)         │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │ fetch('/api/sora')    │ POST api.openai.com/v1/videos
        │                       │
        ▼                       ▼
   No CORS issues          Server-side auth
```

---

## API Route Examples

### 1. Create Video Route (`/api/sora/create/route.ts`)

```typescript
// app/api/sora/create/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { prompt, model = 'sora-2', duration = 4, size = '1280x720' } = body;

    if (!prompt) {
      return NextResponse.json(
        { error: 'Prompt is required' },
        { status: 400 }
      );
    }

    // Create FormData for multipart request
    const formData = new FormData();
    formData.append('prompt', prompt);
    formData.append('model', model);
    formData.append('seconds', duration.toString());
    formData.append('size', size);

    const response = await fetch('https://api.openai.com/v1/videos', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        // DO NOT set Content-Type - fetch sets it automatically for FormData
      },
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { error: data.error?.message || 'Failed to create video' },
        { status: response.status }
      );
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Sora API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### 2. Check Status Route (`/api/sora/status/[videoId]/route.ts`)

```typescript
// app/api/sora/status/[videoId]/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { videoId: string } }
) {
  try {
    const { videoId } = params;

    const response = await fetch(
      `https://api.openai.com/v1/videos/${videoId}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        },
      }
    );

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(
        { error: data.error?.message || 'Failed to get status' },
        { status: response.status }
      );
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Sora status error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

### 3. Download Video Route (`/api/sora/download/[videoId]/route.ts`)

```typescript
// app/api/sora/download/[videoId]/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { videoId: string } }
) {
  try {
    const { videoId } = params;

    // First check if video is completed
    const statusResponse = await fetch(
      `https://api.openai.com/v1/videos/${videoId}`,
      {
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        },
      }
    );

    const statusData = await statusResponse.json();

    if (statusData.status !== 'completed') {
      return NextResponse.json(
        { error: `Video not ready. Status: ${statusData.status}` },
        { status: 400 }
      );
    }

    // Download the video content
    const videoResponse = await fetch(
      `https://api.openai.com/v1/videos/${videoId}/content`,
      {
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        },
      }
    );

    if (!videoResponse.ok) {
      return NextResponse.json(
        { error: 'Failed to download video' },
        { status: videoResponse.status }
      );
    }

    // Stream the video back to the client
    const videoBuffer = await videoResponse.arrayBuffer();

    return new NextResponse(videoBuffer, {
      headers: {
        'Content-Type': 'video/mp4',
        'Content-Disposition': `attachment; filename="${videoId}.mp4"`,
      },
    });
  } catch (error) {
    console.error('Sora download error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
```

---

## React Frontend Components

### Video Generator Hook (`useSoraVideo.ts`)

```typescript
// hooks/useSoraVideo.ts
import { useState, useCallback } from 'react';

interface VideoOptions {
  prompt: string;
  model?: 'sora-2' | 'sora-2-pro';
  duration?: 4 | 8 | 12;
  size?: '1280x720' | '720x1280' | '1792x1024' | '1024x1792';
}

interface VideoStatus {
  id: string;
  status: 'queued' | 'in_progress' | 'completed' | 'failed';
  progress?: number;
  error?: { message: string };
}

export function useSoraVideo() {
  const [isLoading, setIsLoading] = useState(false);
  const [videoId, setVideoId] = useState<string | null>(null);
  const [status, setStatus] = useState<VideoStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  const createVideo = useCallback(async (options: VideoOptions) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/sora/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(options),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to create video');
      }

      setVideoId(data.id);
      setStatus(data);
      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const checkStatus = useCallback(async (id?: string) => {
    const checkId = id || videoId;
    if (!checkId) return null;

    try {
      const response = await fetch(`/api/sora/status/${checkId}`);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to check status');
      }

      setStatus(data);
      return data;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(message);
      return null;
    }
  }, [videoId]);

  const pollUntilComplete = useCallback(async (
    id?: string,
    interval = 5000,
    timeout = 600000
  ): Promise<VideoStatus | null> => {
    const checkId = id || videoId;
    if (!checkId) return null;

    const startTime = Date.now();

    return new Promise((resolve, reject) => {
      const poll = async () => {
        if (Date.now() - startTime > timeout) {
          reject(new Error('Timeout waiting for video'));
          return;
        }

        const status = await checkStatus(checkId);

        if (status?.status === 'completed') {
          resolve(status);
        } else if (status?.status === 'failed') {
          reject(new Error(status.error?.message || 'Video generation failed'));
        } else {
          setTimeout(poll, interval);
        }
      };

      poll();
    });
  }, [videoId, checkStatus]);

  const getDownloadUrl = useCallback((id?: string) => {
    const downloadId = id || videoId;
    return downloadId ? `/api/sora/download/${downloadId}` : null;
  }, [videoId]);

  return {
    createVideo,
    checkStatus,
    pollUntilComplete,
    getDownloadUrl,
    videoId,
    status,
    isLoading,
    error,
  };
}
```

### Video Generator Component (`SoraVideoGenerator.tsx`)

```tsx
// components/SoraVideoGenerator.tsx
'use client';

import { useState } from 'react';
import { useSoraVideo } from '@/hooks/useSoraVideo';

export function SoraVideoGenerator() {
  const [prompt, setPrompt] = useState('');
  const [model, setModel] = useState<'sora-2' | 'sora-2-pro'>('sora-2');
  const [duration, setDuration] = useState<4 | 8 | 12>(4);
  const [size, setSize] = useState<string>('1280x720');

  const {
    createVideo,
    pollUntilComplete,
    getDownloadUrl,
    status,
    isLoading,
    error,
  } = useSoraVideo();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const video = await createVideo({
        prompt,
        model,
        duration,
        size: size as any,
      });

      // Poll until complete
      await pollUntilComplete(video.id);
    } catch (err) {
      console.error('Video generation failed:', err);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-6">Sora Video Generator</h1>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">
            Prompt
          </label>
          <textarea
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            className="w-full p-3 border rounded-lg"
            rows={4}
            placeholder="Describe the video you want to create..."
            required
          />
        </div>

        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium mb-1">Model</label>
            <select
              value={model}
              onChange={(e) => setModel(e.target.value as any)}
              className="w-full p-2 border rounded"
            >
              <option value="sora-2">Sora 2 (Fast)</option>
              <option value="sora-2-pro">Sora 2 Pro (Quality)</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Duration</label>
            <select
              value={duration}
              onChange={(e) => setDuration(Number(e.target.value) as any)}
              className="w-full p-2 border rounded"
            >
              <option value={4}>4 seconds</option>
              <option value={8}>8 seconds</option>
              <option value={12}>12 seconds</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Size</label>
            <select
              value={size}
              onChange={(e) => setSize(e.target.value)}
              className="w-full p-2 border rounded"
            >
              <option value="1280x720">1280x720 (Landscape)</option>
              <option value="720x1280">720x1280 (Portrait)</option>
              <option value="1792x1024">1792x1024 (Wide)</option>
              <option value="1024x1792">1024x1792 (Tall)</option>
            </select>
          </div>
        </div>

        <button
          type="submit"
          disabled={isLoading || !prompt}
          className="w-full py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
        >
          {isLoading ? 'Generating...' : 'Generate Video'}
        </button>
      </form>

      {error && (
        <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-lg">
          {error}
        </div>
      )}

      {status && (
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-medium mb-2">Status: {status.status}</h3>
          {status.progress !== undefined && (
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className="bg-blue-600 h-2 rounded-full transition-all"
                style={{ width: `${status.progress}%` }}
              />
            </div>
          )}

          {status.status === 'completed' && (
            <a
              href={getDownloadUrl()!}
              download
              className="mt-4 inline-block px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
            >
              Download Video
            </a>
          )}
        </div>
      )}
    </div>
  );
}
```

---

## Important Limitations

### 1. Reference Images with People Are Blocked

The Sora API **blocks all reference images containing people**. This includes:
- Real photos of people
- AI-generated images of people (including DALL-E generated)
- Illustrations with human figures

**Workaround:** Use text-to-video only for videos with people:
```typescript
// This works for people:
createVideo({
  prompt: "A fashion model walking on a runway, professional lighting",
  model: "sora-2-pro",
  duration: 8
});

// This does NOT work with people images:
// createVideoFromImage({ image: personPhoto, prompt: "..." }) // ❌ Blocked
```

### 2. Vercel Function Timeout

Vercel has function timeout limits:
- Hobby: 10 seconds
- Pro: 60 seconds
- Enterprise: 900 seconds

Video generation takes 1-5 minutes, so you **cannot** wait for completion in a single request.

**Solution:** Use polling from the client:
```typescript
// 1. Create video (fast, returns immediately)
const video = await createVideo({ prompt: "..." });

// 2. Poll from client (avoids server timeout)
await pollUntilComplete(video.id);
```

### 3. Environment Variables

Add to your `.env.local`:
```
OPENAI_API_KEY=sk-your-api-key-here
```

Add to Vercel project settings:
1. Go to Project → Settings → Environment Variables
2. Add `OPENAI_API_KEY` with your API key

---

## Debugging the 405 Error

If you're still getting 405 errors, check:

1. **Are you calling OpenAI directly from browser?**
   ```typescript
   // ❌ WRONG - from React component
   fetch('https://api.openai.com/v1/videos', { ... })

   // ✅ CORRECT - through your API route
   fetch('/api/sora/create', { ... })
   ```

2. **Is your API route using the right method?**
   ```typescript
   // ❌ WRONG
   export async function GET(request) { ... }

   // ✅ CORRECT for creating videos
   export async function POST(request) { ... }
   ```

3. **Are you setting Content-Type correctly?**
   ```typescript
   // ❌ WRONG - don't set Content-Type for FormData
   headers: {
     'Content-Type': 'multipart/form-data',  // Don't do this!
     'Authorization': `Bearer ${key}`,
   }

   // ✅ CORRECT - let fetch set it automatically
   headers: {
     'Authorization': `Bearer ${key}`,
   },
   body: formData,  // FormData sets Content-Type automatically
   ```

4. **Is the route file in the correct location?**
   ```
   app/
   └── api/
       └── sora/
           ├── create/
           │   └── route.ts    ← POST /api/sora/create
           └── status/
               └── [videoId]/
                   └── route.ts ← GET /api/sora/status/{videoId}
   ```

---

## Quick Reference

### Working curl command (for testing):
```bash
curl -X POST "https://api.openai.com/v1/videos" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "model=sora-2" \
  -F "prompt=A golden retriever running through a meadow" \
  -F "seconds=4" \
  -F "size=1280x720"
```

### Equivalent API route:
```typescript
const formData = new FormData();
formData.append('model', 'sora-2');
formData.append('prompt', 'A golden retriever running through a meadow');
formData.append('seconds', '4');
formData.append('size', '1280x720');

await fetch('https://api.openai.com/v1/videos', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
  body: formData,
});
```
