# Video Processing for YouTube Shorts

This system includes scripts to process Minecraft gameplay videos into YouTube Shorts format.

## Overview

The system consists of two main scripts:

1. **Video Splitter (`video_splitter.py`)**: Splits long videos into ~10 minute chunks
2. **Clip Cutter (`clip_cutter.py`)**: Cuts and formats shorter clips to YouTube Shorts format (vertical 9:16)

## How to Use in n8n

### Video Splitter

The video splitter can be used in the "Execute Command" node with:

```
/opt/scripts/run_splitter.sh --video /files/your-long-video.mp4
```

This will output to stdout a list of paths to the generated chunks.

### Clip Cutter

The clip cutter can be used in the "Execute Command" node with:

```
/opt/scripts/run_cutter.sh --video /files/video_chunks/chunk_file.mp4 --audio-duration 30.5
```

Where `30.5` is the duration in seconds of the audio clip you intend to use.

The output to stdout will be the path to the generated short clip.

## Example n8n Workflow

1. **Step 1**: Use "Execute Command" to split a long video into chunks
2. **Step 2**: Use "Split In Batches" to process each chunk path from the output
3. **Step 3**: For each chunk, use "Execute Command" to cut it to the desired duration
4. **Step 4**: Process the generated short clips as needed

## File Paths

- Input videos should be placed in the `/files` directory
- Chunks will be saved to `/files/video_chunks`
- Final short clips will be saved to `/files/output_shorts_clips`
- Temporary files are stored in `/files/temp_processing_clips`

These directories map to your host machine through the volume mount defined in `docker-compose.yml`.
