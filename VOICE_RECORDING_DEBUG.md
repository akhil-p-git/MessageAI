# 🎤 Voice Recording Debug Guide

## 🐛 ISSUE: Voice messages send but have 0:00 duration (no audio recorded)

**Symptoms:**
- Voice message UI appears ✅
- File uploads to Firebase ✅
- But duration shows 0:00 ❌
- No actual audio content ❌

---

## ✅ FIXES APPLIED

### **1. Changed Audio Session Mode**

**Before:**
```swift
try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
```

**After:**
```swift
try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
```

**Why:**
- `.voiceChat` mode is optimized for voice recording
- `.allowBluetooth` enables Bluetooth microphones
- `.notifyOthersOnDeactivation` properly handles audio session lifecycle

---

### **2. Added Audio Metering**

**New feature:**
```swift
audioRecorder?.isMeteringEnabled = true
recorder.updateMeters()
let avgPower = recorder.averagePower(forChannel: 0)
```

**Why:**
- Monitors actual audio levels during recording
- Logs every second to verify microphone is capturing audio
- Helps diagnose if microphone is working

---

### **3. Enhanced Logging**

**Now logs:**
- Audio session category and mode
- Input availability status
- Recorder preparation status
- Recording status (isRecording)
- Audio levels every second (in dB)
- Detailed error codes

---

## 🧪 TESTING INSTRUCTIONS

### **Test 1: Check Console Logs**

**When you tap the microphone button, you should see:**

```
🎤 AudioRecorderService: Starting recording...
✅ Microphone permission granted
   Recording to: /var/.../ABC123.m4a
   Audio session configured:
      Category: AVAudioSessionCategoryPlayAndRecord
      Mode: AVAudioSessionModeVoiceChat
      Input available: true
   ✅ Recorder prepared successfully
✅ Recording started successfully!
   Recorder is recording: true
   🎙️ Recording... 1.0s (level: -30.5 dB)
   🎙️ Recording... 2.0s (level: -28.3 dB)
   🎙️ Recording... 3.0s (level: -31.2 dB)
```

**Key things to check:**
1. ✅ `Input available: true` - Microphone is accessible
2. ✅ `Recorder prepared successfully` - Recorder initialized
3. ✅ `Recorder is recording: true` - Recording is active
4. ✅ Audio levels are NOT -160 dB (that means silence/no input)

---

### **Test 2: Check Audio Levels**

**Good audio levels:**
- Speaking normally: -30 to -40 dB
- Speaking loudly: -20 to -30 dB
- Quiet room: -50 to -60 dB

**Bad audio levels:**
- -160 dB = No audio input (microphone not working)
- 0 dB = Clipping (too loud)

---

### **Test 3: Record and Check File**

**Steps:**
1. Tap microphone button
2. **Speak into the microphone** (say "Testing 1, 2, 3")
3. Watch console for audio levels
4. Tap send after 3-5 seconds

**Expected console output:**
```
🛑 AudioRecorderService: Stopping recording...
✅ Recording stopped successfully!
   File: ABC123.m4a
   Size: 45678 bytes  ← Should be > 0
   Duration: 3.5s     ← Should match recording time
```

**If file size is 0 or very small (<1000 bytes):**
- Microphone is not capturing audio
- Check permissions
- Check if another app is using the microphone

---

## 🔍 COMMON ISSUES & SOLUTIONS

### **Issue 1: "Input available: false"**

**Cause:** No microphone detected

**Solutions:**
1. Check if another app is using the microphone
2. Restart the device
3. Check Settings → Privacy → Microphone → MessageAI is enabled
4. Try unplugging headphones (if connected)

---

### **Issue 2: Audio levels always -160 dB**

**Cause:** Microphone not capturing audio

**Solutions:**
1. Make sure you're **speaking into the microphone** during recording
2. Check microphone permissions in Settings
3. Try recording with Voice Memos app to verify microphone works
4. Check if microphone is blocked/covered

---

### **Issue 3: "Recorder prepared: false"**

**Cause:** Recorder initialization failed

**Solutions:**
1. Check the error message in console
2. Verify file path is writable
3. Check audio session configuration
4. Try restarting the app

---

### **Issue 4: File size is 0 bytes**

**Cause:** No audio was recorded

**Solutions:**
1. Verify audio levels are showing in console (not -160 dB)
2. Make sure recording duration is > 1 second
3. Check if `recorder.isRecording` is true
4. Verify microphone permission is granted

---

## 📱 DEVICE-SPECIFIC CHECKS

### **Check 1: Microphone Hardware**

**Test with Voice Memos app:**
1. Open Voice Memos (built-in iOS app)
2. Record a voice memo
3. Play it back
4. **If Voice Memos works:** Problem is in our app
5. **If Voice Memos doesn't work:** Hardware issue

---

### **Check 2: Permissions**

**Settings → Privacy & Security → Microphone:**
- MessageAI should be listed
- Toggle should be ON (green)
- If not listed, delete and reinstall app

---

### **Check 3: Other Apps**

**Close other apps that might use microphone:**
- Phone calls
- FaceTime
- Voice Memos
- Other messaging apps
- Music/podcast apps

---

## 🎯 EXPECTED BEHAVIOR AFTER FIX

### **Scenario A: Normal Recording**

```
User taps microphone
    ↓
Permission granted
    ↓
Audio session configured with .voiceChat mode
    ↓
Recorder starts
    ↓
User speaks: "Testing 1, 2, 3"
    ↓
Console shows: 🎙️ Recording... 1.0s (level: -35 dB)
    ↓
User taps send
    ↓
File size: 45,678 bytes (not 0!)
    ↓
Duration: 3.5s (not 0:00!)
    ↓
✅ Voice message with actual audio!
```

---

### **Scenario B: Silent Recording (What We Want to Avoid)**

```
User taps microphone
    ↓
Permission granted
    ↓
Recorder starts
    ↓
User doesn't speak (or microphone not working)
    ↓
Console shows: 🎙️ Recording... 1.0s (level: -160 dB)  ← BAD!
    ↓
User taps send
    ↓
File size: 0 bytes or very small
    ↓
Duration: 0:00
    ↓
❌ Empty voice message
```

---

## 🚨 CRITICAL CONSOLE CHECKS

When testing, look for these in the console:

### **✅ GOOD SIGNS:**
```
✅ Microphone permission granted
   Input available: true
✅ Recorder prepared successfully
   Recorder is recording: true
🎙️ Recording... 1.0s (level: -35.2 dB)  ← Audio levels changing
   Size: 45678 bytes  ← File has content
   Duration: 3.5s     ← Matches recording time
```

### **❌ BAD SIGNS:**
```
❌ Microphone permission denied
   Input available: false
⚠️ Recorder prepare returned false
   Recorder is recording: false
🎙️ Recording... 1.0s (level: -160 dB)  ← No audio input
   Size: 0 bytes      ← Empty file
   Duration: 0.0s     ← No recording
```

---

## 🔧 WHAT CHANGED

### **AudioRecorderService.swift:**

1. **Audio session mode:** `.default` → `.voiceChat`
2. **Audio session options:** Added `.allowBluetooth`
3. **Audio session activation:** Added `.notifyOthersOnDeactivation`
4. **Metering enabled:** Now monitors audio levels
5. **Real-time logging:** Shows audio levels every second
6. **Better error handling:** Shows error codes and domains

---

## 📊 NEXT STEPS

### **Step 1: Test with Console Open**

Run the app with Xcode console visible and try recording. Look for:
- Is `Input available: true`?
- Is `Recorder is recording: true`?
- Are audio levels showing (not -160 dB)?

### **Step 2: Verify Microphone Works**

Test with Voice Memos app to confirm hardware is working.

### **Step 3: Check Permissions**

Go to Settings → Privacy → Microphone → Verify MessageAI is enabled.

### **Step 4: Record While Speaking**

Make sure you're actually speaking into the microphone during recording!

---

## 🎉 SUCCESS CRITERIA

After this fix, you should see:

| Check | Expected |
|-------|----------|
| Console shows audio levels | ✅ -30 to -40 dB (not -160) |
| File size after recording | ✅ > 10,000 bytes |
| Duration in UI | ✅ Shows actual time (not 0:00) |
| Playback works | ✅ Can hear your voice |
| Waveform animates | ✅ Shows audio activity |

---

**Status:** ✅ AUDIO SESSION FIXED  
**Last Updated:** October 24, 2025  
**Ready to Test:** YES  

---

**Try recording again and check the console logs!** 🎤

Look specifically for the audio level logs like:
```
🎙️ Recording... 1.0s (level: -35.2 dB)
```

If you see -160 dB, the microphone isn't capturing audio. If you see changing values like -30 to -40 dB, it's working! 🎉

