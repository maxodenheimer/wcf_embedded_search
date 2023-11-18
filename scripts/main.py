import os
import openai
from pydub import AudioSegment
import time
import json

# Set the API key
openai.api_key = os.getenv("OPENAI_API_KEY")

# Load the podcast MP3 file
podcast = AudioSegment.from_mp3("../public/podcast.mp3")

# Constants for time conversion and clip length
one_min = 60 * 1000
podcast_length_seconds = len(podcast) / 1000
clip_count = int(podcast_length_seconds / 60) + 1

# List to hold clip information
clips = []

def create_clips():
    print("Creating clips...")
    # Ensure the clips directory exists
    if not os.path.exists("clips"):
        os.makedirs("clips")

    # Create the first one-minute clip
    clip = podcast[:one_min]
    clip.export("clips/1.mp3", format="mp3")
    print("Exported clip 1")
    
    # Create subsequent one-minute clips
    for i in range(1, clip_count):
        file_name = f"{i + 1}.mp3"
        start_time = i * one_min - 1000
        end_time = (i + 1) * one_min
        clip = podcast[start_time:end_time]
        clip.export(f"clips/{file_name}", format="mp3")
        print(f"Exported clip {i + 1}")

def generate_transcript():
    print("Generating transcript...")

    for i in range(clip_count):
        print(f"Transcribing clip {i + 1}...")

        with open(f"clips/{i + 1}.mp3", "rb") as audio_file:
            # Use the correct method for transcription based on the working example
            response = openai.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file
            )

        # Create a dictionary for the current clip with its data
        clip = {
            "file": f"{i + 1}.mp3",
            "seconds": i * 60,  # Calculate the timestamp
            "content": response.text
        }

        # Append the clip information to the clips list
        clips.append(clip)

        # Wait a short time before the next request
        print("Waiting 1.2s before next transcription...")
        time.sleep(1.2)

def create_json():
    print("Creating JSON...")
    with open("clips.json", "w") as f:
        json_string = json.dumps(clips, indent=2)
        f.write(json_string)

# Run the functions to create clips, generate transcriptions, and create the JSON file
create_clips()
generate_transcript()
create_json()
