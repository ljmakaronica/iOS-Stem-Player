from flask import Flask, request, jsonify, send_file
import yt_dlp
import os
from uuid import uuid4
import subprocess
from flask_cors import CORS
import shutil
import threading
from datetime import datetime
import json
from pydub import AudioSegment

app = Flask(__name__)
CORS(app)

# Directories
OUTPUT_DIR = "output_files"
STEMS_DIR = "stems_files"
STATUS_DIR = "status_files"
COMPRESSED_DIR = "compressed_files"  # New directory for MP3s


for directory in [OUTPUT_DIR, STEMS_DIR, STATUS_DIR, COMPRESSED_DIR]:
    os.makedirs(directory, exist_ok=True)

def save_status(session_id, status, title=None):
    status_file = os.path.join(STATUS_DIR, f"{session_id}.json")
    status_data = {
        "status": status,
        "title": title,
        "timestamp": datetime.now().isoformat()
    }
    with open(status_file, 'w') as f:
        json.dump(status_data, f)



#This is used after the processing is done. iOS device recieves mp3 files instead of raw WAV files.
def convert_to_mp3(wav_path, mp3_path, bitrate='320k'):
    """
    Convert WAV to high-quality MP3
    """
    try:
        audio = AudioSegment.from_wav(wav_path)
        audio.export(mp3_path, format='mp3', parameters=["-b:a", bitrate])
        return True
    except Exception as e:
        print(f"Error converting to MP3: {str(e)}")
        return False

def process_video(youtube_url, session_id):
    try:
        # Save initial status
        save_status(session_id, "processing")
        
        # Get video title
        with yt_dlp.YoutubeDL() as ydl:
            info = ydl.extract_info(youtube_url, download=False)
            video_title = info.get('title', 'YouTube Video')
        
        # Update status with title
        save_status(session_id, "processing", video_title)
        
        # Download and convert to WAV
        output_file_base = f"{OUTPUT_DIR}/{session_id}"
        output_wav_file = f"{output_file_base}.wav"
        
        ydl_opts = {
            'format': 'bestaudio/best',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'wav',
            }],
            'outtmpl': output_file_base,
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([youtube_url])
        
        # Run Demucs
        stems_output_dir = f"{STEMS_DIR}/{session_id}"
        subprocess.run(['demucs', '-n', 'mdx_extra', output_wav_file, '-o', stems_output_dir])
        
        # Clean up original WAV file
        if os.path.exists(output_wav_file):
            os.remove(output_wav_file)
        
        # Create compressed versions directory
        compressed_dir = os.path.join(COMPRESSED_DIR, session_id)
        os.makedirs(compressed_dir, exist_ok=True)
        
        # Get path to stems
        base_stem_dir = os.path.join(stems_output_dir, 'mdx_extra')
        first_dir = os.listdir(base_stem_dir)[0]
        stem_dir = os.path.join(base_stem_dir, first_dir)
        
        # Convert each stem to MP3
        stem_types = ['vocals', 'drums', 'bass', 'other']
        for stem_type in stem_types:
            wav_path = os.path.join(stem_dir, f'{stem_type}.wav')
            mp3_path = os.path.join(compressed_dir, f'{stem_type}.mp3')
            
            if os.path.exists(wav_path):
                # Convert to high quality MP3
                convert_to_mp3(wav_path, mp3_path)
                # Remove WAV stem after successful conversion
                os.remove(wav_path)
        
        # Clean up the stems directory since we've moved everything to compressed
        shutil.rmtree(stems_output_dir)
        
        # Update status to ready
        save_status(session_id, "ready", video_title)
        
    except Exception as e:
        print(f"Error processing {session_id}: {str(e)}")
        save_status(session_id, "failed")
        




@app.route('/convert', methods=['POST'])
def convert_youtube_to_wav():
    try:
        data = request.json
        youtube_url = data.get('youtube_url')
        session_id = data.get('session_id')
        
        if not youtube_url or not session_id:
            return jsonify({"error": "YouTube URL and session ID are required"}), 400
        
        # Start processing in background
        thread = threading.Thread(
            target=process_video,
            args=(youtube_url, session_id)
        )
        thread.start()
        
        return jsonify({
            "session_id": session_id,
            "message": "Processing started"
        }), 202
        
    except Exception as e:
        print(f"Error occurred: {str(e)}")
        return jsonify({"error": str(e)}), 500



@app.route('/status/<session_id>', methods=['GET'])
def get_status(session_id):
    try:
        status_file = os.path.join(STATUS_DIR, f"{session_id}.json")
        if not os.path.exists(status_file):
            return jsonify({
                "status": "not_found",
                "error": "Session not found"
            }), 404
            
        with open(status_file, 'r') as f:
            status_data = json.load(f)
            
        return jsonify(status_data), 200
        
    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e)
        }), 500



@app.route('/download/<session_id>/<stem_type>', methods=['GET'])
def download_stem(session_id, stem_type):
    try:
        # Check if processing is complete
        status_file = os.path.join(STATUS_DIR, f"{session_id}.json")
        if not os.path.exists(status_file):
            return jsonify({"error": "Session not found"}), 404
            
        with open(status_file, 'r') as f:
            status_data = json.load(f)
            if status_data['status'] != "ready":
                return jsonify({"error": "Stems not ready yet"}), 400
        
        # Get compressed stem file
        mp3_path = os.path.join(COMPRESSED_DIR, session_id, f'{stem_type}.mp3')
        
        if not os.path.exists(mp3_path):
            return jsonify({"error": "Stem file not found"}), 404
            
        return send_file(
            mp3_path,
            mimetype='audio/mpeg',
            as_attachment=True,
            download_name=f'{stem_type}.mp3'
        )
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500



@app.route('/cleanup/<session_id>', methods=['DELETE'])
def cleanup_files(session_id):
    try:
        # Clean up output directory
        output_file = os.path.join(OUTPUT_DIR, f"{session_id}.wav")
        if os.path.exists(output_file):
            os.remove(output_file)
            
        # Clean up stems directory
        stems_dir = os.path.join(STEMS_DIR, session_id)
        if os.path.exists(stems_dir):
            shutil.rmtree(stems_dir)
            
        # Clean up compressed directory
        compressed_dir = os.path.join(COMPRESSED_DIR, session_id)
        if os.path.exists(compressed_dir):
            shutil.rmtree(compressed_dir)
            
        # Clean up status file
        status_file = os.path.join(STATUS_DIR, f"{session_id}.json")
        if os.path.exists(status_file):
            os.remove(status_file)
            
        return jsonify({"message": "Cleanup successful"}), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500




def cleanup_old_files():
    try:
        current_time = datetime.now()
        for status_file in os.listdir(STATUS_DIR):
            file_path = os.path.join(STATUS_DIR, status_file)
            with open(file_path, 'r') as f:
                status_data = json.load(f)
                
            # Parse the timestamp
            timestamp = datetime.fromisoformat(status_data['timestamp'])
            
            # If file is older than 24 hours and status is either ready or failed
            if (current_time - timestamp).days >= 1 and status_data['status'] in ['ready', 'failed']:
                session_id = status_file.replace('.json', '')
                
                # Clean up output file
                output_file = os.path.join(OUTPUT_DIR, f"{session_id}.wav")
                if os.path.exists(output_file):
                    os.remove(output_file)
                
                # Clean up stems directory
                stems_dir = os.path.join(STEMS_DIR, session_id)
                if os.path.exists(stems_dir):
                    shutil.rmtree(stems_dir)
                    
                # Clean up compressed directory
                compressed_dir = os.path.join(COMPRESSED_DIR, session_id)
                if os.path.exists(compressed_dir):
                    shutil.rmtree(compressed_dir)
                    
                # Remove status file
                os.remove(file_path)
                
    except Exception as e:
        print(f"Error in cleanup: {str(e)}")


if __name__ == '__main__':
    # Start cleanup thread
    cleanup_thread = threading.Thread(target=cleanup_old_files)
    cleanup_thread.daemon = True
    cleanup_thread.start()
    
    app.run(debug=False, host='0.0.0.0', port=5001)