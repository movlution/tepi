using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

namespace Tepi
{
    [ComImport, Guid("F294ACFC-3146-4483-A7BF-ADDCA7C260E2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioRenderClient
    {
        [PreserveSig] int GetBuffer(uint numFramesRequested, out IntPtr data);
        [PreserveSig] int ReleaseBuffer(uint numFramesWritten, uint flags);
    }

    // Polyphonic WASAPI shared-mode event-driven mixer + 44.1 kHz 16-bit PCM synthesizer
    partial class Island
    {
        const int ComboAudioRate = 44100;
        const int MixerMaxVoices = 24;
        const int MixerIdleShutdownMs = 2500;

        // WASAPI constants
        const int AUDCLNT_SHAREMODE_SHARED = 0;
        const int AUDCLNT_STREAMFLAGS_EVENTCALLBACK = 0x00040000;
        const int AUDCLNT_STREAMFLAGS_NOPERSIST = 0x00080000;
        const int AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY = 0x08000000;
        const int AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM = unchecked((int)0x80000000);
        const int AUDCLNT_E_DEVICE_INVALIDATED = unchecked((int)0x88890004);
        const int CLSCTX_ALL = 23;
        const int eRender = 0;
        const int eMultimedia = 1;
        static readonly Guid KSDATAFORMAT_SUBTYPE_PCM = new Guid("00000001-0000-0010-8000-00AA00389B71");
        static readonly Guid KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = new Guid("00000003-0000-0010-8000-00AA00389B71");

        // WinMM waveOut fallback constants
        const uint WAVE_MAPPER = unchecked((uint)-1);
        const uint CALLBACK_EVENT = 0x00050000;
        const uint WHDR_DONE = 0x00000001;
        const uint WHDR_PREPARED = 0x00000002;
        const int FallbackRate = 48000;
        const int FallbackFrames = 960; // 20 ms at 48 kHz
        const int FallbackBufBytes = FallbackFrames * 4; // 16-bit stereo
        const int FallbackBufCount = 4;

        [StructLayout(LayoutKind.Sequential)]
        struct WAVEFORMATEX
        {
            public ushort wFormatTag;
            public ushort nChannels;
            public uint nSamplesPerSec;
            public uint nAvgBytesPerSec;
            public ushort nBlockAlign;
            public ushort wBitsPerSample;
            public ushort cbSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct WAVEHDR
        {
            public IntPtr lpData;
            public uint dwBufferLength;
            public uint dwBytesRecorded;
            public IntPtr dwUser;
            public uint dwFlags;
            public uint dwLoops;
            public IntPtr lpNext;
            public IntPtr reserved;
        }

        [DllImport("ole32.dll")]
        static extern void CoTaskMemFree(IntPtr pv);

        [DllImport("avrt.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr AvSetMmThreadCharacteristicsW(string taskName, out uint taskIndex);

        [DllImport("avrt.dll")]
        static extern bool AvRevertMmThreadCharacteristics(IntPtr avrtHandle);

        [DllImport("winmm.dll")]
        static extern uint timeBeginPeriod(uint uPeriod);

        [DllImport("winmm.dll")]
        static extern uint timeEndPeriod(uint uPeriod);

        [DllImport("winmm.dll")]
        static extern int waveOutOpen(out IntPtr phwo, uint uDeviceID, ref WAVEFORMATEX pwfx, IntPtr dwCallback, IntPtr dwInstance, uint fdwOpen);

        [DllImport("winmm.dll")]
        static extern int waveOutPrepareHeader(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        static extern int waveOutUnprepareHeader(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        static extern int waveOutWrite(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        static extern int waveOutReset(IntPtr hwo);

        [DllImport("winmm.dll")]
        static extern int waveOutClose(IntPtr hwo);

        sealed class PinnedWav
        {
            public byte[] Data;
            public short[] Samples;
            public GCHandle Handle;
            public IntPtr Ptr;
        }

        struct AudioVoice
        {
            public short[] Samples;
            public int Pos;
            public double SrcPos;
            public float Gain;
            public bool Active;
        }

        static readonly int WaveHdrSize = Marshal.SizeOf(typeof(WAVEHDR));
        static readonly int WaveHdrFlagsOffset = Marshal.OffsetOf(typeof(WAVEHDR), "dwFlags").ToInt32();

        bool comboAudioReady;
        readonly List<PinnedWav> comboAudioAll = new List<PinnedWav>();
        PinnedWav[] comboArcadeBlips;
        PinnedWav[] comboThockVariants;
        PinnedWav[] comboClickVariants;
        PinnedWav[] comboPianoNotes;
        PinnedWav[] comboTierChimes;
        PinnedWav comboPbFanfareWav;
        PinnedWav comboCriticalWav;
        PinnedWav comboBrokenWav;
        PinnedWav comboShieldCrackWav;

        readonly object voiceLock = new object();
        readonly object mixerLifecycleLock = new object();
        readonly AudioVoice[] comboVoices = new AudioVoice[MixerMaxVoices];
        Thread mixerThread;
        ManualResetEvent mixerStopEvent;
        bool mixerStopping;
        bool mixerHasPlayed;
        int mixerLastVoiceTick;
        int mixerLastFailTick;
        bool mixerFailLogged;
        volatile int mixerUnderruns;
        public int ComboAudioUnderruns { get { return mixerUnderruns; } }

        void EnsureComboAudio()
        {
            if (comboAudioReady) return;
            comboAudioReady = true;

            // 50 ascending arcade blips (440 Hz -> 1240 Hz, ~36ms)
            comboArcadeBlips = new PinnedWav[50];
            for (int i = 0; i < 50; i++)
            {
                double t = i / 49.0;
                double freq = 440.0 + t * 800.0;
                comboArcadeBlips[i] = PinWav(SynthArcadeBlip(freq, 0.036));
            }

            // 6 organic mechanical thock variants (~48ms, damped 250-320 Hz body + woody PBT knock)
            comboThockVariants = new PinnedWav[6];
            for (int i = 0; i < 6; i++)
            {
                double baseFreq = 250.0 + i * 14.0;
                comboThockVariants[i] = PinWav(SynthThock(baseFreq, 0.048, i));
            }

            // 6 crisp tactile click variants (~30ms, clickbar impulse + subtle bottom-out body)
            comboClickVariants = new PinnedWav[6];
            for (int i = 0; i < 6; i++)
            {
                double resFreq = 1900.0 + i * 115.0;
                comboClickVariants[i] = PinWav(SynthClick(resFreq, 0.030, i));
            }

            // 11 consonant C-major pentatonic piano notes (G4-G6, ~240ms)
            double[] pianoFreqs = {
                392.00, 440.00, 523.25, 587.33, 659.25,
                783.99, 880.00, 1046.50, 1174.66, 1318.51,
                1567.98
            };
            comboPianoNotes = new PinnedWav[pianoFreqs.Length];
            for (int i = 0; i < pianoFreqs.Length; i++)
                comboPianoNotes[i] = PinWav(SynthPianoNote(pianoFreqs[i], 0.24, i));

            // Tier-up chimes (tiers 2..6 -> indices 0..4)
            comboTierChimes = new PinnedWav[5];
            double[] tierRoots = { 523.25, 587.33, 659.25, 783.99, 880.00 };
            for (int i = 0; i < 5; i++)
                comboTierChimes[i] = PinWav(SynthTierChime(tierRoots[i], 0.20 + i * 0.02));

            comboPbFanfareWav = PinWav(SynthPbFanfare());
            comboCriticalWav = PinWav(SynthCritical());
            comboBrokenWav = PinWav(SynthBroken());
            comboShieldCrackWav = PinWav(SynthShieldCrack());
        }

        PinnedWav PinWav(short[] samples)
        {
            byte[] wav = BuildWav(samples);
            var h = GCHandle.Alloc(wav, GCHandleType.Pinned);
            var pw = new PinnedWav { Data = wav, Samples = samples, Handle = h, Ptr = h.AddrOfPinnedObject() };
            comboAudioAll.Add(pw);
            return pw;
        }

        void ClearComboAudioVoices()
        {
            lock (voiceLock)
            {
                for (int i = 0; i < comboVoices.Length; i++)
                    comboVoices[i].Active = false;
                mixerHasPlayed = false;
            }
        }

        public void StopComboAudio()
        {
            Thread t;
            ManualResetEvent stopEv;
            lock (mixerLifecycleLock)
            {
                mixerStopping = true;
                stopEv = mixerStopEvent;
                t = mixerThread;
                mixerThread = null;
            }
            if (stopEv != null)
            {
                try { stopEv.Set(); } catch (Exception) { }
            }
            if (t != null && t.IsAlive)
            {
                try { t.Join(1000); } catch (Exception) { }
            }
            ClearComboAudioVoices();
            mixerUnderruns = 0;
            for (int i = 0; i < comboAudioAll.Count; i++)
            {
                if (comboAudioAll[i].Handle.IsAllocated)
                    comboAudioAll[i].Handle.Free();
            }
            comboAudioAll.Clear();
            comboAudioReady = false;
        }

        bool ComboAudioAllowed(bool test)
        {
            if (test) return true;
            return ComboSoundOn && !Quiet && !fullscreen && !PrompterOn;
        }

        void EnsureMixerStarted()
        {
            lock (mixerLifecycleLock)
            {
                if (IsDisposed) return;
                if (mixerThread != null && mixerThread.IsAlive) return;
                if (mixerLastFailTick != 0 && (uint)(Environment.TickCount - mixerLastFailTick) < 5000u) return;
                mixerStopping = false;
                mixerUnderruns = 0;
                var stopEv = new ManualResetEvent(false);
                mixerStopEvent = stopEv;
                var t = new Thread(delegate () { MixerLoop(stopEv); })
                {
                    IsBackground = true,
                    Name = "TepiComboAudio",
                    Priority = ThreadPriority.Highest
                };
                t.SetApartmentState(ApartmentState.MTA);
                mixerThread = t;
                t.Start();
            }
        }

        void PlayPinned(PinnedWav pw, float gain = 1.0f)
        {
            if (pw == null || pw.Samples == null || pw.Samples.Length == 0) return;
            EnsureMixerStarted();
            lock (mixerLifecycleLock)
            {
                if (mixerStopping) return;
            }
            lock (voiceLock)
            {
                int slot = -1;
                int bestPos = -1;
                int oldestSlot = 0;
                for (int i = 0; i < comboVoices.Length; i++)
                {
                    if (!comboVoices[i].Active) { slot = i; break; }
                    if (comboVoices[i].Pos > bestPos)
                    {
                        bestPos = comboVoices[i].Pos;
                        oldestSlot = i;
                    }
                }
                if (slot < 0) slot = oldestSlot;
                comboVoices[slot].Samples = pw.Samples;
                comboVoices[slot].Pos = 0;
                comboVoices[slot].SrcPos = 0.0;
                comboVoices[slot].Gain = gain;
                comboVoices[slot].Active = true;
                mixerLastVoiceTick = Environment.TickCount;
                mixerHasPlayed = true;
            }
        }

        static float SoftClip(float v)
        {
            if (v > 0.85f)
            {
                float over = v - 0.85f;
                return 0.85f + 0.14f * (over / (over + 0.14f));
            }
            if (v < -0.85f)
            {
                float over = -0.85f - v;
                return -0.85f - 0.14f * (over / (over + 0.14f));
            }
            return v;
        }

        bool HasActiveVoices()
        {
            lock (voiceLock)
            {
                for (int v = 0; v < comboVoices.Length; v++)
                {
                    if (comboVoices[v].Active) return true;
                }
                return false;
            }
        }

        bool ShouldKeepStreamAlive(bool anyVoiceActive)
        {
            if (anyVoiceActive) return true;
            if (ComboOn && ComboSoundOn && !Quiet && !fullscreen && !PrompterOn) return true;
            int lastTick;
            lock (voiceLock) { lastTick = mixerLastVoiceTick; }
            return (uint)(Environment.TickCount - lastTick) < (uint)MixerIdleShutdownMs;
        }

        // Mixes active 44.1 kHz voices into mono float32 at targetRate using linear resampling
        void MixFramesFloat(float[] monoBuf, int frameCount, int targetRate, out bool anyActive)
        {
            Array.Clear(monoBuf, 0, frameCount);
            anyActive = false;
            double step = (double)ComboAudioRate / targetRate;
            const float inv32768 = 1.0f / 32768.0f;

            lock (voiceLock)
            {
                for (int v = 0; v < comboVoices.Length; v++)
                {
                    if (!comboVoices[v].Active) continue;
                    short[] src = comboVoices[v].Samples;
                    int len = src.Length;
                    double p = comboVoices[v].SrcPos;
                    float gain = comboVoices[v].Gain * inv32768;

                    if (p >= len)
                    {
                        comboVoices[v].Active = false;
                        continue;
                    }

                    if (targetRate == ComboAudioRate)
                    {
                        int ip = (int)p;
                        int take = len - ip;
                        if (take > frameCount) take = frameCount;
                        for (int f = 0; f < take; f++)
                            monoBuf[f] += src[ip + f] * gain;
                        p += take;
                    }
                    else
                    {
                        for (int f = 0; f < frameCount; f++)
                        {
                            int idx = (int)p;
                            if (idx >= len) break;
                            double frac = p - idx;
                            float s0 = src[idx];
                            float s1 = (idx + 1 < len) ? src[idx + 1] : 0.0f;
                            monoBuf[f] += (float)(s0 + (s1 - s0) * frac) * gain;
                            p += step;
                        }
                    }

                    comboVoices[v].SrcPos = p;
                    comboVoices[v].Pos = (int)p;
                    if (p >= len) comboVoices[v].Active = false;
                    else anyActive = true;
                }
            }

            for (int f = 0; f < frameCount; f++)
                monoBuf[f] = SoftClip(monoBuf[f]);
        }

        static bool ParseMixFormat(IntPtr fmtPtr, out int channels, out int rate, out int bits, out bool isFloat)
        {
            channels = 0;
            rate = 0;
            bits = 0;
            isFloat = false;
            if (fmtPtr == IntPtr.Zero) return false;

            int tag = Marshal.ReadInt16(fmtPtr, 0) & 0xFFFF;
            channels = Marshal.ReadInt16(fmtPtr, 2) & 0xFFFF;
            rate = Marshal.ReadInt32(fmtPtr, 4);
            bits = Marshal.ReadInt16(fmtPtr, 14) & 0xFFFF;
            if (channels <= 0 || rate <= 0) return false;

            if (tag == 3 && bits == 32)
            {
                isFloat = true;
                return true;
            }
            if (tag == 1 && bits == 16)
            {
                isFloat = false;
                return true;
            }
            if (tag == 0xFFFE)
            {
                int cbSize = Marshal.ReadInt16(fmtPtr, 16) & 0xFFFF;
                if (cbSize >= 22)
                {
                    byte[] gBytes = new byte[16];
                    Marshal.Copy(IntPtr.Add(fmtPtr, 24), gBytes, 0, 16);
                    Guid sub = new Guid(gBytes);
                    if (sub == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT && bits == 32)
                    {
                        isFloat = true;
                        return true;
                    }
                    if (sub == KSDATAFORMAT_SUBTYPE_PCM && bits == 16)
                    {
                        isFloat = false;
                        return true;
                    }
                }
            }
            return false;
        }

        bool OpenWasapiDevice(
            AutoResetEvent audioEvent,
            out IAudioClient client,
            out IAudioRenderClient render,
            out uint bufferFrames,
            out int channels,
            out int rate,
            out bool isFloat,
            out double periodMs)
        {
            client = null;
            render = null;
            bufferFrames = 0;
            channels = 2;
            rate = 48000;
            isFloat = true;
            periodMs = 10.0;

            IMMDeviceEnumerator en = null;
            IMMDevice dev = null;
            IntPtr fmtPtr = IntPtr.Zero;
            IntPtr customFmtPtr = IntPtr.Zero;

            try
            {
                en = (IMMDeviceEnumerator)new MMDeviceEnumerator();
                int hr = en.GetDefaultAudioEndpoint(eRender, eMultimedia, out dev);
                if (hr != 0 || dev == null) return false;

                Guid iidClient = typeof(IAudioClient).GUID;
                object clientObj;
                hr = dev.Activate(ref iidClient, CLSCTX_ALL, IntPtr.Zero, out clientObj);
                if (hr != 0 || clientObj == null) return false;
                client = (IAudioClient)clientObj;

                hr = client.GetMixFormat(out fmtPtr);
                if (hr != 0 || fmtPtr == IntPtr.Zero)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                int bits;
                int flags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK | AUDCLNT_STREAMFLAGS_NOPERSIST;
                IntPtr initFmt = fmtPtr;
                if (!ParseMixFormat(fmtPtr, out channels, out rate, out bits, out isFloat))
                {
                    // Endpoint mix format is non-standard (e.g. 24-bit PCM): ask Windows SRC to convert from 48 kHz float32 stereo
                    channels = 2;
                    rate = 48000;
                    isFloat = true;
                    var wfx = new WAVEFORMATEX
                    {
                        wFormatTag = 3, // WAVE_FORMAT_IEEE_FLOAT
                        nChannels = 2,
                        nSamplesPerSec = 48000,
                        wBitsPerSample = 32,
                        nBlockAlign = 8,
                        nAvgBytesPerSec = 48000 * 8,
                        cbSize = 0
                    };
                    customFmtPtr = Marshal.AllocCoTaskMem(Marshal.SizeOf(typeof(WAVEFORMATEX)));
                    Marshal.StructureToPtr(wfx, customFmtPtr, false);
                    initFmt = customFmtPtr;
                    flags |= AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
                }

                hr = client.Initialize(AUDCLNT_SHAREMODE_SHARED, flags, 0, 0, initFmt, IntPtr.Zero);
                if (hr != 0)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                long defPeriod, minPeriod;
                if (client.GetDevicePeriod(out defPeriod, out minPeriod) == 0 && defPeriod > 0)
                    periodMs = defPeriod / 10000.0;

                hr = client.GetBufferSize(out bufferFrames);
                if (hr != 0 || bufferFrames == 0)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                hr = client.SetEventHandle(audioEvent.SafeWaitHandle.DangerousGetHandle());
                if (hr != 0)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                Guid iidRender = typeof(IAudioRenderClient).GUID;
                object renderObj;
                hr = client.GetService(ref iidRender, out renderObj);
                if (hr != 0 || renderObj == null)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }
                render = (IAudioRenderClient)renderObj;

                // Pre-fill entire initial buffer with clean 0.0f / 0 silence before Start()
                IntPtr dataPtr;
                hr = render.GetBuffer(bufferFrames, out dataPtr);
                if (hr != 0 || dataPtr == IntPtr.Zero)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }
                int sampleCount = (int)bufferFrames * channels;
                if (isFloat)
                {
                    var zeroF = new float[sampleCount];
                    Marshal.Copy(zeroF, 0, dataPtr, sampleCount);
                }
                else
                {
                    var zeroS = new short[sampleCount];
                    Marshal.Copy(zeroS, 0, dataPtr, sampleCount);
                }
                hr = render.ReleaseBuffer(bufferFrames, 0);
                if (hr != 0)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                hr = client.Start();
                if (hr != 0)
                {
                    ReleaseWasapiDevice(ref client, ref render);
                    return false;
                }

                mixerLastFailTick = 0;
                mixerFailLogged = false;
                return true;
            }
            catch (Exception ex)
            {
                if (!mixerFailLogged)
                {
                    mixerFailLogged = true;
                    Log.Write("combo audio WASAPI open: " + ex.Message);
                }
                ReleaseWasapiDevice(ref client, ref render);
                return false;
            }
            finally
            {
                if (fmtPtr != IntPtr.Zero) CoTaskMemFree(fmtPtr);
                if (customFmtPtr != IntPtr.Zero) Marshal.FreeCoTaskMem(customFmtPtr);
                if (dev != null) try { Marshal.ReleaseComObject(dev); } catch (Exception) { }
                if (en != null) try { Marshal.ReleaseComObject(en); } catch (Exception) { }
            }
        }

        static void ReleaseWasapiDevice(ref IAudioClient client, ref IAudioRenderClient render)
        {
            try { if (client != null) client.Stop(); } catch (Exception) { }
            if (render != null)
            {
                try { Marshal.ReleaseComObject(render); } catch (Exception) { }
                render = null;
            }
            if (client != null)
            {
                try { Marshal.ReleaseComObject(client); } catch (Exception) { }
                client = null;
            }
        }

        bool RunWasapiLoop(ManualResetEvent stopEvent)
        {
            IAudioClient client = null;
            IAudioRenderClient render = null;
            AutoResetEvent audioEvent = new AutoResetEvent(false);
            WaitHandle[] waitHandles = new WaitHandle[] { stopEvent, audioEvent };
            IntPtr mmcssHandle = IntPtr.Zero;

            try
            {
                uint taskIdx;
                try { mmcssHandle = AvSetMmThreadCharacteristicsW("Audio", out taskIdx); }
                catch (Exception) { mmcssHandle = IntPtr.Zero; }

                uint bufferFrames;
                int channels;
                int rate;
                bool isFloat;
                double periodMs;
                if (!OpenWasapiDevice(audioEvent, out client, out render, out bufferFrames, out channels, out rate, out isFloat, out periodMs))
                    return false;

                var monoBuf = new float[bufferFrames];
                float[] outFloats = isFloat ? new float[bufferFrames * channels] : null;
                short[] outShorts = isFloat ? null : new short[bufferFrames * channels];
                var sw = Stopwatch.StartNew();
                long lastWakeMs = sw.ElapsedMilliseconds;
                bool streamPrimed = false;

                while (true)
                {
                    int signaled = WaitHandle.WaitAny(waitHandles, 200);
                    if (signaled == 0) break;
                    lock (mixerLifecycleLock)
                    {
                        if (mixerStopping) break;
                    }

                    long nowMs = sw.ElapsedMilliseconds;
                    long elapsedMs = nowMs - lastWakeMs;
                    lastWakeMs = nowMs;

                    uint padding;
                    int hr = client.GetCurrentPadding(out padding);
                    if (hr == AUDCLNT_E_DEVICE_INVALIDATED || hr < 0)
                    {
                        ReleaseWasapiDevice(ref client, ref render);
                        if (hr == AUDCLNT_E_DEVICE_INVALIDATED)
                        {
                            if (stopEvent.WaitOne(150)) break;
                            if (!OpenWasapiDevice(audioEvent, out client, out render, out bufferFrames, out channels, out rate, out isFloat, out periodMs))
                            {
                                mixerLastFailTick = Environment.TickCount;
                                break;
                            }
                            if (monoBuf.Length < bufferFrames) monoBuf = new float[bufferFrames];
                            outFloats = isFloat ? new float[bufferFrames * channels] : null;
                            outShorts = isFloat ? null : new short[bufferFrames * channels];
                            streamPrimed = false;
                            lastWakeMs = sw.ElapsedMilliseconds;
                            continue;
                        }
                        mixerLastFailTick = Environment.TickCount;
                        break;
                    }

                    bool anyVoice = HasActiveVoices();
                    if (!ShouldKeepStreamAlive(anyVoice))
                    {
                        // User disabled Combo/ComboSound and tail finished -> stop cleanly
                        break;
                    }

                    if (streamPrimed && anyVoice && padding == 0 && elapsedMs > periodMs * 1.6)
                        mixerUnderruns++;

                    if (padding >= bufferFrames)
                        continue;

                    int framesAvailable = (int)(bufferFrames - padding);
                    IntPtr dataPtr;
                    hr = render.GetBuffer((uint)framesAvailable, out dataPtr);
                    if (hr == AUDCLNT_E_DEVICE_INVALIDATED || hr < 0 || dataPtr == IntPtr.Zero)
                    {
                        ReleaseWasapiDevice(ref client, ref render);
                        if (hr == AUDCLNT_E_DEVICE_INVALIDATED)
                        {
                            if (stopEvent.WaitOne(150)) break;
                            if (!OpenWasapiDevice(audioEvent, out client, out render, out bufferFrames, out channels, out rate, out isFloat, out periodMs))
                            {
                                mixerLastFailTick = Environment.TickCount;
                                break;
                            }
                            if (monoBuf.Length < bufferFrames) monoBuf = new float[bufferFrames];
                            outFloats = isFloat ? new float[bufferFrames * channels] : null;
                            outShorts = isFloat ? null : new short[bufferFrames * channels];
                            streamPrimed = false;
                            lastWakeMs = sw.ElapsedMilliseconds;
                            continue;
                        }
                        mixerLastFailTick = Environment.TickCount;
                        break;
                    }

                    if (anyVoice)
                    {
                        bool stillActive;
                        MixFramesFloat(monoBuf, framesAvailable, rate, out stillActive);
                        if (isFloat)
                        {
                            for (int f = 0; f < framesAvailable; f++)
                            {
                                float s = monoBuf[f];
                                int baseIdx = f * channels;
                                for (int c = 0; c < channels; c++)
                                    outFloats[baseIdx + c] = s;
                            }
                            Marshal.Copy(outFloats, 0, dataPtr, framesAvailable * channels);
                        }
                        else
                        {
                            for (int f = 0; f < framesAvailable; f++)
                            {
                                int iv = (int)Math.Round(monoBuf[f] * 32767.0f);
                                if (iv > 32767) iv = 32767;
                                else if (iv < -32768) iv = -32768;
                                short sv = (short)iv;
                                int baseIdx = f * channels;
                                for (int c = 0; c < channels; c++)
                                    outShorts[baseIdx + c] = sv;
                            }
                            Marshal.Copy(outShorts, 0, dataPtr, framesAvailable * channels);
                        }
                    }
                    else
                    {
                        int totalSamples = framesAvailable * channels;
                        if (isFloat)
                        {
                            Array.Clear(outFloats, 0, totalSamples);
                            Marshal.Copy(outFloats, 0, dataPtr, totalSamples);
                        }
                        else
                        {
                            Array.Clear(outShorts, 0, totalSamples);
                            Marshal.Copy(outShorts, 0, dataPtr, totalSamples);
                        }
                    }

                    hr = render.ReleaseBuffer((uint)framesAvailable, 0);
                    if (hr < 0)
                    {
                        ReleaseWasapiDevice(ref client, ref render);
                        mixerLastFailTick = Environment.TickCount;
                        break;
                    }
                    streamPrimed = true;
                }
                return true;
            }
            finally
            {
                ReleaseWasapiDevice(ref client, ref render);
                if (mmcssHandle != IntPtr.Zero)
                {
                    try { AvRevertMmThreadCharacteristics(mmcssHandle); } catch (Exception) { }
                }
                try { audioEvent.Dispose(); } catch (Exception) { }
            }
        }

        // Conservative 48 kHz stereo 20 ms x 4 waveOut fallback if WASAPI cannot initialize
        void RunWaveOutFallback(ManualResetEvent stopEvent)
        {
            IntPtr hWaveOut = IntPtr.Zero;
            AutoResetEvent waveEv = new AutoResetEvent(false);
            WaitHandle[] waitHandles = new WaitHandle[] { stopEvent, waveEv };
            var pcmBytes = new byte[FallbackBufCount][];
            var pcmHandles = new GCHandle[FallbackBufCount];
            var hdrPtrs = new IntPtr[FallbackBufCount];
            var inFlight = new bool[FallbackBufCount];
            var monoBuf = new float[FallbackFrames];
            var outShorts = new short[FallbackFrames * 2];
            bool timerSet = false;

            try
            {
                try { timerSet = timeBeginPeriod(1) == 0; } catch (Exception) { timerSet = false; }

                var fmt = new WAVEFORMATEX
                {
                    wFormatTag = 1,
                    nChannels = 2,
                    nSamplesPerSec = FallbackRate,
                    wBitsPerSample = 16,
                    nBlockAlign = 4,
                    nAvgBytesPerSec = FallbackRate * 4,
                    cbSize = 0
                };
                int mmr = waveOutOpen(out hWaveOut, WAVE_MAPPER, ref fmt, waveEv.SafeWaitHandle.DangerousGetHandle(), IntPtr.Zero, CALLBACK_EVENT);
                if (mmr != 0 || hWaveOut == IntPtr.Zero)
                {
                    mixerLastFailTick = Environment.TickCount;
                    if (!mixerFailLogged)
                    {
                        mixerFailLogged = true;
                        Log.Write("combo audio fallback waveOutOpen: " + mmr);
                    }
                    return;
                }

                for (int i = 0; i < FallbackBufCount; i++)
                {
                    pcmBytes[i] = new byte[FallbackBufBytes];
                    pcmHandles[i] = GCHandle.Alloc(pcmBytes[i], GCHandleType.Pinned);
                    hdrPtrs[i] = Marshal.AllocHGlobal(WaveHdrSize);
                    var hdr = new WAVEHDR
                    {
                        lpData = pcmHandles[i].AddrOfPinnedObject(),
                        dwBufferLength = (uint)FallbackBufBytes,
                        dwBytesRecorded = 0,
                        dwUser = IntPtr.Zero,
                        dwFlags = 0,
                        dwLoops = 0,
                        lpNext = IntPtr.Zero,
                        reserved = IntPtr.Zero
                    };
                    Marshal.StructureToPtr(hdr, hdrPtrs[i], false);
                    if (waveOutPrepareHeader(hWaveOut, hdrPtrs[i], WaveHdrSize) != 0)
                        return;
                    // Pre-queue all 4 buffers with silence before entering the wait loop
                    if (waveOutWrite(hWaveOut, hdrPtrs[i], WaveHdrSize) != 0)
                        return;
                    inFlight[i] = true;
                }

                while (true)
                {
                    int signaled = WaitHandle.WaitAny(waitHandles, 100);
                    if (signaled == 0) break;
                    lock (mixerLifecycleLock)
                    {
                        if (mixerStopping) break;
                    }

                    bool anyVoice = HasActiveVoices();
                    if (!ShouldKeepStreamAlive(anyVoice))
                        break;

                    int doneCount = 0;
                    for (int i = 0; i < FallbackBufCount; i++)
                    {
                        if (inFlight[i])
                        {
                            uint flags = (uint)Marshal.ReadInt32(hdrPtrs[i], WaveHdrFlagsOffset);
                            if ((flags & WHDR_DONE) != 0)
                            {
                                inFlight[i] = false;
                                doneCount++;
                            }
                        }
                    }

                    if (doneCount == FallbackBufCount && anyVoice)
                        mixerUnderruns++;

                    for (int i = 0; i < FallbackBufCount; i++)
                    {
                        if (inFlight[i]) continue;
                        if (HasActiveVoices())
                        {
                            bool stillActive;
                            MixFramesFloat(monoBuf, FallbackFrames, FallbackRate, out stillActive);
                            for (int f = 0; f < FallbackFrames; f++)
                            {
                                int iv = (int)Math.Round(monoBuf[f] * 32767.0f);
                                if (iv > 32767) iv = 32767;
                                else if (iv < -32768) iv = -32768;
                                short sv = (short)iv;
                                outShorts[f * 2] = sv;
                                outShorts[f * 2 + 1] = sv;
                            }
                            Buffer.BlockCopy(outShorts, 0, pcmBytes[i], 0, FallbackBufBytes);
                        }
                        else
                        {
                            Array.Clear(pcmBytes[i], 0, FallbackBufBytes);
                        }
                        if (waveOutWrite(hWaveOut, hdrPtrs[i], WaveHdrSize) != 0)
                        {
                            mixerLastFailTick = Environment.TickCount;
                            return;
                        }
                        inFlight[i] = true;
                    }
                }
            }
            finally
            {
                if (hWaveOut != IntPtr.Zero)
                {
                    try { waveOutReset(hWaveOut); } catch (Exception) { }
                    for (int i = 0; i < FallbackBufCount; i++)
                    {
                        if (hdrPtrs[i] != IntPtr.Zero)
                        {
                            uint flags = (uint)Marshal.ReadInt32(hdrPtrs[i], WaveHdrFlagsOffset);
                            if ((flags & WHDR_PREPARED) != 0)
                            {
                                try { waveOutUnprepareHeader(hWaveOut, hdrPtrs[i], WaveHdrSize); } catch (Exception) { }
                            }
                        }
                    }
                    try { waveOutClose(hWaveOut); } catch (Exception) { }
                }
                for (int i = 0; i < FallbackBufCount; i++)
                {
                    if (hdrPtrs[i] != IntPtr.Zero) Marshal.FreeHGlobal(hdrPtrs[i]);
                    if (pcmHandles[i].IsAllocated) pcmHandles[i].Free();
                }
                if (timerSet)
                {
                    try { timeEndPeriod(1); } catch (Exception) { }
                }
                try { waveEv.Dispose(); } catch (Exception) { }
            }
        }

        void MixerLoop(ManualResetEvent stopEvent)
        {
            try
            {
                if (!RunWasapiLoop(stopEvent))
                {
                    bool stopping;
                    lock (mixerLifecycleLock) { stopping = mixerStopping; }
                    if (!stopping)
                        RunWaveOutFallback(stopEvent);
                }
            }
            catch (Exception ex)
            {
                mixerLastFailTick = Environment.TickCount;
                Log.Write("combo audio mixer: " + ex.Message);
            }
            finally
            {
                lock (mixerLifecycleLock)
                {
                    if (ReferenceEquals(mixerStopEvent, stopEvent))
                        mixerStopEvent = null;
                    if (ReferenceEquals(mixerThread, Thread.CurrentThread))
                        mixerThread = null;
                }
                try { stopEvent.Dispose(); } catch (Exception) { }
            }
        }

        void PlayComboKeySound(int count, bool test)
        {
            if (!ComboAudioAllowed(test)) return;
            string prof = ComboSoundProfile;
            if (prof == "classic") return;
            EnsureComboAudio();
            if (prof == "thocky")
            {
                int idx = Math.Abs(count) % comboThockVariants.Length;
                PlayPinned(comboThockVariants[idx]);
            }
            else if (prof == "clicky")
            {
                int idx = Math.Abs(count) % comboClickVariants.Length;
                PlayPinned(comboClickVariants[idx]);
            }
            else if (prof == "piano")
            {
                int span = comboPianoNotes.Length - 1;
                int wave = Math.Abs(count - 1) % (span * 2);
                int idx = wave <= span ? wave : (span * 2 - wave);
                PlayPinned(comboPianoNotes[idx]);
            }
            else
            {
                int idx = Math.Max(0, Math.Min(comboArcadeBlips.Length - 1, count - 1));
                PlayPinned(comboArcadeBlips[idx]);
            }
        }

        void PlayComboTierUpSound(int tier)
        {
            if (!ComboAudioAllowed(false) || tier < 2) return;
            EnsureComboAudio();
            int idx = Math.Max(0, Math.Min(comboTierChimes.Length - 1, tier - 2));
            PlayPinned(comboTierChimes[idx], 0.92f);
        }

        void PlayComboPbFanfare()
        {
            if (!ComboAudioAllowed(false)) return;
            EnsureComboAudio();
            PlayPinned(comboPbFanfareWav, 0.95f);
        }

        void PlayComboCriticalSound()
        {
            if (!ComboAudioAllowed(false)) return;
            EnsureComboAudio();
            PlayPinned(comboCriticalWav, 0.95f);
        }

        void PlayComboBrokenSound()
        {
            if (!ComboAudioAllowed(false)) return;
            EnsureComboAudio();
            PlayPinned(comboBrokenWav, 0.90f);
        }

        void PlayComboShieldCrackSound()
        {
            if (!ComboAudioAllowed(false)) return;
            EnsureComboAudio();
            PlayPinned(comboShieldCrackWav, 0.92f);
        }

        public void PlayComboTestSound()
        {
            EnsureComboAudio();
            string prof = ComboSoundProfile;
            if (prof == "classic")
                PlayPinned(comboTierChimes[1]);
            else if (prof == "piano")
                PlayComboKeySound(6, true);
            else
                PlayComboKeySound(18, true);
        }

        static byte[] BuildWav(short[] samples)
        {
            int dataBytes = samples.Length * 2;
            byte[] buf = new byte[44 + dataBytes];
            // RIFF header
            buf[0] = (byte)'R'; buf[1] = (byte)'I'; buf[2] = (byte)'F'; buf[3] = (byte)'F';
            WriteInt32(buf, 4, 36 + dataBytes);
            buf[8] = (byte)'W'; buf[9] = (byte)'A'; buf[10] = (byte)'V'; buf[11] = (byte)'E';
            // fmt chunk
            buf[12] = (byte)'f'; buf[13] = (byte)'m'; buf[14] = (byte)'t'; buf[15] = (byte)' ';
            WriteInt32(buf, 16, 16); // PCM
            WriteInt16(buf, 20, 1);  // AudioFormat = 1
            WriteInt16(buf, 22, 1);  // Mono
            WriteInt32(buf, 24, ComboAudioRate);
            WriteInt32(buf, 28, ComboAudioRate * 2);
            WriteInt16(buf, 32, 2);  // BlockAlign
            WriteInt16(buf, 34, 16); // BitsPerSample
            // data chunk
            buf[36] = (byte)'d'; buf[37] = (byte)'a'; buf[38] = (byte)'t'; buf[39] = (byte)'a';
            WriteInt32(buf, 40, dataBytes);
            Buffer.BlockCopy(samples, 0, buf, 44, dataBytes);
            return buf;
        }

        static void WriteInt32(byte[] b, int off, int v)
        {
            b[off] = (byte)(v & 0xFF);
            b[off + 1] = (byte)((v >> 8) & 0xFF);
            b[off + 2] = (byte)((v >> 16) & 0xFF);
            b[off + 3] = (byte)((v >> 24) & 0xFF);
        }

        static void WriteInt16(byte[] b, int off, short v)
        {
            b[off] = (byte)(v & 0xFF);
            b[off + 1] = (byte)((v >> 8) & 0xFF);
        }

        static short ClampSample(double v)
        {
            int iv = (int)Math.Round(v * 32767.0);
            if (iv > 32767) return 32767;
            if (iv < -32768) return -32768;
            return (short)iv;
        }

        static void ApplyFadeOut(short[] s, int fadeSamples)
        {
            if (s == null || s.Length == 0 || fadeSamples <= 0) return;
            int count = Math.Min(fadeSamples, s.Length);
            int start = s.Length - count;
            for (int i = 0; i < count; i++)
            {
                double g = (double)(count - 1 - i) / count;
                s[start + i] = (short)Math.Round(s[start + i] * g);
            }
        }

        static void RemoveDc(short[] s)
        {
            if (s == null || s.Length == 0) return;
            double prevX = s[0];
            double prevY = 0;
            s[0] = 0;
            const double r = 0.995;
            for (int i = 1; i < s.Length; i++)
            {
                double x = s[i];
                double y = x - prevX + r * prevY;
                prevX = x;
                prevY = y;
                int iv = (int)Math.Round(y);
                if (iv > 32767) iv = 32767;
                else if (iv < -32768) iv = -32768;
                s[i] = (short)iv;
            }
        }

        static short[] SynthArcadeBlip(double freq, double durSec)
        {
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double phase = 0;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double env = Math.Min(1.0, t / 0.0014) * Math.Exp(-t * 85.0);
                double f = freq * (1.0 + t * 5.0);
                phase += 2.0 * Math.PI * f / ComboAudioRate;
                double sine = Math.Sin(phase);
                double tri = 2.0 * Math.Abs(2.0 * ((phase / (2.0 * Math.PI)) - Math.Floor(phase / (2.0 * Math.PI) + 0.5))) - 1.0;
                s[i] = ClampSample((sine * 0.80 + tri * 0.20) * env * 0.42);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.008));
            return s;
        }

        static short[] SynthThock(double freq, double durSec, int seed)
        {
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double phase = 0;
            uint rng = (uint)(0x9E3779B9u + seed * 1013904223u);
            double lp = 0;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double bodyEnv = Math.Min(1.0, t / 0.0014) * Math.Exp(-t * 68.0);
                double f = freq * (1.0 - Math.Min(0.42, t * 16.0));
                phase += 2.0 * Math.PI * f / ComboAudioRate;
                rng = rng * 1664525u + 1013904223u;
                double raw = (rng >> 16) / 32768.0 - 1.0;
                lp += 0.18 * (raw - lp);
                double noise = lp * Math.Exp(-t * 360.0) * 0.10;
                double body = Math.Sin(phase) * 0.78 + Math.Sin(phase * 2.0) * 0.14;
                double knockFreq = freq * 2.4;
                double knock = Math.Sin(2.0 * Math.PI * knockFreq * t) * Math.Exp(-t * 155.0) * 0.34 * Math.Min(1.0, t / 0.0012);
                s[i] = ClampSample((body * bodyEnv + knock + noise * Math.Min(1.0, t / 0.0012)) * 0.82);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.010));
            return s;
        }

        static short[] SynthClick(double resFreq, double durSec, int seed)
        {
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double bodyPhase = 0;
            uint rng = (uint)(0x85EBCA6Bu + seed * 2246822519u);
            double lp = 0, hp = 0, prevLp = 0;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double clickEnv = Math.Min(1.0, t / 0.0012) * Math.Exp(-t * 165.0);
                double bodyEnv = Math.Min(1.0, t / 0.0012) * Math.Exp(-t * 140.0);
                bodyPhase += 2.0 * Math.PI * (245.0 * (1.0 - Math.Min(0.35, t * 14.0))) / ComboAudioRate;
                rng = rng * 1664525u + 1013904223u;
                double raw = (rng >> 16) / 32768.0 - 1.0;
                lp += 0.35 * (raw - lp);
                hp = 0.85 * (hp + lp - prevLp);
                prevLp = lp;
                double noise = hp * Math.Exp(-t * 380.0) * Math.Min(1.0, t / 0.0012);
                double res = Math.Sin(2.0 * Math.PI * resFreq * t) * 0.65 + Math.Sin(2.0 * Math.PI * (resFreq * 2.1) * t) * 0.35;
                double bottom = Math.Sin(bodyPhase) * 0.35 * bodyEnv;
                s[i] = ClampSample((res * clickEnv * 0.65 + noise * 0.24 + bottom) * 0.48);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.008));
            return s;
        }

        static short[] SynthPianoNote(double freq, double durSec, int seed)
        {
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double twoPi = 2.0 * Math.PI;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double attack = Math.Min(1.0, t / 0.0018);

                // Fundamental + slight unison string detune
                double h1 = (Math.Sin(twoPi * freq * t) * 0.55 + Math.Sin(twoPi * (freq * 1.0012) * t) * 0.45) * Math.Exp(-t * 10.5);
                double h2 = Math.Sin(twoPi * (freq * 2.0) * t) * Math.Exp(-t * 15.0) * 0.34;
                double h3 = Math.Sin(twoPi * (freq * 3.0) * t) * Math.Exp(-t * 24.0) * 0.16;
                double h4 = Math.Sin(twoPi * (freq * 4.0) * t) * Math.Exp(-t * 36.0) * 0.07;
                double strings = (h1 + h2 + h3 + h4) * 0.62;

                s[i] = ClampSample(strings * attack * 0.36);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.020));
            return s;
        }

        static short[] SynthTierChime(double rootFreq, double durSec)
        {
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double f1 = rootFreq, f2 = rootFreq * 1.25, f3 = rootFreq * 1.5, f4 = rootFreq * 2.0;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double env = Math.Min(1.0, t / 0.002) * Math.Exp(-t * 13.5);
                double v = Math.Sin(2.0 * Math.PI * f1 * t) * 0.40
                         + Math.Sin(2.0 * Math.PI * f2 * t) * 0.26
                         + Math.Sin(2.0 * Math.PI * f3 * t) * 0.22
                         + Math.Sin(2.0 * Math.PI * f4 * t) * 0.12;
                s[i] = ClampSample(v * env * 0.38);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.015));
            return s;
        }

        static short[] SynthPbFanfare()
        {
            double durSec = 0.28;
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double[] notes = { 523.25, 659.25, 783.99, 1046.50 };
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double sum = 0;
                for (int k = 0; k < notes.Length; k++)
                {
                    double nt = t - k * 0.055;
                    if (nt < 0) continue;
                    double env = Math.Min(1.0, nt / 0.002) * Math.Exp(-nt * 16.0);
                    double f = notes[k];
                    sum += (Math.Sin(2.0 * Math.PI * f * nt) * 0.72 + Math.Sin(2.0 * Math.PI * f * 2.0 * nt) * 0.28) * env;
                }
                s[i] = ClampSample(sum * 0.32);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.015));
            return s;
        }

        static short[] SynthCritical()
        {
            double durSec = 0.16;
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double f = t < 0.055 ? 620.0 : 980.0;
                double nt = t < 0.055 ? t : (t - 0.055);
                double env = Math.Min(1.0, nt / 0.0015) * Math.Exp(-nt * 24.0);
                double v = Math.Sin(2.0 * Math.PI * f * nt) * 0.7 + Math.Sin(2.0 * Math.PI * f * 1.5 * nt) * 0.3;
                s[i] = ClampSample(v * env * 0.58);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.012));
            return s;
        }

        static short[] SynthBroken()
        {
            double durSec = 0.18;
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            double phase = 0;
            uint rng = 0x12345678u;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double f = 320.0 * Math.Exp(-t * 7.5);
                phase += 2.0 * Math.PI * f / ComboAudioRate;
                double env = Math.Min(1.0, t / 0.0015) * Math.Exp(-t * 16.0);
                rng = rng * 1664525u + 1013904223u;
                double crunch = ((rng >> 16) / 32768.0 - 1.0) * 0.25;
                s[i] = ClampSample((Math.Sin(phase) * 0.75 + crunch) * env * 0.54);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.012));
            return s;
        }

        static short[] SynthShieldCrack()
        {
            double durSec = 0.085;
            int n = (int)(ComboAudioRate * durSec);
            var s = new short[n];
            uint rng = 0xCAFEBABEu;
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / ComboAudioRate;
                double env = Math.Min(1.0, t / 0.0012) * Math.Exp(-t * 52.0);
                rng = rng * 1664525u + 1013904223u;
                double noise = ((rng >> 16) / 32768.0 - 1.0) * 0.4;
                double tone = Math.Sin(2.0 * Math.PI * 1240.0 * t) * 0.6;
                s[i] = ClampSample((tone + noise) * env * 0.52);
            }
            RemoveDc(s);
            ApplyFadeOut(s, (int)(ComboAudioRate * 0.010));
            return s;
        }
    }
}
