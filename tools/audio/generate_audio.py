"""Minik Kasaba - ana sahne seslerini prosedürel olarak üretir.

Tüm sesler bu script tarafından sıfırdan sentezlenir (harici kayıt yok, telif yok).
Döngüler (müzik, rüzgâr) frekans alanında dairesel işlendiği için dikişsiz döner.

Gereksinimler: numpy, scipy, soundfile (OGG Vorbis yazabilen libsndfile ile)
Kullanım (proje kökünden):  python tools/audio/generate_audio.py
"""
from __future__ import annotations

import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
PEAK_DBFS = -3.0
SEED = 7
WRITE_BLOCK = 4096
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")

rng = np.random.default_rng(SEED)


# ------------------------------------------------------------------ yardımcılar
def normalize(x: np.ndarray, peak_dbfs: float = PEAK_DBFS) -> np.ndarray:
    return x * (10 ** (peak_dbfs / 20) / np.max(np.abs(x)))


def write(rel: str, x: np.ndarray) -> None:
    path = os.path.join(AUDIO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = normalize(x).astype(np.float32)
    # libsndfile, Windows'ta uzun Vorbis verisini tek çağrıda yazarken yığın taşmasına düşüyor: bloklarla yaz.
    with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), WRITE_BLOCK):
            f.write(data[i: i + WRITE_BLOCK])
    print(f"{rel:40s} {len(x) / SR:6.2f} sn")


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def times(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def lowpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, hz, "low", fs=SR, output="sos"), x)


def circular_spectrum_filter(x: np.ndarray, gain_fn) -> np.ndarray:
    """Periyodik sinyali FFT ile süzer; sonuç da periyodik kalır (dikişsiz döngü)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec * gain_fn(f), len(x))


def reverb_ir(seconds: float, damp_hz: float) -> np.ndarray:
    t = times(seconds)
    ir = rng.standard_normal(len(t)) * np.exp(-t * 6.0 / seconds)
    ir = lowpass(ir, damp_hz)
    return ir / np.sqrt(np.sum(ir ** 2))


def circular_reverb(x: np.ndarray, wet: float, seconds: float = 1.6, damp_hz: float = 3000) -> np.ndarray:
    ir = np.zeros(len(x))
    tail = reverb_ir(seconds, damp_hz)
    ir[: len(tail)] = tail
    wet_sig = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), len(x))
    return x + wet * wet_sig * (np.std(x) / max(np.std(wet_sig), 1e-9))


def linear_reverb(x: np.ndarray, wet: float, seconds: float = 0.5, damp_hz: float = 4000) -> np.ndarray:
    ir = reverb_ir(seconds, damp_hz)
    y = np.convolve(x, ir)
    y = y * (np.std(x) / max(np.std(y[: len(x)]), 1e-9))
    out = np.zeros(len(y))
    out[: len(x)] += x
    return out + wet * y


def fade_edges(x: np.ndarray, fade_in: float = 0.005, fade_out: float = 0.05) -> np.ndarray:
    n_in, n_out = int(fade_in * SR), int(fade_out * SR)
    x = x.copy()
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


# ------------------------------------------------------------------ müzik enstrümanları
def music_box(freq: float, dur: float) -> np.ndarray:
    t = times(max(dur, 1.8))
    out = np.zeros(len(t))
    for k, amp in ((1, 1.0), (2, 0.16), (3, 0.05)):
        out += amp * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (1.1 + 0.9 * k))
    return out * np.minimum(t / 0.004, 1)


def flute(freq: float, dur: float) -> np.ndarray:
    t = times(dur + 0.25)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = lowpass(rng.standard_normal(len(t)), 2500) * 0.015
    env = np.clip(t / 0.08, 0, 1) * np.clip((dur + 0.25 - t) / 0.25, 0, 1)
    return (tone + breath) * env


def soft_piano(freq: float, dur: float) -> np.ndarray:
    t = times(max(dur, 2.5))
    out = np.zeros(len(t))
    for k in range(1, 7):
        out += (1 / k ** 1.6) * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (0.7 + 0.5 * k))
    return out * np.minimum(t / 0.006, 1)


def pad(freqs: list[float], dur: float) -> np.ndarray:
    t = times(dur + 0.6)
    out = sum(np.sin(2 * np.pi * f * t) + 0.1 * np.sin(4 * np.pi * f * t) for f in freqs)
    env = np.clip(t / 0.6, 0, 1) * np.clip((dur + 0.6 - t) / 0.6, 0, 1)
    return out * env


# ------------------------------------------------------------------ müzik
BPM = 80
BEAT = 60 / BPM
BAR_BEATS = 4

# Akorlar: (bas notası, akor sesleri [kök, üçlü, beşli])
CHORDS = {
    "C": (48, (60, 64, 67)),
    "Am": (45, (57, 60, 64)),
    "F": (41, (53, 57, 60)),
    "G": (43, (55, 59, 62)),
    "Em": (40, (52, 55, 59)),
}
PROG_A = ["C", "Am", "F", "G", "C", "Am", "F", "C"]
PROG_B = ["F", "G", "Em", "Am", "F", "G", "C", "G"]

R = None  # sus
MELODY_A = [[(76, 2), (79, 1), (76, 1)], [(72, 2), (69, 2)], [(77, 1.5), (76, 0.5), (74, 1), (72, 1)], [(74, 3), (R, 1)],
            [(76, 2), (79, 1), (81, 1)], [(79, 2), (76, 2)], [(77, 1), (81, 1), (79, 1), (77, 1)], [(76, 3), (R, 1)]]
MELODY_A_END = MELODY_A[:7] + [[(72, 3), (R, 1)]]
MELODY_B = [[(81, 2), (79, 1), (77, 1)], [(74, 2), (71, 1), (74, 1)], [(76, 2), (79, 2)], [(81, 3), (R, 1)],
            [(77, 1), (76, 1), (74, 1), (72, 1)], [(74, 1), (76, 1), (74, 1), (71, 1)], [(72, 2), (76, 2)], [(74, 3), (R, 1)]]

# (akor dizisi, melodi, melodi enstrümanı)
SECTIONS = [(PROG_A, MELODY_A, "box"), (PROG_A, MELODY_A, "flute"), (PROG_B, MELODY_B, "flute"), (PROG_A, MELODY_A_END, "box")]


def make_music() -> np.ndarray:
    bars = sum(len(p) for p, _, _ in SECTIONS)
    length = int(round(bars * BAR_BEATS * BEAT * SR))
    buf = np.zeros(length + 6 * SR)

    def add(sig: np.ndarray, start_beat: float, gain: float) -> None:
        i = int(round(start_beat * BEAT * SR))
        buf[i: i + len(sig)] += gain * sig

    bar = 0
    for prog, melody, inst in SECTIONS:
        for chord_name, notes in zip(prog, melody):
            bass, tones = CHORDS[chord_name]
            b0 = bar * BAR_BEATS
            add(soft_piano(midi_hz(bass), 3 * BEAT), b0, 0.30)
            for j, m in enumerate((tones[0], tones[2], tones[1] + 12, tones[2])):
                add(soft_piano(midi_hz(m), BEAT), b0 + j, 0.10)
            add(pad([midi_hz(m) for m in tones], BAR_BEATS * BEAT), b0, 0.025)
            beat = b0
            for m, d in notes:
                if m is not None:
                    if inst == "box":
                        add(music_box(midi_hz(m), d * BEAT), beat, 0.30)
                    else:
                        add(flute(midi_hz(m), d * BEAT), beat, 0.24)
                beat += d
            bar += 1

    # Kuyruğu başa sar: sinyal artık tam periyodik.
    loop = buf[:length].copy()
    loop[: len(buf) - length] += buf[length:]
    # Tiz ve sert frekansları yumuşat (dairesel süzgeç -> dikişsiz).
    loop = circular_spectrum_filter(loop, lambda f: 1 / np.sqrt(1 + (f / 4200) ** 4) * (1 / np.sqrt(1 + (40 / np.maximum(f, 1)) ** 4)))
    return circular_reverb(loop, wet=0.22, seconds=1.8, damp_hz=2800)


# ------------------------------------------------------------------ rüzgâr
def make_wind(seconds: float = 40.0) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR

    def band(lo: float, hi: float, tilt: float):
        def gain(f: np.ndarray) -> np.ndarray:
            f = np.maximum(f, 1)
            return (1 / f ** tilt) / np.sqrt(1 + (lo / f) ** 4) / np.sqrt(1 + (f / hi) ** 4)
        return gain

    body = circular_spectrum_filter(rng.standard_normal(n), band(70, 650, 0.5))
    leaves = circular_spectrum_filter(rng.standard_normal(n), band(1500, 3500, 0.0))
    body /= np.std(body)
    leaves /= np.std(leaves)
    # Esinti zarfları: periyotlar döngü uzunluğunu tam böler.
    gust = 0.65 + 0.22 * np.sin(2 * np.pi * 2 * t / seconds + 0.7) + 0.13 * np.sin(2 * np.pi * 5 * t / seconds + 2.1)
    rustle = np.maximum(0, np.sin(2 * np.pi * 3 * t / seconds + 1.3)) ** 3
    return body * gust + 0.12 * leaves * rustle


# ------------------------------------------------------------------ kuşlar
def chirp(contour: list[tuple[float, float]], dur: float, vibrato: float = 0.0) -> np.ndarray:
    """contour: (zaman oranı, Hz) noktaları; yumuşak zarflı tek bir ötüş."""
    t = times(dur)
    pts_t = np.array([p[0] for p in contour]) * dur
    freq = np.interp(t, pts_t, [p[1] for p in contour])
    freq *= 1 + vibrato * np.sin(2 * np.pi * 28 * t)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return (np.sin(phase) + 0.12 * np.sin(2 * phase)) * env


def sequence(parts: list[tuple[np.ndarray, float]]) -> np.ndarray:
    """(ses, öncesindeki sessizlik sn) listesini art arda dizer."""
    out = []
    for sig, gap in parts:
        out.append(np.zeros(int(gap * SR)))
        out.append(sig)
    return np.concatenate(out)


def make_birds() -> list[np.ndarray]:
    up = [(0, 2200), (1, 3100)]
    down = [(0, 3300), (1, 2400)]
    birds = [
        sequence([(chirp(up, 0.08), 0), (chirp(up, 0.08), 0.06)]),
        sequence([(chirp([(0, 2600), (1, 2700)] if i % 2 else [(0, 3000), (1, 2900)], 0.045), 0.02) for i in range(7)]),
        sequence([(chirp(down, 0.12), 0), (chirp(down, 0.11), 0.08)]),
        chirp([(0, 2000), (0.4, 2600), (1, 2250)], 0.34, vibrato=0.01),
        sequence([(chirp([(0, f + 120), (1, f)], 0.09), 0.05 if i else 0) for i, f in enumerate((3000, 2700, 2400))]),
    ]
    return [fade_edges(linear_reverb(lowpass(b, 5000), wet=0.18, seconds=0.35)) for b in birds]


# ------------------------------------------------------------------ uzak inek
def make_distant_cow() -> np.ndarray:
    dur = 1.8
    t = times(dur)
    f0 = np.interp(t, [0, 0.35, 1.2, dur], [135, 160, 150, 118])
    f1 = np.interp(t, [0, 0.3, 1.3, dur], [320, 650, 600, 340])  # "mmm" -> "ööö" ağız açılması
    phase = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(len(t))
    for k in range(1, 26):
        hk = f0 * k
        formant = np.exp(-((hk - f1) / 220) ** 2) + 0.35 * np.exp(-((hk - 1050) / 260) ** 2) + 0.15 / k
        out += formant * np.sin(k * phase) / k ** 0.3
    env = np.clip(t / 0.25, 0, 1) * np.clip((dur - t) / 0.5, 0, 1)
    out = lowpass(out * env, 1100, order=4)
    return fade_edges(linear_reverb(out, wet=0.55, seconds=1.4, damp_hz=1500), fade_out=0.3)


# ------------------------------------------------------------------ kıkırdama
def giggle_syllable(f0: float, dur: float) -> np.ndarray:
    """Formantlı tek bir "hi" hecesi: kısa nefes sesi + "i/e" ünlüsü, perdesi hafifçe iner."""
    t = times(dur)
    pitch = f0 * np.interp(t, [0, dur], [1.04, 0.94])
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    voice = np.zeros(len(t))
    for k in range(1, 12):
        hk = pitch * k
        formant = (np.exp(-((hk - 480) / 160) ** 2) + 0.55 * np.exp(-((hk - 2300) / 300) ** 2)
                   + 0.25 * np.exp(-((hk - 3000) / 350) ** 2))
        voice += formant * np.sin(k * phase)
    voice *= np.clip((t - 0.018) / 0.012, 0, 1) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    breath = sosfilt(butter(2, [1200, 3800], "band", fs=SR, output="sos"), rng.standard_normal(len(t)))
    breath *= 0.08 * np.exp(-t / 0.02)
    return voice / 4 + breath


def make_giggle() -> np.ndarray:
    parts = []
    for i, (f0, gain) in enumerate(((640, 1.0), (610, 0.92), (585, 0.82), (560, 0.68))):
        parts.append((giggle_syllable(f0, 0.085) * gain, 0.055 if i else 0.0))
    return fade_edges(linear_reverb(lowpass(sequence(parts), 4500), wet=0.1, seconds=0.3))


# ------------------------------------------------------------------ tarla
def make_hoe_chop() -> np.ndarray:
    """Çapanın toprağa girişi: boğuk bir "tok", ardından toprak hışırtısı ("hışt") ve dökülen kesekler."""
    t = times(0.3)
    thump_hz = np.interp(t, [0, 0.06], [150, 70])
    thump = np.sin(2 * np.pi * np.cumsum(thump_hz) / SR) * np.exp(-t / 0.035)
    scrape = sosfilt(butter(2, [700, 3600], "band", fs=SR, output="sos"), rng.standard_normal(len(t)))
    scrape *= np.clip(t / 0.008, 0, 1) * np.exp(-t / 0.07)
    scrape /= np.max(np.abs(scrape))
    crumbs = np.zeros(len(t))
    for i, start in enumerate(np.sort(rng.uniform(0.06, 0.22, 5))):
        n = int(0.008 * SR)
        k = int(start * SR)
        grain = sosfilt(butter(2, 1500, "high", fs=SR, output="sos"), rng.standard_normal(n)) * np.hanning(n)
        crumbs[k: k + n] += grain * 0.3 * (1 - i / 6)
    out = thump + 0.7 * scrape + crumbs
    return fade_edges(lowpass(out, 6000), fade_out=0.06)


def make_plot_ready() -> np.ndarray:
    """Parsel hazır: yukarı çıkan üç notalı müzik kutusu arpeji (Sol-Do-Mi, müzikle aynı Do majör)."""
    step = 0.09
    notes = ((79, 0.8), (84, 0.9), (88, 1.0))
    buf = np.zeros(int((step * len(notes) + 1.9) * SR))
    for i, (m, gain) in enumerate(notes):
        sig = music_box(midi_hz(m), 0.6)
        k = int(i * step * SR)
        buf[k: k + len(sig)] += gain * sig
    return fade_edges(linear_reverb(lowpass(buf, 6000), wet=0.2, seconds=0.6), fade_out=0.3)


def main() -> None:
    write("music/home_theme.ogg", make_music())
    write("ambience/wind_loop.ogg", make_wind())
    for i, b in enumerate(make_birds(), 1):
        write(f"ambience/bird_chirp_{i}.ogg", b)
    write("ambience/distant_cow.ogg", make_distant_cow())
    write("sfx/giggle.ogg", make_giggle())
    # Yeni sesler hep sona eklenir: rastgele sayı sırası değişmesin, eski sesler birebir aynı kalsın.
    write("sfx/hoe_chop.ogg", make_hoe_chop())
    write("sfx/plot_ready.ogg", make_plot_ready())


if __name__ == "__main__":
    main()
