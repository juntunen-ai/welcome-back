# F5-TTS Voice Cloning Server

Local server for Finnish voice cloning, used by the Story of My Life iOS app.

## Requirements

- Python 3.10+
- Mac with Apple Silicon (M1+) or PC with NVIDIA GPU
- ~4GB RAM for model inference

## Setup

```bash
# 1. Create virtual environment
python -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Download the Finnish F5-TTS model
mkdir -p model
# Download from: https://huggingface.co/AsmoKoskinen/F5-TTS_Finnish_Model
# Place model_last_20250323.safetensors in the model/ directory
# Rename to model_last.safetensors (or set F5_MODEL_PATH env var)

# 4. Run the server
python f5_server.py
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `F5_MODEL_PATH` | `./model/model_last.safetensors` | Path to Finnish model checkpoint |
| `F5_VOCAB_PATH` | (F5-TTS default) | Path to vocab file |
| `F5_HOST` | `0.0.0.0` | Bind address |
| `F5_PORT` | `5000` | Port number |
| `F5_REF_DIR` | `./references` | Directory for stored voice references |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v1/health` | Health check |
| `POST` | `/v1/references` | Upload voice reference (multipart: name + audio) |
| `GET` | `/v1/references` | List all voice references |
| `DELETE` | `/v1/references/{id}` | Delete a voice reference |
| `POST` | `/v1/tts` | Synthesize speech (JSON: text + reference_id) |

## iOS App Setup

In the Story of My Life app:
1. Go to **Settings > Voice Cloning Server**
2. Enter your server URL (e.g., `http://192.168.1.50:5000`)
3. Tap **Test Connection** to verify

Your Mac/PC and iPhone must be on the same Wi-Fi network.
