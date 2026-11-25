"""Procedural music for Реликварий: dark-medieval drones, bells, frame drums, plucked lines.
python3 game/tools/make_music.py  → game/audio/music/{menu,run,boss}.ogg (seamless loops)."""
import numpy as np, subprocess, os, wave
SR = 44100
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")

def hz(n):  # midi → Hz
    return 440.0 * 2 ** ((n - 69) / 12)

def env(n, a, r):
    e = np.ones(n)
    a, r = int(a * SR), int(r * SR)
    if a: e[:a] = np.linspace(0, 1, a)
    if r: e[-r:] *= np.linspace(1, 0, r)
    return e

def lowpass(x, cut):
    # one-pole, run twice
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x); s = 0.0
    for _ in range(2):
        for i in range(len(x)):
            s = (1 - a) * x[i] + a * s; y[i] = s
        x = y.copy()
    return y

def lp_fast(x, cut):
    # FFT brick-ish low-pass with soft knee (fast for long buffers)
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cut) ** 4)
    return np.fft.irfft(X, len(x))

def pad(notes, dur, bright=0.35, det=0.004):
    t = np.arange(int(dur * SR)) / SR
    y = np.zeros_like(t)
    for n in notes:
        f0 = hz(n)
        for d in (-det, 0, det):
            for k in range(1, 9):
                y += np.sin(2 * np.pi * f0 * (1 + d) * k * t + rng.uniform(0, 6.28)) * (bright ** (k - 1)) / k
    y *= 1 + 0.15 * np.sin(2 * np.pi * 0.17 * t)
    return y / max(1e-9, np.abs(y).max()) * env(len(t), dur * 0.35, dur * 0.35)

def bell(n, dur=6.0, amp=1.0):
    t = np.arange(int(dur * SR)) / SR
    f0 = hz(n)
    y = np.zeros_like(t)
    for ratio, a, dec in ((0.56, .6, .9), (1.0, 1, .6), (1.19, .5, .8), (2.0, .55, .4), (2.74, .35, .3), (3.76, .2, .2), (5.4, .12, .12)):
        y += a * np.sin(2 * np.pi * f0 * ratio * t) * np.exp(-t / (dur * dec * 0.5))
    return amp * y * env(len(t), 0.004, 0.2) / 2.5

def pluck(n, dur=1.6, amp=1.0, damp=0.996):
    # Karplus-Strong
    N = int(SR / hz(n)); buf = rng.uniform(-1, 1, N)
    out = np.zeros(int(dur * SR))
    for i in range(len(out)):
        out[i] = buf[i % N]
        buf[i % N] = damp * 0.5 * (buf[i % N] + buf[(i + 1) % N])
    return amp * out * env(len(out), 0.002, 0.15)

def drum(dur=0.9, pitch=55, amp=1.0, noise=0.4):
    t = np.arange(int(dur * SR)) / SR
    f = pitch * (1 + 1.5 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)
    hit = lp_fast(rng.uniform(-1, 1, len(t)), 1800) * np.exp(-t * 40) * noise
    return amp * (body + hit)

def wind(dur, amp=0.08):
    n = rng.uniform(-1, 1, int(dur * SR))
    y = lp_fast(n, 500)
    t = np.arange(len(y)) / SR
    return amp * y / np.abs(y).max() * (0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t))

def place(buf, x, at):
    i = int(at * SR) % len(buf)
    end = i + len(x)
    if end <= len(buf):
        buf[i:end] += x
    else:  # wrap around → seamless loop
        k = len(buf) - i
        buf[i:] += x[:k]; buf[:end - len(buf)] += x[k:]

def reverb(x, amt=0.35):
    y = x.copy()
    for d, g in ((0.031, .5), (0.047, .45), (0.071, .4), (0.113, .33), (0.173, .27), (0.257, .2), (0.37, .14)):
        y += g * amt * np.roll(x, int(d * SR))
    return y

def write(name, y):
    y = reverb(y)
    y = y / np.abs(y).max() * 0.85
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    st = np.stack([pcm, np.roll(pcm, int(0.011 * SR))], 1)   # tiny stereo width
    tmp = os.path.join("/tmp", name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(st.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    print(name, round(len(y) / SR, 1), "s →", out)

# D minor world: D2=38. Chords as midi lists.
DM, BB, GM, AM, CM = [38, 45, 50, 53], [34, 41, 46, 50], [31, 38, 43, 46], [33, 40, 45, 49], [36, 43, 48, 52]

def menu():
    L = 64.0; y = np.zeros(int(L * SR))
    for i, ch in enumerate([DM, BB, GM, AM, DM, CM, BB, AM]):
        place(y, 0.5 * pad(ch, 10.0, 0.3), i * 8.0 - 1.0)
    place(y, 0.25 * pad([26], L, 0.5), 0)                      # low drone under everything
    for i, n in enumerate([62, 57, 62, 58, 62, 57, 60, 57]):    # distant bell every 8 s
        place(y, 0.35 * bell(n, 7.0), i * 8.0 + 0.2)
    y += wind(L, 0.05)
    return y

def run():
    bpm = 72; beat = 60 / bpm; bars = 16; L = bars * 4 * beat; y = np.zeros(int(L * SR))
    prog = [DM, DM, BB, BB, GM, GM, AM, AM] * 2
    for b, ch in enumerate(prog):
        place(y, 0.32 * pad(ch, 4 * beat + 2.0, 0.28), b * 4 * beat - 1.0)
    for b in range(bars):
        for k, (at, p, a) in enumerate(((0, 55, 1.0), (1.5, 62, 0.45), (2, 55, 0.8), (3, 70, 0.35), (3.5, 62, 0.4))):
            place(y, 0.5 * drum(0.8, p, a), (b * 4 + at) * beat)
    phr = [62, 65, 64, 62, 60, 62, 57, None, 58, 60, 62, 65, 64, 61, 62, None]
    for b in range(bars):
        for i in range(4):
            n = phr[(b * 4 + i) % len(phr)]
            if n is not None and (b % 4 != 3 or i < 2):
                place(y, 0.32 * pluck(n, 1.4, damp=0.995), (b * 4 + i) * beat + 0.02 * rng.uniform())
    for b in range(0, bars, 4):
        place(y, 0.25 * bell(74, 6.0), b * 4 * beat)
    y += wind(L, 0.04)
    return y

def boss():
    bpm = 100; beat = 60 / bpm; bars = 16; L = bars * 4 * beat; y = np.zeros(int(L * SR))
    prog = [DM, DM, [37, 44, 49, 52], DM, BB, [32, 39, 44, 47], AM, AM] * 2   # Eb-ish and Ab tritone colours
    for b, ch in enumerate(prog):
        place(y, 0.42 * pad(ch, 4 * beat + 1.5, 0.5, 0.007), b * 4 * beat - 0.8)
    for b in range(bars):
        for at, p, a in ((0, 48, 1.2), (0.75, 48, 0.6), (1.5, 48, 0.8), (2, 60, 0.7), (2.5, 48, 0.9), (3, 66, 0.5), (3.5, 48, 0.7), (3.75, 66, 0.4)):
            place(y, 0.55 * drum(0.7, p, a, 0.6), (b * 4 + at) * beat)
    riff = [50, 50, 51, 50, 56, 55, 51, 50]
    for b in range(bars):
        for i, n in enumerate(riff):
            place(y, 0.3 * pluck(n - 12, 0.9, damp=0.99), (b * 4 + i * 0.5) * beat)
    for b in range(0, bars, 2):
        place(y, 0.3 * bell(68, 5.0), b * 4 * beat)   # tritone bell over D
    return y

for name, fn in (("menu", menu), ("run", run), ("boss", boss)):
    write(name, fn())
