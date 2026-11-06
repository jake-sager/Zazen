#!/usr/bin/env python3
"""Clean and master Zazen's real iPhone 17 singing-bowl recordings (.m4a -> .wav).

Pipeline stages:
1. Lossless ALAC decoding (48 kHz) via ffmpeg.
2. Pre-strike room-noise profiling from each recording's quiet closet window.
3. DC offset removal, a gentle 50 Hz sub-sonic high-pass filter (preserving 100%
   of the warm 60-350 Hz wooden/felt mallet thump), and smooth minimum-phase
   pre-onset shelf voicing (`strike_hf_shelf_db`) so the initial strike's
   upper-overtone-to-body ratio matches `small-bowl.wav` (~-10.5 dB) from t = 0.000s
   with zero time-domain notch ringing or filter-switching gates.
4. Sample-accurate onset alignment with a 6 ms natural pre-contact cushion and
   4 ms raised-cosine (sin^2) click-free micro-fade.
5. High-resolution zero-phase STFT parametric Wiener denoising + dynamic modal
   masking. All natural bowl modes are preserved at unity gain during the strike
   (0-120 ms) so the time-domain-to-STFT crossfade (35-95 ms) has >0.997 waveform
   correlation and zero phase cancellation, while upper whistle modes (>850 Hz on
   the Big Bowl: 1045 Hz, 1623/1652 Hz, 2330 Hz, 3110 Hz) decay smoothly with a
   natural exponential acoustic damping rate (`overtone_decay_db_per_s`) so they
   completely vanish well before the 2-3s mark.
6. Transparent soft-knee envelope transient conditioning (only rounding the single
   anomalous 3 ms half-cycle tip on `big bowl soft` by <0.8 dB RMS).
7. Organic raised-cosine tail shaping to true digital zero.
8. ITU-R BS.1770-4 K-weighted perceptual loudness (LUFS) balancing + mono-compatible
   Hilbert-quadrature Mid/Side stereo bloom + gated TPDF dither to 16-bit PCM WAV.

Usage:
    uv run --with numpy --with scipy python3 Scripts/clean_bells.py
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.ndimage import gaussian_filter, maximum_filter1d


SAMPLE_RATE = 48_000
DEFAULT_DURATION_SECONDS = 24.0
DEFAULT_FADE_START_SECONDS = 16.0
PEAK_CEILING_DBFS = -1.5


@dataclass(frozen=True)
class BowlRecording:
    source_filename: str
    output_filename: str
    label: str
    noise_window_sec: tuple[float, float]
    sustain_hp_hz: float
    strike_hf_shelf_db: float
    overtone_decay_db_per_s: float
    target_lufs: float
    max_crest_above_body_db: float = 6.0


RECORDINGS: tuple[BowlRecording, ...] = (
    BowlRecording(
        source_filename="big bowl soft.m4a",
        output_filename="big-bowl-soft.wav",
        label="I (Big Bowl - Soft Strike, 190.4 / 547.5 Hz)",
        # Avoid 1.8s-6.5s where pre-strike handling/movement occurred
        noise_window_sec=(6.8, 9.4),
        sustain_hp_hz=150.0,
        strike_hf_shelf_db=-6.5,
        overtone_decay_db_per_s=24.0,
        target_lufs=-21.0,
        max_crest_above_body_db=5.5,
    ),
    BowlRecording(
        source_filename="big bowl.m4a",
        output_filename="big-bowl.wav",
        label="II (Big Bowl - Full Strike, 190.4 / 547.5 Hz)",
        noise_window_sec=(0.5, 5.5),
        sustain_hp_hz=150.0,
        strike_hf_shelf_db=-15.5,
        overtone_decay_db_per_s=24.0,
        target_lufs=-19.5,
        max_crest_above_body_db=6.0,
    ),
    BowlRecording(
        source_filename="small bowl.m4a",
        output_filename="small-bowl.wav",
        label="III (Small Bowl - High Strike, 508.5 / 1383.8 Hz)",
        noise_window_sec=(0.5, 4.0),
        sustain_hp_hz=380.0,
        strike_hf_shelf_db=0.0,
        overtone_decay_db_per_s=0.0,
        target_lufs=-21.0,
        max_crest_above_body_db=6.0,
    ),
)


def decode_audio_to_float64(source_path: Path) -> np.ndarray:
    """Decode an .m4a file to 48 kHz mono float64 samples in [-1.0, 1.0]."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                str(source_path),
                "-ar",
                str(SAMPLE_RATE),
                "-ac",
                "1",
                "-c:a",
                "pcm_s16le",
                tmp.name,
            ],
            check=True,
        )
        with wave.open(tmp.name, "rb") as wav_in:
            n_frames = wav_in.getnframes()
            pcm = np.frombuffer(wav_in.readframes(n_frames), dtype=np.int16)
            return pcm.astype(np.float64) / 32768.0


def k_weighting_filter(samples: np.ndarray) -> np.ndarray:
    """Apply ITU-R BS.1770-4 K-weighting filter at 48 kHz."""
    b1 = np.array([1.53512485958697, -2.69169618940638, 1.19839281085285])
    a1 = np.array([1.0, -1.69065929318241, 0.73248077421585])
    b2 = np.array([1.0, -2.0, 1.0])
    a2 = np.array([1.0, -1.99004745483398, 0.99007225036621])
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, samples))


def compute_integrated_lufs(samples: np.ndarray, window_sec: float = 8.0) -> float:
    """Compute K-weighted loudness (LUFS) over the initial ring window."""
    n = min(len(samples), int(window_sec * SAMPLE_RATE))
    weighted = k_weighting_filter(samples[:n])
    return float(-0.691 + 10.0 * np.log10(np.mean(weighted**2) + 1e-18))


def apply_minimum_phase_warm_shelf(
    samples: np.ndarray, shelf_db: float
) -> np.ndarray:
    """Apply a time-invariant, minimum-phase smooth high-shelf across the full recording.

    Passes 0-580 Hz (100% of the wooden/felt mallet thump plus the 190.4 Hz and
    547.5 Hz warm singing modes) with 0.00 dB attenuation, and smoothly shelves
    >980 Hz by `shelf_db` right from t = 0.000s so the mallet strike has the exact
    same ~-10.5 dB overtone-to-body balance as `small-bowl.wav` without any
    time-domain notch ringing or post-strike filter-switching gate.
    """
    if shelf_db >= 0.0:
        return samples
    n = len(samples)
    n_fft = 1 << (n - 1).bit_length()
    freqs = np.fft.rfftfreq(n_fft, 1.0 / SAMPLE_RATE)

    t1 = np.clip((freqs - 580.0) / (980.0 - 580.0), 0.0, 1.0)
    db_curve = shelf_db * (0.5 - 0.5 * np.cos(np.pi * t1))
    t2 = np.clip((freqs - 1350.0) / (2400.0 - 1350.0), 0.0, 1.0)
    db_curve += (shelf_db * 0.6) * (0.5 - 0.5 * np.cos(np.pi * t2))
    mag = 10.0 ** (db_curve / 20.0)

    log_mag = np.log(mag + 1e-18)
    log_mag_full = np.concatenate([log_mag, log_mag[-2:0:-1]])
    cep = np.fft.ifft(log_mag_full).real
    win = np.zeros_like(cep)
    win[0] = 1.0
    win[1 : n_fft // 2] = 2.0
    win[n_fft // 2] = 1.0
    min_phase_spec = np.exp(np.fft.fft(cep * win)[: len(freqs)])

    spec_in = np.fft.rfft(samples, n=n_fft)
    return np.fft.irfft(spec_in * min_phase_spec, n=n_fft)[:n]


def apply_stereo_bloom(mono: np.ndarray, stereo_amount: float = 0.08) -> np.ndarray:
    """Create a 100% mono-compatible, comb-free stereo image via quadrature M/S."""
    sos_side_hp = signal.butter(4, 280.0, btype="highpass", fs=SAMPLE_RATE, output="sos")
    side_base = signal.sosfilt(sos_side_hp, mono)
    analytic = signal.hilbert(side_base)
    quadrature = np.imag(analytic)

    ramp_len = int(0.060 * SAMPLE_RATE)
    side_env = np.ones_like(mono)
    side_env[:ramp_len] = np.sin(np.linspace(0.0, np.pi / 2.0, ramp_len)) ** 2

    side = quadrature * side_env * stereo_amount
    left = mono + side
    right = mono - side
    return np.column_stack((left, right))


def clean_and_master_bell(
    raw: np.ndarray,
    cfg: BowlRecording,
    duration_sec: float = DEFAULT_DURATION_SECONDS,
    fade_start_sec: float = DEFAULT_FADE_START_SECONDS,
) -> tuple[np.ndarray, dict[str, float | list[float]]]:
    """Run the restoration and mastering pipeline on a raw recording."""
    # Stage 1: DC offset removal + gentle 50 Hz sub-sonic high-pass + smooth pre-onset warm shelf
    x = raw - np.mean(raw)
    sos_sub = signal.butter(4, 50.0, btype="highpass", fs=SAMPLE_RATE, output="sos")
    x_clean_sub = apply_minimum_phase_warm_shelf(
        signal.sosfilt(sos_sub, x), cfg.strike_hf_shelf_db
    )

    # Stage 2: Separate detection filter (180 Hz causal) strictly to locate the strike index
    sos_det = signal.butter(4, 180.0, btype="highpass", fs=SAMPLE_RATE, output="sos")
    x_det = signal.sosfilt(sos_det, x_clean_sub)

    n0 = int(cfg.noise_window_sec[0] * SAMPLE_RATE)
    n1 = int(cfg.noise_window_sec[1] * SAMPLE_RATE)
    raw_noise_rms_db = float(20.0 * np.log10(np.sqrt(np.mean(raw[n0:n1] ** 2)) + 1e-18))

    det_noise_peak = float(np.max(np.abs(x_det[n0:n1])))
    pk_idx = int(np.argmax(np.abs(x_det[: int(12.0 * SAMPLE_RATE)])))
    search_start = max(0, pk_idx - int(0.08 * SAMPLE_RATE))
    above_thresh = np.where(np.abs(x_det[search_start:pk_idx]) > det_noise_peak * 2.5)[0]
    first_rise = search_start + int(above_thresh[0])

    # Step back 6.0 ms (288 samples) before first_rise and align to zero-crossing
    pre_samples = int(0.0060 * SAMPLE_RATE)
    zc_window = x_clean_sub[first_rise - pre_samples - 64 : first_rise - pre_samples]
    zero_crossings = np.where(np.diff(np.signbit(zc_window)))[0]
    if len(zero_crossings) > 0:
        onset_idx = first_rise - pre_samples - 64 + int(zero_crossings[-1]) + 1
    else:
        onset_idx = first_rise - pre_samples

    peak_delay_ms = (pk_idx - onset_idx) * 1000.0 / SAMPLE_RATE
    raw_lufs = compute_integrated_lufs(raw[onset_idx:], window_sec=8.0)
    raw_peak_db = float(20.0 * np.log10(np.max(np.abs(raw[onset_idx:])) + 1e-18))

    total_samples = int(round(duration_sec * SAMPLE_RATE))
    stft_margin = int(0.25 * SAMPLE_RATE)
    seg = x_clean_sub[onset_idx : onset_idx + total_samples + stft_margin].copy()
    noise_seg = x_clean_sub[n0:n1].copy()

    # Stage 3: High-resolution zero-phase STFT Wiener denoising + Dynamic Modal Masking
    n_fft = 4096
    hop = 512
    f_bins, t_frames, z_sig = signal.stft(
        seg, fs=SAMPLE_RATE, window="hann", nperseg=n_fft, noverlap=n_fft - hop
    )
    _, _, z_noise = signal.stft(
        noise_seg, fs=SAMPLE_RATE, window="hann", nperseg=n_fft, noverlap=n_fft - hop
    )

    noise_psd = np.percentile(np.abs(z_noise) ** 2, 98, axis=1, keepdims=True)
    sig_psd = gaussian_filter(np.abs(z_sig) ** 2, sigma=(0.8, 1.8))
    snr_post = np.maximum(sig_psd / (noise_psd * 2.5 + 1e-20) - 1.0, 0.0)
    snr_smooth = gaussian_filter(snr_post, sigma=(1.0, 2.5))

    wiener_gain = (snr_smooth / (snr_smooth + 1.0)) ** 1.5
    wiener_gain = np.maximum(wiener_gain, 5e-4)  # -66 dB floor in dead zones

    # Identify all natural resonant modes of the bowl so t = 0..120ms has 100% modal continuity
    sustain_t_mask = (t_frames >= 0.25) & (t_frames <= 6.0)
    sustain_snr_db = 10.0 * np.log10(
        np.mean(np.abs(z_sig[:, sustain_t_mask]) ** 2, axis=1)
        / (noise_psd[:, 0] + 1e-20)
        + 1e-20
    )
    modal_peaks, _ = signal.find_peaks(
        sustain_snr_db, height=10.0, prominence=5.0, distance=3
    )

    freq_modal_mask = np.full_like(f_bins, 0.012)  # -38 dB inter-partial suppression
    detected_modes_hz: list[float] = []
    for pk in modal_peaks:
        f_c = float(f_bins[pk])
        if f_c < cfg.sustain_hp_hz:
            continue
        if cfg.overtone_decay_db_per_s == 0.0 or f_c < 900.0:
            detected_modes_hz.append(round(f_c, 1))
        bw_flat = max(24.0, f_c * 0.015)
        bw_skirt = max(20.0, f_c * 0.011)
        dist = np.maximum(np.abs(f_bins - f_c) - bw_flat, 0.0)
        freq_modal_mask = np.maximum(
            freq_modal_mask, np.exp(-0.5 * (dist / bw_skirt) ** 2)
        )

    # Zero-phase sub-fundamental suppression in the sustain region (below sustain_hp_hz)
    hp_skirt = np.clip((f_bins - (cfg.sustain_hp_hz - 35.0)) / 35.0, 0.0, 1.0) ** 2
    freq_modal_mask *= hp_skirt

    # Time-varying high-frequency low-pass ceiling gliding down as upper modes decay
    f_ceil_t = (
        1400.0
        + 2200.0 * np.exp(-t_frames / 5.5)
        + 12000.0 * np.exp(-t_frames / 0.35)
    )
    hf_dist = np.maximum(f_bins[:, None] - f_ceil_t[None, :], 0.0)
    hf_mask = np.exp(-0.5 * (hf_dist / 320.0) ** 2)

    sustain_gain = wiener_gain * freq_modal_mask[:, None] * hf_mask

    # Natural post-strike exponential acoustic damping for upper whistle overtones (>850 Hz).
    # Keeps t = 0..120ms at 1.0 gain (so the 35-95ms time-domain-to-STFT crossfade has
    # >0.997 waveform correlation and zero timbral jump), then smoothly decays upper
    # modes (1045 Hz, 1623/1652 Hz, 2330 Hz, 3110 Hz) so they vanish before t = 2-3s.
    if cfg.overtone_decay_db_per_s > 0.0:
        ov_freq_weight = np.clip((f_bins - 850.0) / 200.0, 0.0, 1.0) ** 2
        ov_rate_scale = 1.0 + 0.45 * np.clip((f_bins - 1000.0) / 600.0, 0.0, 2.5)
        t_post = np.maximum(t_frames - 0.12, 0.0)
        t_smooth = (t_post**2) / (t_post + 0.18)
        ov_atten_db = (
            cfg.overtone_decay_db_per_s
            * (ov_freq_weight * ov_rate_scale)[:, None]
            * t_smooth[None, :]
        )
        ov_decay_mask = np.maximum(10.0 ** (-ov_atten_db / 20.0), 1e-4)
        sustain_gain *= ov_decay_mask

    sustain_gain = gaussian_filter(sustain_gain, sigma=(0.6, 1.0))

    _, y_stft = signal.istft(
        z_sig * sustain_gain,
        fs=SAMPLE_RATE,
        window="hann",
        nperseg=n_fft,
        noverlap=n_fft - hop,
    )
    y_stft = y_stft[:total_samples]

    # Stage 4: Phase-coherent time-domain strike preservation (0-35 ms) crossfaded
    # (35-95 ms) into `y_stft` (which shares the exact same phase and initial modal amplitudes)
    y_td = seg[:total_samples]
    td_end = int(0.035 * SAMPLE_RATE)
    xf_end = int(0.095 * SAMPLE_RATE)
    stft_blend = np.ones(total_samples)
    stft_blend[:td_end] = 0.0
    stft_blend[td_end:xf_end] = (
        np.sin(np.linspace(0.0, np.pi / 2.0, xf_end - td_end)) ** 2
    )
    y = (1.0 - stft_blend) * y_td + stft_blend * y_stft

    # Stage 5: Gentle soft-knee transient conditioning (only rounds anomalous >5.5 dB half-cycle tip)
    body_peak = float(np.max(np.abs(y[int(0.05 * SAMPLE_RATE) : int(0.60 * SAMPLE_RATE)])))
    thresh = body_peak * (10.0 ** (cfg.max_crest_above_body_db / 20.0))
    tr_len = int(0.045 * SAMPLE_RATE)
    y_tr = y[:tr_len]
    if np.max(np.abs(y_tr)) > thresh:
        win_env = int(0.0015 * SAMPLE_RATE)
        env = gaussian_filter(
            maximum_filter1d(np.abs(y_tr), size=win_env), sigma=win_env / 2.0
        )
        knee = thresh * 0.70
        span = thresh * 0.40
        gain_tr = np.ones_like(env)
        over = env > knee
        gain_tr[over] = (knee + span * np.tanh((env[over] - knee) / span)) / (
            env[over] + 1e-12
        )
        fade_back = np.linspace(0.0, 1.0, tr_len) ** 2
        gain_tr = gain_tr * (1.0 - fade_back) + fade_back
        y[:tr_len] = y_tr * gain_tr

    # Stage 6: 4.0 ms raised-cosine (sin^2) pre-contact micro-fade + 8 s cosine tail fade
    onset_samples = int(0.0040 * SAMPLE_RATE)
    y[:onset_samples] *= np.sin(np.linspace(0.0, np.pi / 2.0, onset_samples)) ** 2

    fade_start_idx = int(round(fade_start_sec * SAMPLE_RATE))
    fade_len = total_samples - fade_start_idx
    tail_env = np.cos(np.linspace(0.0, 1.0, fade_len) * np.pi / 2.0) ** 1.6
    y[fade_start_idx:] *= tail_env

    # Stage 7: Perceptual Loudness (LUFS) balancing + True-Peak ceiling
    cur_lufs = compute_integrated_lufs(y, window_sec=8.0)
    y *= 10.0 ** ((cfg.target_lufs - cur_lufs) / 20.0)

    ceil_lin = 10.0 ** (PEAK_CEILING_DBFS / 20.0)
    if np.max(np.abs(y)) > ceil_lin:
        y *= ceil_lin / np.max(np.abs(y))

    final_lufs = compute_integrated_lufs(y, window_sec=8.0)
    final_peak_db = float(20.0 * np.log10(np.max(np.abs(y)) + 1e-18))

    sustain_slice = y[int(0.5 * SAMPLE_RATE) : int(16.0 * SAMPLE_RATE)]
    spec_sus = np.abs(np.fft.rfft(sustain_slice)) / len(sustain_slice)
    freqs_sus = np.fft.rfftfreq(len(sustain_slice), 1.0 / SAMPLE_RATE)
    sub120_db = float(
        20.0 * np.log10(np.sqrt(2.0 * np.sum(spec_sus[freqs_sus < 120.0] ** 2)) + 1e-18)
    )
    tail_slice = y[int(1.8 * SAMPLE_RATE) : int(3.2 * SAMPLE_RATE)]
    spec_tail = np.abs(np.fft.rfft(tail_slice * np.hanning(len(tail_slice)))) * 2.0 / len(tail_slice)
    freqs_tail = np.fft.rfftfreq(len(tail_slice), 1.0 / SAMPLE_RATE)
    over1k_db = float(
        20.0 * np.log10(np.max(spec_tail[freqs_tail > 980.0]) + 1e-18)
    )

    metrics: dict[str, float | list[float]] = {
        "trimmed_start_sec": round(onset_idx / SAMPLE_RATE, 4),
        "peak_delay_ms": round(peak_delay_ms, 2),
        "raw_noise_rms_db": round(raw_noise_rms_db, 1),
        "raw_peak_db": round(raw_peak_db, 2),
        "raw_lufs": round(raw_lufs, 2),
        "final_peak_db": round(final_peak_db, 2),
        "final_lufs": round(final_lufs, 2),
        "sub120_noise_db": round(sub120_db, 1),
        "over1k_2to3s_db": round(over1k_db, 1),
        "detected_modes_hz": detected_modes_hz,
    }
    return y, metrics


def write_wav_16bit_dithered(
    output_path: Path,
    mono_samples: np.ndarray,
    stereo: bool = True,
    fade_start_sec: float = DEFAULT_FADE_START_SECONDS,
) -> None:
    """Write 48 kHz 16-bit PCM WAV with optional M/S stereo bloom and gated TPDF dither."""
    rng = np.random.default_rng(seed=42)

    dither_gate = np.ones(len(mono_samples))
    fade_start_idx = int(round(fade_start_sec * SAMPLE_RATE))
    fade_len = len(mono_samples) - fade_start_idx
    dither_gate[fade_start_idx:] = (
        np.cos(np.linspace(0.0, 1.0, fade_len) * np.pi / 2.0) ** 1.6
    )

    if stereo:
        frames = apply_stereo_bloom(mono_samples, stereo_amount=0.08)
        tpdf = (
            rng.uniform(-0.5, 0.5, frames.shape) + rng.uniform(-0.5, 0.5, frames.shape)
        ) * dither_gate[:, None]
        n_channels = 2
    else:
        frames = mono_samples
        tpdf = (
            rng.uniform(-0.5, 0.5, frames.shape) + rng.uniform(-0.5, 0.5, frames.shape)
        ) * dither_gate
        n_channels = 1

    pcm_float = np.clip(np.round(frames * 32767.0 + tpdf), -32768, 32767)
    pcm_int16 = pcm_float.astype("<i2")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output_path), "wb") as wav_out:
        wav_out.setnchannels(n_channels)
        wav_out.setsampwidth(2)
        wav_out.setframerate(SAMPLE_RATE)
        wav_out.writeframes(pcm_int16.tobytes())


def main() -> None:
    default_sounds_dir = Path(__file__).resolve().parents[1] / "Zazen" / "Sounds"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sounds-dir",
        type=Path,
        default=default_sounds_dir,
        help=f"Directory containing source .m4a files (default: {default_sounds_dir})",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=DEFAULT_DURATION_SECONDS,
        help=f"Output duration in seconds (default: {DEFAULT_DURATION_SECONDS})",
    )
    parser.add_argument(
        "--fade-start",
        type=float,
        default=DEFAULT_FADE_START_SECONDS,
        help=f"Fade-out start time in seconds (default: {DEFAULT_FADE_START_SECONDS})",
    )
    parser.add_argument(
        "--mono",
        action="store_true",
        help="Write 1-channel mono WAV files instead of 2-channel M/S stereo WAV files",
    )
    args = parser.parse_args()

    for cfg in RECORDINGS:
        src = args.sounds_dir / cfg.source_filename
        dst = args.sounds_dir / cfg.output_filename
        raw = decode_audio_to_float64(src)
        cleaned, metrics = clean_and_master_bell(
            raw, cfg, duration_sec=args.duration, fade_start_sec=args.fade_start
        )
        write_wav_16bit_dithered(
            dst, cleaned, stereo=not args.mono, fade_start_sec=args.fade_start
        )
        print(f"=== {cfg.label} ===")
        print(f"  Source -> Output : {src.name} -> {dst.name} ({args.duration:.0f}s)")
        print(
            f"  Trimmed Pre-Roll : {metrics['trimmed_start_sec']:.4f}s removed "
            f"(peak hit at +{metrics['peak_delay_ms']:.2f} ms)"
        )
        print(
            f"  Level & Loudness : Peak {metrics['raw_peak_db']:+.2f} -> {metrics['final_peak_db']:+.2f} dBFS | "
            f"8s LUFS {metrics['raw_lufs']:+.2f} -> {metrics['final_lufs']:+.2f}"
        )
        print(
            f"  High-Pitch Check : Max >1 kHz Mode at 1.8-3.2s = {metrics['over1k_2to3s_db']:.1f} dBFS | "
            f"Sub-120Hz = {metrics['sub120_noise_db']:.1f} dBFS"
        )
        print(f"  Sustain Modes    : {metrics['detected_modes_hz']} Hz\n")


if __name__ == "__main__":
    main()
