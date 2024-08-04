bkp-transcribe
==============

A set of scripts to automate transcription of recordings from DJI mic 2.

Tailored to process the raw WAV files extracted from the onboard memory
of one of the standalone transmitters, although it can transcribe arbitrary
audio files.

Requirements:
 - bash
 - python3
 - Lambda Cloud API key
 - [optional] Hugging Face token for diarization

NB: diarization output has been found abysmal on long DJI recordings. YMMV


The script spins up a fresh instance on Lambda Cloud on every invocation.
The instance will be terminated on successful transcription.

In case of failure, the instance will keep running. DO TERMINATE IT to
avoid incurring significant ongoing cost...

Even on relatively low-powered instances (1x A10) transcription is quite
fast, at roughly 1min per hour of input audio. The overhead of booting up
the instance, setting up the required packages, and downloading model
weights is typically on the order of 2-5min, which makes transcription
very affordable, but it's still worth processing input files in groups as
large as possible to amortize the setup overhead.

