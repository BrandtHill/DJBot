# Djbot

This is simple Discord music bot using the Nostrum Discord library written in Elixir.

I created the Voice API for the Nostrum library for interacting with Discord Voice channels, and this bot is basically a wrapper around the voice functionality with a few features like queuing (and voice commands?!). Feel free to use this repo as a reference or as inspiration for a more fully featured Elixir music bot. This Mix project depends on my fork of Nostrum since voice features and fixes will usually be live there sooner than they will be on [the upstream repo](https://github.com/Kraigie/nostrum). If you have any questions on Nostrum's Voice API usage or suggestions for features, feel free to visit [the `#elixir_nostrum` channel of the unofficial Discord API guild](https://discord.gg/2Bgn8nW).

# Interacting

Using the `/help` command will show the following:

```
/help - Show all commands
/leave - Tell DJ Bot to leave your voice channel
/pause - Pause the currently playing sound
/play - Play (or queue) URLs from common service
/playdir - Play (or queue) directory of files
/playfile - Play (or queue) files from URL
/playstream - Play (or queue) livestream URLs from common service
/purge - Purge elements from queue without stopping playback
/resume - Resume the currently paused sound
/show - Show the next few queued URLs
/skip - Skip to next queued track
/soundboard - Interact with a soundboard
/stop - Stop the currently playing sound and purge queue
/summon - Summon DJ Bot to your voice channel
```

Each command is a Discord application command, so use tab complete to assist in entering commands and their arguments. 

The `play`, `playfile`, `playdir`, and `playstream` commands will start playing right away, or will queue if something's already playing.

I've added the ability to pipe tons of options directly to ffmpeg through Nostrum. The `play`/`playfile`/`playdir`/`playstream` commands support these options.
The `filters: {FILTER_1} {FILTER_2} ...` option takes a space-delimited list of ffmpeg filters, and their order determines how they will be chained together when passed to ffmpeg.
The `volume: {VOLUME}` option is a filter shortcut and will be placed at the end of the chain if other filters are supplied.
I've added a `playdir` command which acts the same as the `playfile` command except that a file system directory will be searched recursively for
files in common audio formats, and the results will be shuffled. If options are given, they will be applied to each of the files queued.
The `playstream` is like `play` except that URLs are opened through `streamlink` instead of `youtube-dl`, which is for livestreams.

# Voice Commands

Most recently I've fully implemented listening to incoming audio data for Nostrum. At the time of writing the only other Discord libraries that I know of that support listening to audio are `discord.js` and someone's fork of `discord.py`. Discord does not provide documentation on voice listening, but they do use standard protocols and formats. A use case for this might be to record audio tracks to files for a meeting. I don't have a use for this, but I have added some speech recognition functionality to this project. It uses `vosk`, an open source offline speech recognition tool. By default each guild will have an instance of `vosk` started. You can say `DJ play`, and if the speech is recognized, DJ Bot will begin shuffling a hardcoded directory of music my machine. You can also say `DJ pause`, `DJ resume`, `DJ stop`, `DJ skip`, `DJ leave`, which are equivalent to the text-based commands (skip uses a value of `1`) when spoken.

# Soundboard

I've added a configurable soundboard for each guild. A user can enter a url which gets downloaded and transcoded into raw opus and stored in an `:ets` table and synced to disk in a `:dets` table. Showing the soundboard will send an interaction response with a button for each sound, and they can be clicked for instant audio playback.

# Examples

First, join a Discord voice channel.

`/summon`

The bot should have joined your voice channel.

### Play a song normally

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4`

The rest of these examples will be using the same YouTube URL, but they can all be done with the `playfile` command and a filename (which supports spaces).

### Play a song from a start position

This will play the song from the position 37.8 seconds.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 start_time: 0:37.8`

### Play a song for a duration

This will play the song from the beginning for 15.3 seconds.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 duration: 15.3`

### Play a song at half volume

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 volume: 0.5`

### Play a song at double volume (adding some saturation)

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 volume: 2`

### Play a song at double tempo

We're using the `atempo` filter to increase the tempo.
Note that we're turning off `realtime` with `realtime: False`.
This is because "realtime" is relative to the original playback speed;
when the audio is playing back faster than the original, ffmpeg will need to
be told to pre-process to keep up.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 realtime: False filters: atempo=2`

### Play a song at half tempo

We're using the `atempo` filter to decrease the tempo.
Since halving the tempo will reduce the playback speed compared to the original
there's no need for the `realtime: False` option, and `realtime` will default to `True`.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 filters: atempo=0.5`

### Play a song with BASS BOOSTED

Headphone users be warned (there actually is a `asubboost` filter, but this is just for the bass boosted memes). 

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 volume: 1000 filters: lowpass=f=750`

### Play a song in NIGHTCORE MODE

This assumes the original sample rate is 48kHz. Both pitch and tempo will be increased by 30%.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 realtime: False filters: asetrate=48000*1.3`

### Play a song with sickening tremolo

This is the sound it makes when you talk into a fan.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 filters: tremolo=d=1.0:f=12.0`

### Play a song with too much vibrato

This sounds like that TikTok filter that makes the voice's pitch modulate rapidly.
Well, that's just what vibrato *is*. Anyway..
If you crank the f value you could do some basic sine wave frequency modulation.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 filters: vibrato=d=0.8:f=15`

### Play a song with some crunchy FM

The vibrato modulates pitch with a sine wave. If we lower the depth a bit
and set the frequency to some octave of the song's root key - F in this case -
we can get some pleasant, crunchy frequency modulation.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 filters: vibrato=d=0.05:f=698.46`

### Play a song with a wide chorus effect

A chorus is similar to a phaser or flanger.

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 filters: chorus=0.5:0.9:50|60|40:0.4|0.32|0.3:0.25|0.4|0.3:2|2.3|1.3`

### Bringing it all together

Now let's try to play something with way too many filters added together to make it sound lo-fi and trippy.

This will start the song at the 50 second timestamp, slow the sample rate down to 73% of the original lowering pitch and tempo,
add a vibrato for crunchy FM, add another vibrato for trippy, slow pitch bending, put a lowpass at 1200 Hz, add a slow phaser, and turn the volume to 3 (heavy saturation).

`/play url: https://www.youtube.com/watch?v=b4RJ-QGOtw4 volume: 3 start_time: 50 filters: asetrate=48000*0.73 vibrato=d=0.05:f=698.46 vibrato=f=1:d=0.8 lowpass=f=1200 aphaser=in_gain=0.4:out_gain=0.5:delay=3.0:decay=0.3:speed=0.3:type=t`

The possibilities are literally infinite. Be sure to check out the [ffmpeg audio filters documentation](https://ffmpeg.org/ffmpeg-filters.html#Audio-Filters) to learn how to
use the innumerable filters and their boundless options.

# Troubleshooting

If you upset `ffmpeg` - with bad parameters or otherwise - and the bot isn't playing when it's supposed to, run the `/stop` command and try playing again.

If the sound is choppy or cuts out on occasion, it probably is at least partially due to packet loss. It could also be due to your machine's inability to process audio efficiently.
Try toggling `realtime: {True|False}` as some have better luck with one option over the other.
