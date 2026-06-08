"""
F5-TTS Voice Cloning Server for Story of My Life

A FastAPI wrapper around F5-TTS that provides REST endpoints for:
- Storing voice reference audio samples
- Synthesizing speech using cloned voices
- Managing voice references

Designed to run on a Mac/PC on the same local network as the iOS app.

Usage:
    python f5_server.py

Environment variables:
    F5_MODEL_PATH   Path to Finnish model checkpoint (default: latest Finnish model in ./model/)
    F5_VOCAB_PATH   Path to vocab file (default: uses F5-TTS default)
    F5_HOST         Bind address (default: 0.0.0.0)
    F5_PORT         Port number (default: 5005)
    F5_REF_DIR      Reference audio storage directory (default: ./references)
"""

import json
import os
import uuid
import wave
from pathlib import Path

import torch
import torchaudio
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MODEL_PATH = os.getenv(
    "F5_MODEL_PATH",
    "./model/model_commonvoice_fi_librivox_fi_vox_populi_fi_20250323/model_last_20250323.safetensors",
)
VOCAB_PATH = os.getenv(
    "F5_VOCAB_PATH",
    "./model/model_commonvoice_fi_librivox_fi_vox_populi_fi_20250323/vocab.txt",
)
HOST = os.getenv("F5_HOST", "0.0.0.0")
PORT = int(os.getenv("F5_PORT", "5005"))
REF_DIR = Path(os.getenv("F5_REF_DIR", "./references"))

# Ensure reference storage exists
REF_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# F5-TTS Model Loading
# ---------------------------------------------------------------------------

model = None


def load_model():
    """Load the F5-TTS Finnish model."""
    global model
    from f5_tts.api import F5TTS

    print(f"[F5-Server] Loading model from {MODEL_PATH}...")

    kwargs = {"ckpt_file": MODEL_PATH}
    if VOCAB_PATH:
        kwargs["vocab_file"] = VOCAB_PATH

    model = F5TTS(model="F5TTS_v1_Base", **kwargs)
    print("[F5-Server] Model loaded successfully")


# ---------------------------------------------------------------------------
# Reference Management Helpers
# ---------------------------------------------------------------------------

METADATA_FILE = REF_DIR / "_metadata.json"


def _load_metadata() -> dict:
    """Load reference metadata from disk."""
    if METADATA_FILE.exists():
        return json.loads(METADATA_FILE.read_text())
    return {}


def _save_metadata(data: dict):
    """Save reference metadata to disk."""
    METADATA_FILE.write_text(json.dumps(data, indent=2))


# ---------------------------------------------------------------------------
# FastAPI App
# ---------------------------------------------------------------------------

app = FastAPI(title="F5-TTS Voice Cloning Server", version="1.0.0")


@app.on_event("startup")
async def startup():
    load_model()


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.get("/v1/health")
async def health():
    return {
        "status": "ok",
        "model": "F5-TTS Finnish",
        "model_loaded": model is not None,
    }


@app.post("/v1/references")
async def upload_reference(
    name: str = Form(...),
    audio: UploadFile = File(...),
):
    """Upload a voice reference audio sample."""
    ref_id = str(uuid.uuid4())
    audio_data = await audio.read()

    if len(audio_data) < 1000:
        raise HTTPException(status_code=400, detail="Audio sample too short")

    # Save audio file
    audio_path = REF_DIR / f"{ref_id}.wav"
    audio_path.write_bytes(audio_data)

    # Save metadata
    metadata = _load_metadata()
    metadata[ref_id] = {"name": name, "filename": f"{ref_id}.wav"}
    _save_metadata(metadata)

    print(f"[F5-Server] Reference saved: {name} ({ref_id})")
    return {"reference_id": ref_id, "name": name}


@app.get("/v1/references")
async def list_references():
    """List all stored voice references."""
    metadata = _load_metadata()
    return [
        {"reference_id": ref_id, "name": info["name"]}
        for ref_id, info in metadata.items()
    ]


@app.delete("/v1/references/{ref_id}")
async def delete_reference(ref_id: str):
    """Delete a voice reference."""
    metadata = _load_metadata()
    if ref_id not in metadata:
        raise HTTPException(status_code=404, detail="Reference not found")

    # Remove audio file
    audio_path = REF_DIR / metadata[ref_id]["filename"]
    if audio_path.exists():
        audio_path.unlink()

    # Remove from metadata
    del metadata[ref_id]
    _save_metadata(metadata)

    print(f"[F5-Server] Reference deleted: {ref_id}")
    return {"status": "deleted"}


@app.post("/v1/tts")
async def text_to_speech(body: dict):
    """
    Synthesize speech using a cloned voice.

    Request body:
        {"text": "Hello world", "reference_id": "uuid-here"}

    Returns: WAV audio data
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    text = body.get("text", "").strip()
    ref_id = body.get("reference_id", "")

    if not text:
        raise HTTPException(status_code=400, detail="Text is required")
    if not ref_id:
        raise HTTPException(status_code=400, detail="reference_id is required")

    # Look up reference audio
    metadata = _load_metadata()
    if ref_id not in metadata:
        raise HTTPException(status_code=404, detail="Reference not found")

    ref_audio_path = str(REF_DIR / metadata[ref_id]["filename"])
    if not Path(ref_audio_path).exists():
        raise HTTPException(status_code=404, detail="Reference audio file missing")

    # Load reference audio to get the transcript (empty = let F5-TTS auto-detect)
    ref_text = ""

    print(f"[F5-Server] Synthesizing: '{text[:80]}...' with ref={ref_id}")

    try:
        # F5-TTS inference: zero-shot voice cloning
        wav, sr, _ = model.infer(
            ref_file=ref_audio_path,
            ref_text=ref_text,
            gen_text=text,
        )

        # Convert tensor to WAV bytes
        if isinstance(wav, torch.Tensor):
            if wav.dim() == 1:
                wav = wav.unsqueeze(0)
        else:
            wav = torch.tensor(wav).unsqueeze(0)

        # Write to in-memory WAV
        import io

        buffer = io.BytesIO()
        torchaudio.save(buffer, wav, sr, format="wav")
        wav_bytes = buffer.getvalue()

        print(f"[F5-Server] Synthesis complete: {len(wav_bytes)} bytes")
        return Response(content=wav_bytes, media_type="audio/wav")

    except Exception as e:
        print(f"[F5-Server] Synthesis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print(f"[F5-Server] Starting on {HOST}:{PORT}")
    print(f"[F5-Server] Model path: {MODEL_PATH}")
    print(f"[F5-Server] References dir: {REF_DIR}")
    uvicorn.run(app, host=HOST, port=PORT, workers=1)
