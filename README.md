bkp-transcribe
==============

A simple workflow for automated transcription and archival of audio recordings

Goals:
 - easily consumes the output from a DJI mic 2 (chunked WAV files)
 - fast transcription via Whisper on cloud GPU
 - cheap transcription with short-lived instances
   - archive workspace to avoid wasted time in setup?
   - compress input when uploading to reduce network overhead
 - archive original audio into a compressed lossless format (FLAC)

