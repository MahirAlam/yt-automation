# clip_cutter_final.py
import os
import random
import subprocess
import argparse
import time
import sys
import signal
import re

# --- Configuration ---
CONFIG = {
    "output_folder": "/files/output_shorts_clips",
    "chunks_folder": "/files/video_chunks", # IMPORTANT: Point to the output folder of the splitter script
    "output_filename_prefix": "parkour_short",
    
    # Heuristic for 'smart start'
    "smart_start_min_percent": 0.10,
    "smart_start_max_percent": 0.80,
    "assumed_chunk_duration_for_start_calc": 180, # Match the chunk duration from the splitter script
    
    "default_fps": 40,
    "ffmpeg_stall_timeout": 60,
    
    # --- ENCODING SETTINGS FOR FINAL CLIP ---
    # These settings are applied to a SHORT clip, so they are fast enough
    # while providing excellent quality for the final upload.
    "libx264_preset": "veryfast", 
    "libx264_crf": "22",
    
    "enable_smart_color": True,
}

# --- Global state for signal handling ---
ffmpeg_process = None

def ensure_folders_exist():
    os.makedirs(CONFIG["output_folder"], exist_ok=True)

def select_random_chunk_reservoir():
    """Selects one random .mp4 file efficiently using Reservoir Sampling."""
    try:
        chunks_folder = CONFIG["chunks_folder"]
        chosen_file = None
        count = 0
        with os.scandir(chunks_folder) as it:
            for entry in it:
                if entry.is_file() and entry.name.endswith('.mp4'):
                    count += 1
                    if random.randint(1, count) == 1:
                        try:
                            if entry.stat().st_size > 100000:
                                chosen_file = entry.path
                        except FileNotFoundError:
                            continue
        
        if chosen_file:
            sys.stderr.write(f"Efficiently selected random HQ chunk: {os.path.basename(chosen_file)}\n")
            return chosen_file
        else:
            sys.stderr.write(f"Error: No valid .mp4 files found in {chunks_folder}\n")
            return None
    except Exception as e:
        sys.stderr.write(f"An unexpected error occurred during chunk selection: {e}\n")
        return None

def main_clip_logic(audio_duration_seconds):
    global ffmpeg_process
    ensure_folders_exist()
    
    input_video_path = select_random_chunk_reservoir()
    if not input_video_path: return None

    assumed_duration = CONFIG["assumed_chunk_duration_for_start_calc"]
    if audio_duration_seconds > assumed_duration:
         sys.stderr.write(f"Error: Audio duration ({audio_duration_seconds}s) > assumed chunk duration ({assumed_duration}s).\n")
         return None

    min_start = assumed_duration * CONFIG["smart_start_min_percent"]
    max_start = assumed_duration * CONFIG["smart_start_max_percent"] - audio_duration_seconds
    if max_start <= min_start:
        max_start = max(10, assumed_duration - audio_duration_seconds - 5)
        min_start = 1
    
    start_time = random.uniform(min_start, max_start)
    clip_duration = audio_duration_seconds + 0.2
    
    sys.stderr.write(f"Source: {os.path.basename(input_video_path)}\n")
    sys.stderr.write(f"Calculated 'smart' start time: {start_time:.2f}s (Clip duration: {clip_duration:.2f}s)\n")
    
    base_name = os.path.splitext(os.path.basename(input_video_path))[0]
    output_filename = f"{CONFIG['output_filename_prefix']}{base_name}_{int(time.time())}.mp4"
    final_output_path = os.path.join(CONFIG["output_folder"], output_filename)

    vf_chain = ["crop=floor(ih*9/16/2)*2:ih"] # Crop to 9:16, ensuring even width
    if CONFIG["enable_smart_color"]:
        vf_chain.extend(["curves=preset=strong_contrast", "hue=s=1.15"])
    filter_string = ",".join(vf_chain)

    cmd = [
        'ffmpeg', '-y', '-nostdin',
        '-ss', str(start_time),
        '-i', input_video_path,
        '-t', str(clip_duration),
        '-vf', filter_string,
        '-an',
        '-c:v', 'libx264',
        '-preset', CONFIG['libx264_preset'],
        '-crf', CONFIG['libx264_crf'],
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
        final_output_path
    ]

    sys.stderr.write(f"Executing QUALITY clip command with progress monitoring...\n")
    sys.stderr.write(f"{' '.join(cmd)}\n")
    
    try:
        ffmpeg_process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, universal_newlines=True)
        
        last_progress_update = time.time()
        for line in iter(ffmpeg_process.stderr.readline, ''):
            sys.stderr.write(line)
            if 'frame=' in line:
                last_progress_update = time.time()
            if time.time() - last_progress_update > CONFIG["ffmpeg_stall_timeout"]:
                sys.stderr.write(f"\n--- FFMPEG STALL DETECTED! Terminating. ---\n")
                ffmpeg_process.terminate(); time.sleep(1); ffmpeg_process.kill()
                return None

        ffmpeg_process.wait()
        return_code = ffmpeg_process.returncode
        
        if return_code != 0:
            sys.stderr.write(f"FFmpeg finished with a non-zero exit code: {return_code}.\n")
            return None
            
        if not os.path.exists(final_output_path) or os.path.getsize(final_output_path) < 1000:
            sys.stderr.write(f"Output file missing or too small after processing.\n")
            return None

        sys.stderr.write(f"Successfully generated clip: {final_output_path}\n")
        return final_output_path
    except Exception as e:
        sys.stderr.write(f"An unexpected error occurred during FFmpeg processing: {e}\n")
        if ffmpeg_process and ffmpeg_process.poll() is None:
            ffmpeg_process.kill()
        return None
    finally:
        ffmpeg_process = None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="High-quality video clip cutter using pre-processed chunks.")
    parser.add_argument("--audio-duration", required=True, type=float, help="Desired final clip duration in seconds.")
    parser.add_argument("--smart-color", action="store_true", help="Enable smart color grading.")
    
    ARGS = parser.parse_args()
    
    if ARGS.smart_color: CONFIG["enable_smart_color"] = True

    def signal_handler(sig, frame):
        sys.stderr.write(f"\nSignal {sig} received, terminating FFmpeg...\n")
        if ffmpeg_process:
            ffmpeg_process.terminate(); time.sleep(1); ffmpeg_process.kill()
            sys.stderr.write("FFmpeg process terminated.\n")
        sys.exit(1)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    start_time_script = time.time()
    output_file_path = main_clip_logic(ARGS.audio_duration)
    end_time_script = time.time()

    if output_file_path:
        sys.stderr.write(f"\nScript finished successfully in {end_time_script - start_time_script:.2f} seconds.\n")
        print(output_file_path)
    else:
        sys.stderr.write("\nScript failed to generate a clip.\n")
        sys.exit(1)