# video_splitter_quality.py
import os
import subprocess
import argparse
import time
import sys
import signal
import json
import re

# --- CONFIGURATION FOR HIGH-QUALITY CHUNKS ---
CONFIG = {
    "output_folder_default": "/files/video_chunks", # New folder for High Quality chunks
    "output_filename_prefix": "chunk_",
    "chunk_duration_minutes_default": 3, # Shorter chunks are easier to manage
    "ffmpeg_priority_default": 18,
    "ffmpeg_stall_timeout": 300, # 5 minutes stall detection

    # --- KEY QUALITY SETTINGS FOR YOUTUBE ---
    # Standardize all source video to this format for consistency
    "target_width": 1280,   # Standard HD width
    "target_height": 720,   # Standard HD height
    "target_fps": 40,       # Your desired FPS
    "libx264_preset": "veryfast", # Best balance of speed and quality for a master file
    "libx264_crf": "22",      # Lower CRF = higher quality. 22 is great for uploads.
}

ffmpeg_process = None

def ensure_output_folder_exists(output_folder):
    os.makedirs(output_folder, exist_ok=True)

def split_and_reencode_to_quality_chunks(input_video_path, output_folder, chunk_minutes):
    """
    This is the core function. It splits the source video into high-quality,
    standardized chunks. This is the main CPU-intensive step.
    """
    global ffmpeg_process
    chunk_duration_seconds = chunk_minutes * 60
    
    base_name = os.path.splitext(os.path.basename(input_video_path))[0]
    sanitized_base_name = "".join(c if c.isalnum() or c in ('_', '-') else '_' for c in base_name)
    
    output_pattern = os.path.join(output_folder, f"{CONFIG['output_filename_prefix']}{sanitized_base_name}_%03d.mp4")
    
    sys.stderr.write(f"Starting high-quality split & re-encode for: {input_video_path}\n")
    sys.stderr.write(f"Output chunks will be ~{chunk_minutes} minutes long.\n")
    
    cmd = [
        'ffmpeg', '-y', '-nostdin', '-i', input_video_path,
        '-vf', f"scale={CONFIG['target_width']}:{CONFIG['target_height']}:flags=lanczos,fps={CONFIG['target_fps']}",
        '-c:v', 'libx264',
        '-preset', CONFIG['libx264_preset'],
        '-crf', CONFIG['libx264_crf'],
        '-pix_fmt', 'yuv420p',
        '-an',
        '-f', 'segment',
        '-segment_time', str(chunk_duration_seconds),
        '-reset_timestamps', '1',
        '-movflags', '+faststart',
        output_pattern
    ]

    sys.stderr.write(f"Executing QUALITY CHUNKING FFmpeg command...\n{' '.join(cmd)}\n")

    try:
        ffmpeg_process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, universal_newlines=True)
        
        last_progress_update = time.time()
        for line in iter(ffmpeg_process.stderr.readline, ''):
            sys.stderr.write(line) # Real-time logging
            if 'frame=' in line: last_progress_update = time.time()
            if time.time() - last_progress_update > CONFIG["ffmpeg_stall_timeout"]:
                sys.stderr.write(f"--- FFMPEG STALL DETECTED! Terminating. ---\n")
                ffmpeg_process.terminate(); time.sleep(1); ffmpeg_process.kill()
                return False

        ffmpeg_process.wait()
        if ffmpeg_process.returncode != 0:
             sys.stderr.write(f"FFmpeg finished with non-zero exit code: {ffmpeg_process.returncode}\n")
             return False
        return True
    except Exception as e:
        sys.stderr.write(f"An error occurred during chunking: {e}\n")
        if ffmpeg_process and ffmpeg_process.poll() is None: ffmpeg_process.kill()
        return False
    finally:
        ffmpeg_process = None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="High-Quality Video Splitting Script for pre-processing.")
    parser.add_argument("--video", required=True, help="Path to the source video file to be chunked.")
    parser.add_argument("--chunk-minutes", type=int, default=CONFIG["chunk_duration_minutes_default"], help="Chunk duration in minutes.")
    parser.add_argument("--output-folder", type=str, default=CONFIG["output_folder_default"], help="Folder to save high-quality chunks.")
    
    ARGS = parser.parse_args()

    def signal_handler(sig, frame):
        sys.stderr.write(f"\nSignal {sig} received, terminating FFmpeg...\n")
        if ffmpeg_process:
            ffmpeg_process.terminate(); time.sleep(1); ffmpeg_process.kill()
            sys.stderr.write("FFmpeg process terminated.\n")
        sys.exit(1)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    start_time_total = time.time()
    ensure_output_folder_exists(ARGS.output_folder)
    success = split_and_reencode_to_quality_chunks(ARGS.video, ARGS.output_folder, ARGS.chunk_minutes)
    end_time_total = time.time()

    if success:
        sys.stderr.write(f"\nSuccessfully created high-quality chunks in {end_time_total - start_time_total:.2f}s.\n")
    else:
        sys.stderr.write("\nFailed to create high-quality chunks.\n")
        sys.exit(1)