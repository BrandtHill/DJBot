#!/usr/bin/env python3

from time import sleep
from vosk import Model, KaldiRecognizer, SetLogLevel
import os
import json
import subprocess

SetLogLevel(-1)

# If you're not me, you'll need to download a model and put things in their places.

model_path = "vosk/models/model_small"

print("process started")

if not os.path.exists(model_path):
    print ("Please download the model from https://alphacephei.com/vosk/models and unpack as 'model' in the current folder.")
    print(os.getcwd())
    exit (1)

model = Model(model_path)
rec = KaldiRecognizer(model, 16000)

process = subprocess.Popen(['ffmpeg', '-loglevel', 'quiet', '-i', 'pipe:0', '-ar', '16000', '-ac', '1', '-f', 's16le', '-'], stdout=subprocess.PIPE)

i = 0
s = 0
while True:
    data = process.stdout.read(1000)
    if len(data):
        i+=1
        s+=len(data)
        #print(f"Got a line: {len(data)}, {i}, {s}")

        if rec.AcceptWaveform(data):
            res = json.loads(rec.Result())['text']
            res = res.strip()
            if len(res): print(res)
        
    else:
        print('Got nothing... sleeping')
        sleep(2)

