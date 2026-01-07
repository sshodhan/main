# Sora API HTTP 405 Error - Debugging Guide

**Error:** `Request to /videos failed with status 405`

## Root Cause Analysis

HTTP 405 "Method Not Allowed" indicates one of the following issues:

### 1. **API Access Not Enabled** (Most Likely)
- **Sora Video API is in PREVIEW** and requires special access
- Your OpenAI API key may not have Sora access enabled
- **Action Required:** Check your OpenAI account tier and Sora API access

### 2. **Account Tier Limitations**
- Sora API may only be available to Plus, Pro, or Enterprise tiers
- Free tier accounts won't have access to `/v1/videos` endpoint
- **Action Required:** Verify your OpenAI subscription level

### 3. **API Endpoint Availability**
- Sora API endpoints may not be fully rolled out yet
- Preview features can have limited availability
- **Action Required:** Check OpenAI status page and announcements

## Verification Steps

### Step 1: Test with CURL
Test the endpoint directly with curl to isolate the issue:

```bash
curl -X POST "https://api.openai.com/v1/videos" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F prompt="A cat walking on a beach" \
  -F model="sora-2" \
  -F size="1280x720" \
  -F seconds="8"
```

**Expected Results:**
- ✅ **200-202**: API access is working - issue is in your code
- ❌ **405**: Your API key doesn't have Sora access
- ❌ **401**: Authentication problem
- ❌ **403**: Permission denied - account tier issue

### Step 2: Check OpenAI Account Dashboard
1. Go to https://platform.openai.com/settings/organization/billing
2. Verify your subscription tier
3. Check if Sora access is listed under available features
4. Review usage limits and quotas

### Step 3: Test with OpenAI SDK
Use the official OpenAI Python/Node.js SDK:

```javascript
import OpenAI from 'openai';
const openai = new OpenAI();

let video = await openai.videos.create({
  model: 'sora-2',
  prompt: "A test video",
});
console.log('Video generation started:', video);
```

If this fails with the same error, it confirms the issue is with API access, not your implementation.

## Current Implementation Status

### ✅ What's Working:
- FormData construction is correct
- Image conversion (data URL → File) works properly
- File objects have correct MIME types (image/png, image/jpeg)
- Reference photos are properly attached as `input_reference`
- Prompt building with identity and outfit locks

### ❌ What's Failing:
- OpenAI Sora API returns HTTP 405 on `POST /v1/videos`
- This blocks all video generation attempts

## Temporary Workaround

Until Sora API access is confirmed, you can:

1. **Continue using Gemini Veo** for video generation (already working)
2. **Request Sora API access** from OpenAI support
3. **Wait for general availability** of Sora API

## Next Steps

1. **Verify API Access:**
   - Run the curl test above with your `OPENAI_API_KEY`
   - Check the response code and message
   - Document the exact error response

2. **Contact OpenAI Support:**
   - If you have a paid account, open a support ticket
   - Ask specifically about "Sora Video API preview access"
   - Reference the `/v1/videos` endpoint documentation

3. **Monitor OpenAI Announcements:**
   - Watch https://platform.openai.com/docs/changelog
   - Check https://status.openai.com for service updates
   - Join OpenAI community forums for preview program updates

## Expected Timeline

- **Preview Access:** May require waitlist or specific account tier
- **General Availability:** TBD by OpenAI
- **Alternative:** Gemini Veo is production-ready and working now

## Debug Logs to Collect

If testing with curl still fails, collect:
```
1. Full curl command (with masked API key)
2. Complete response headers
3. Response body/error message
4. Your OpenAI account tier
5. API key permissions/scopes
```

Send these to OpenAI support for assistance.

---

**Last Updated:** 2026-01-07  
**Status:** Waiting for Sora API access confirmation
