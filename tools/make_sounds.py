"""Generate Ticky's built-in sound files (Ticky/Sounds/*.ogg): short sine tones, Ogg Vorbis.

usage: python tools/make_sounds.py
needs: pip install numpy soundfile
"""
import pathlib

import numpy as np
import soundfile as sf

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "Ticky" / "Sounds"


def tone(name, freqs, seconds):
    t = np.linspace(0, seconds, int(RATE * seconds), endpoint=False)
    wave = sum(np.sin(2 * np.pi * f * t) for f in freqs) / len(freqs)
    envelope = np.minimum(1, np.minimum(t / 0.01, (seconds - t) / 0.08))  # no clicks
    sf.write(OUT / name, (0.6 * wave * envelope).astype("float32"), RATE, format="OGG", subtype="VORBIS")


OUT.mkdir(exist_ok=True)
tone("beep.ogg", [880], 0.25)
tone("chime.ogg", [660, 990], 0.5)
print("wrote", ", ".join(p.name for p in sorted(OUT.glob("*.ogg"))))
