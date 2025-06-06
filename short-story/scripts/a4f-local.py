# a4f_local_stitcher_final.py
import argparse
import os
import subprocess
import sys
import time
import random  # <-- FIX 1: IMPORT 'random' MODULE
from a4f_local import A4F

def main():
    # --- Argument Parser Setup ---
    parser = argparse.ArgumentParser(description='Generate and stitch multi-part speech using A4F')
    parser.add_argument('--text', type=str, action='append', required=True,
                        help='A part of the text to convert to speech. Use this argument multiple times for each part of the story.')
    parser.add_argument('--output', type=str, required=True,
                        help='Final output file path for the stitched audio')
    parser.add_argument('--voice', type=str, default="alloy",
                        help='Voice to use for speech generation')
    parser.add_argument('--model', type=str, default="tts-1",
                        help='Model name to use')
    
    args = parser.parse_args()
    
    # --- Directory and File Setup ---
    final_output_dir = os.path.dirname(args.output)
    temp_dir = "/files/temp_processing"
    
    os.makedirs(final_output_dir, exist_ok=True)
    os.makedirs(temp_dir, exist_ok=True)
    
    client = A4F()
    temp_audio_files = []
    
    # --- Loop Through and Generate Audio for Each Text Part ---
    for i, text_part in enumerate(args.text):
        part_num = i + 1
        sys.stderr.write(f"Generating audio for Part {part_num}/{len(args.text)}...\n")
        
        # NOTE: Even if you save with .mp3, the underlying data from a4f is WAV (PCM).
        temp_path = os.path.join(temp_dir, f"part{part_num}_{int(time.time())}_{random.randint(100,999)}.wav")
        temp_audio_files.append(temp_path)
        
        try:
            audio_bytes = client.audio.speech.create(
                model=args.model,
                input=text_part,
                voice=args.voice
            )
            with open(temp_path, "wb") as f:
                f.write(audio_bytes)
            sys.stderr.write(f"Generated Part {part_num} audio: {temp_path}\n")
        except Exception as e:
            sys.stderr.write(f"An error occurred generating Part {part_num} audio: {e}\n")
            cleanup_temp_files(temp_audio_files)
            sys.exit(1)

    if not temp_audio_files:
        sys.stderr.write("No audio parts were generated. Aborting.\n")
        sys.exit(1)

    # --- Combine All Audio Files with FFmpeg ---
    concat_list_path = os.path.join(temp_dir, f"concat_list_{int(time.time())}.txt")
    temp_files_for_cleanup = temp_audio_files + [concat_list_path]

    try:
        sys.stderr.write(f"Combining {len(args.text)} audio files into {args.output}...\n")
        
        with open(concat_list_path, 'w') as f:
            for audio_file in temp_audio_files:
                f.write(f"file '{os.path.abspath(audio_file)}'\n")
        
        # --- FIX 2: RE-ENCODE TO MP3 INSTEAD OF COPYING ---
        ffmpeg_cmd = [
            'ffmpeg',
            '-y',
            '-f', 'concat',
            '-safe', '0',
            '-i', concat_list_path,
            '-c:a', 'libmp3lame',  # Specify the MP3 encoder
            '-q:a', '2',           # Set VBR quality (0=best, 9=worst). 2 is excellent for voice.
            args.output
        ]

        sys.stderr.write(f"Executing FFmpeg command: {' '.join(ffmpeg_cmd)}\n")
        process = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, check=True)
        
        sys.stderr.write(f"Successfully stitched audio to: {args.output}\n")
        print(args.output)

    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"FFmpeg failed to combine audio files.\n")
        sys.stderr.write(f"FFmpeg stderr: {e.stderr}\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"An error occurred during audio combination: {e}\n")
        sys.exit(1)
    finally:
        # --- Clean Up All Temporary Files ---
        cleanup_temp_files(temp_files_for_cleanup)

def cleanup_temp_files(file_list):
    sys.stderr.write("Cleaning up temporary files...\n")
    for f_path in file_list:
        try:
            if os.path.exists(f_path):
                os.remove(f_path)
        except Exception as e:
            sys.stderr.write(f"Warning: Could not remove temp file {f_path}: {e}\n")

if __name__ == "__main__":
    main()