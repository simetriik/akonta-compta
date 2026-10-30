#!/usr/bin/env python3
"""Assemble la vidéo de recette Akonta à partir d'un manifeste JSON.

Chaque segment porte un titre et une suite de « temps » (une phrase de narration, une capture
d'écran PNG ou une carte-titre). La narration est synthétisée avec piper (voix française
hors ligne), les captures sont agrandies dans un cadre 1920×1080 avec un bandeau de sous-titres,
puis les séquences sont concaténées avec ffmpeg.

Usage : python3 make_video.py manifest.json akonta-recette.mp4
Pré-requis : ffmpeg, piper (uv tool install piper-tts) et la voix fr_FR-siwis-medium dans ~/.local/share/piper.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FRAMES = ROOT / "frames-v2"
WORK = ROOT / "build"
VOICE = Path.home() / ".local/share/piper/fr_FR-siwis-medium.onnx"
FONT_TEXT = "/usr/local/share/fonts/google-fonts/ofl/notosans/NotoSans[wdth,wght].ttf"
FONT_TITLE = "/usr/local/share/fonts/google-fonts/ofl/poppins/Poppins-SemiBold.ttf"
LOGO = ROOT / "logo-horizontal.png"  # SVG du système de design (app/assets/logo/akonta-logo-horizontal.svg), rasterisé
W, H, FPS = 1920, 1080, 25
# Identité bleu nuit : fond neutre bleuté, encre bleu nuit, texte atténué (l'orange, couleur d'action, reste réservé au logo).
SAND, INK, TERRACOTTA = "0xF5F6F8", "0x1E2A5A", "0x5A6274"
MIN_BEAT = 3.0      # durée minimale d'un temps (s)
PAUSE = 0.7         # silence après chaque phrase (s)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True, capture_output=True)


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         check=True, capture_output=True, text=True).stdout.strip()
    return float(out)


def speak(text: str, wav: Path) -> float:
    """Synthétise la phrase et renvoie sa durée, silence de fin inclus."""
    subprocess.run(["piper", "--model", str(VOICE), "--output_file", str(wav), "--sentence_silence", "0.4"],
                   input=text, text=True, check=True, capture_output=True)
    return duration(wav) + PAUSE


def escape(text: str) -> str:
    """Échappe le texte pour drawtext (deux-points, apostrophes, pourcentages)."""
    return text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace("%", "%%")


def caption_file(text: str, path: Path) -> Path:
    path.write_text("\n".join(textwrap.wrap(text, 88)[:3]))
    return path


def title_card(title: str, subtitle: str, secs: float, out: Path) -> None:
    """Carte-titre : fond neutre, logo, titre Poppins, sous-titre."""
    vf = (
        f"[1:v]scale=720:-1[logo];[0:v][logo]overlay=(W-w)/2:300[b];"
        f"[b]drawtext=fontfile='{FONT_TITLE}':text='{escape(title)}':fontsize=64:fontcolor={INK}:x=(w-text_w)/2:y=600,"
        f"drawtext=fontfile='{FONT_TEXT}':text='{escape(subtitle)}':fontsize=34:fontcolor={TERRACOTTA}:x=(w-text_w)/2:y=700"
    )
    run(["ffmpeg", "-y", "-f", "lavfi", "-i", f"color=c={SAND}:s={W}x{H}:r={FPS}:d={secs:.2f}", "-i", str(LOGO),
         "-filter_complex", vf, "-t", f"{secs:.2f}", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an", str(out)])


def screen_clip(frame: Path, caption: Path, step: str, secs: float, out: Path) -> None:
    """Capture agrandie et centrée sur fond sable, bandeau de sous-titre, repère d'étape en haut."""
    vf = (
        f"scale=-2:{H - 210}:flags=lanczos,pad={W}:{H}:(ow-iw)/2:44:color={SAND},"
        f"drawtext=fontfile='{FONT_TITLE}':text='{escape(step)}':fontsize=26:fontcolor={TERRACOTTA}:x=(w-text_w)/2:y=8,"
        f"drawbox=x=0:y={H - 150}:w={W}:h=150:color={INK}@0.92:t=fill,"
        f"drawtext=fontfile='{FONT_TEXT}':textfile='{caption}':fontsize=28:fontcolor=white:line_spacing=6:text_align=C:x=(w-text_w)/2:y={H - 136}"
    )
    run(["ffmpeg", "-y", "-loop", "1", "-framerate", str(FPS), "-t", f"{secs:.2f}", "-i", str(frame),
         "-vf", vf, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an", str(out)])


def mux(video: Path, wav: Path | None, secs: float, out: Path) -> None:
    """Ajoute la piste audio (ou du silence) à la séquence, à la durée exacte du temps."""
    audio = ["-i", str(wav)] if wav else ["-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono"]
    run(["ffmpeg", "-y", "-i", str(video), *audio, "-t", f"{secs:.2f}", "-af", "apad", "-c:v", "copy",
         "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2", str(out)])


def main(manifest_path: Path, output: Path) -> None:
    manifest = json.loads(manifest_path.read_text())
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir()
    parts: list[Path] = []
    script_lines: list[str] = []
    n = 0
    total = 0.0
    for seg in manifest["segments"]:
        step = seg["title"]
        script_lines.append(f"\n## {step}\n")
        for beat in seg["beats"]:
            n += 1
            text = beat["text"]
            script_lines.append(f"- {text}")
            wav = WORK / f"{n:03d}.wav"
            secs = max(speak(text, wav), MIN_BEAT) if text else MIN_BEAT
            silent = WORK / f"{n:03d}-v.mp4"
            if beat.get("card"):
                title_card(beat["card"], beat.get("subtitle", ""), secs, silent)
            else:
                frame = FRAMES / beat["frame"]
                if not frame.exists():
                    sys.exit(f"capture manquante : {frame}")
                screen_clip(frame, caption_file(text, WORK / f"{n:03d}.txt"), step, secs, silent)
            part = WORK / f"{n:03d}.mp4"
            mux(silent, wav if text else None, secs, part)
            parts.append(part)
            total += secs
            print(f"{n:03d} {secs:5.1f}s  {step} — {text[:60]}")
    concat = WORK / "concat.txt"
    concat.write_text("".join(f"file '{p}'\n" for p in parts))
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(output)])
    (ROOT / "script-narration.md").write_text("# Script de narration — vidéo de recette Akonta\n" + "\n".join(script_lines) + "\n")
    print(f"\n{output} — {total / 60:.1f} min, {n} temps")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
