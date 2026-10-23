#!/usr/bin/env python3
"""Procedural SFX generator (no external assets, no licensing).

Usage: python3 tools/generate_sfx.py
Writes OGG files to assets/audio/sfx/ui and assets/audio/sfx/game.
Requires numpy and ffmpeg (libvorbis).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(1337)


def t_(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, decay=0.2, curve=3.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / max(decay, 1e-4))
    return a * d


def sine(f, dur, phase=0.0):
    f = np.broadcast_to(f, t_(dur).shape) if np.ndim(f) else f
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(f, t_(dur).shape)) / SR
    return np.sin(ph + phase)


def saw(f, dur):
    ph = np.cumsum(np.broadcast_to(f, t_(dur).shape)) / SR
    return 2 * (ph % 1.0) - 1


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def reverb(x, tail=0.6, mix=0.25):
    n = int(SR * tail)
    ir = rng.uniform(-1, 1, n) * np.exp(-6 * np.arange(n) / n)
    wet = np.convolve(x, ir)[: len(x) + n]
    out = np.zeros(len(wet))
    out[: len(x)] += x * (1 - mix)
    out += wet / (np.max(np.abs(wet)) + 1e-9) * mix * np.max(np.abs(x))
    return out


def bell(f, dur, partials=((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))):
    n = int(SR * dur)
    y = np.zeros(n)
    for ratio, amp in partials:
        y += amp * np.sin(2 * np.pi * f * ratio * t_(dur)) * env(n, 0.002, dur / (1 + ratio * 0.4), 5)
    return y


def pad(x, front=0.0):
    return np.concatenate([np.zeros(int(SR * front)), x])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def fade_tail(x, ms=15):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(x, folder, name, peak=0.8, loop_fade=False):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    if not loop_fade:
        x = fade_tail(x)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    out_dir = os.path.join(ROOT, folder)
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_name = tmp.name
    with wave.open(tmp_name, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(out_dir, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_name, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    os.unlink(tmp_name)
    print("wrote", os.path.relpath(dst, ROOT))


# ---------------------------------------------------------------- UI
def ui_click():
    n = int(SR * 0.06)
    return highpass(noise(0.06), 800) * env(n, 0.0005, 0.02, 6) * 0.6 + sine(1800, 0.06) * env(n, 0.0005, 0.015, 6) * 0.5


def ui_hover():
    n = int(SR * 0.05)
    return sine(1100, 0.05) * env(n, 0.003, 0.03, 4) * 0.5


def ui_confirm():
    return mix(bell(520, 0.35), pad(bell(780, 0.45), 0.07))


def ui_cancel():
    return mix(bell(330, 0.3), pad(bell(220, 0.4), 0.07))


def ui_error():
    n = int(SR * 0.28)
    return lowpass(saw(np.full(n, 95.0), 0.28), 700) * env(n, 0.003, 0.2, 3) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 22 * t_(0.28))))


# ---------------------------------------------------------------- game
def coin_ding():
    return reverb(bell(1568, 0.8), 0.4, 0.2)


def win_small():
    notes = [392.0, 493.9, 587.3]
    return reverb(mix(*[pad(bell(f, 0.6), i * 0.09) for i, f in enumerate(notes)]), 0.6, 0.25)


def win_jackpot():
    notes = [261.6, 329.6, 392.0, 523.3, 659.3, 784.0, 1046.5]
    arp = mix(*[pad(bell(f, 0.9), i * 0.07) for i, f in enumerate(notes)])
    shimmer = highpass(noise(1.4), 4000) * env(int(SR * 1.4), 0.2, 0.9, 3) * 0.12
    return reverb(mix(arp, shimmer), 1.0, 0.3)


def lose_sting():
    n = int(SR * 1.4)
    f = np.linspace(180, 55, n)
    drone = lowpass(saw(f, 1.4) + saw(f * 1.06, 1.4), 600) * env(n, 0.01, 0.9, 3)
    toll = bell(98, 1.4, ((1, 1.0), (2.1, 0.5), (3.3, 0.3)))
    return reverb(mix(drone * 0.5, toll), 0.8, 0.3)


def reel_stop():
    n = int(SR * 0.18)
    thump = sine(np.linspace(140, 60, n), 0.18) * env(n, 0.001, 0.08, 5)
    click = highpass(noise(0.18), 1500) * env(n, 0.0005, 0.02, 6) * 0.5
    return thump + click


def reel_spin():
    dur = 1.2
    out = np.zeros(int(SR * dur))
    step = int(SR * 0.055)
    for i in range(0, len(out) - step, step):
        tick = highpass(noise(0.03), 1200) * env(int(SR * 0.03), 0.0005, 0.01, 6)
        out[i : i + len(tick)] += tick * 0.7
    out += lowpass(noise(dur), 300) * 0.15
    return out


def lever_pull():
    n = int(SR * 0.4)
    ratchet = np.zeros(n)
    for i in range(0, n - 400, 1300):
        ratchet[i : i + 400] += highpass(rng.uniform(-1, 1, 400), 1500) * env(400, 0.0003, 0.004, 6)
    thunk = sine(np.linspace(110, 50, n), 0.4) * env(n, 0.005, 0.12, 5) * 0.8
    return ratchet + pad(thunk, 0.0)


def curse_hit():
    n = int(SR * 0.9)
    sub = sine(np.linspace(90, 38, n), 0.9) * env(n, 0.002, 0.5, 4)
    crack = lowpass(noise(0.9), 2500) * env(n, 0.0005, 0.08, 6) * 0.7
    dis = saw(np.full(n, 140.0), 0.9) * env(n, 0.002, 0.3, 4) * 0.25
    return reverb(sub + crack + dis, 0.6, 0.25)


def heartbeat():
    def thump(depth):
        n = int(SR * 0.22)
        return sine(np.linspace(75, 42, n), 0.22) * env(n, 0.004, 0.1, 5) * depth

    out = np.zeros(int(SR * 1.0))
    for start, depth in ((0.0, 1.0), (0.22, 0.7)):
        s = int(SR * start)
        th = thump(depth)
        out[s : s + len(th)] += th
    return out


def tension_drone():
    dur = 4.0
    n = int(SR * dur)
    f = 55.0 + 1.5 * np.sin(2 * np.pi * 0.25 * t_(dur))
    x = lowpass(saw(f, dur) + saw(f * 1.5 * 1.012, dur) * 0.6 + saw(f * 2.01, dur) * 0.3, 450)
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t_(dur))
    x += lowpass(noise(dur), 900) * 0.08
    fade = int(SR * 0.4)  # seamless loop: crossfade the tail into the head
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    return x[:-fade]


def card_reveal():
    dur = 0.45
    n = int(SR * dur)
    sweep = highpass(noise(dur), 600)
    sweep = lowpass(sweep, 5000) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.6
    ping = bell(880, 0.5) * 0.3
    return reverb(mix(sweep, pad(ping, 0.18)), 0.5, 0.2)


def item_use():
    dur = 0.9
    n = int(SR * dur)
    chirp = sine(np.linspace(300, 1400, n), dur) * env(n, 0.01, 0.5, 4) * 0.5
    sparkle = highpass(noise(dur), 5000) * env(n, 0.05, 0.4, 4) * 0.2
    return reverb(chirp + sparkle, 0.7, 0.3)


JOBS = {
    "ui": [ui_click, ui_hover, ui_confirm, ui_cancel, ui_error],
    "game": [coin_ding, win_small, win_jackpot, lose_sting, reel_stop, reel_spin, lever_pull,
             curse_hit, heartbeat, tension_drone, card_reveal, item_use],
}
LOOPS = {"tension_drone"}

if __name__ == "__main__":
    for folder, fns in JOBS.items():
        for fn in fns:
            save(fn(), folder, fn.__name__, loop_fade=fn.__name__ in LOOPS)
