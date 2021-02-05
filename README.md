# Djbot

This is simple music bot based on Elixir's Nostrum library. I implemented Discord Voice for Nostrum and this bot is basically a wrapper around the voice functions with a few features like queuing. The Mix project depends on my fork of Nostrum since updates to the Voice modules will usually here sooner than they will be on [the upstream repo](https://github.com/Kraigie/nostrum). It's not meant to be pretty so don't @ me.

# Interacting

Using the `~help` command will show the following:

```
~help - Show all commands - ~help
~leave - Make the bot leave your voice channel - ~leave
~pause - Pause the currently playing sound - ~pause
~play - Play (or queue) URLs from common service - ~play [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {URL}
~playfile - Play (or queue) files from URL - ~playfile [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {FILE_URL}
~resume - Resume the currently paused sound - ~resume
~skip - Skip to next queued track - ~skip
~stop - Stop the currently playing sound - ~stop
~summon - Make the bot join your voice channel - ~summon
```

The command prefix is hardcoded as `~`.
The `play` and `playfile` commands will start playing right away, or will queue if something's already playing.
~~I might add a feature to start playing from a given timestamp. Stay tuned.~~
I've since added the ability to pipe tons of options directly to ffmpeg through Nostrum. The `play`/`playfile` commands support these options.
The `-f {FILTER}` option can be used multiple times in a single command. The order of the options doesn't matter
except for order of the `filters` relative to each other since they will be chained together.
The `-v {VOLUME}` option is a filter shortcut and will be placed at the end of the chain if other filters are supplied.

# Examples

First, join a Discord voice channel.

`~summon`

The bot should have joined your voice channel.

### Play a song normally

`~play https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song from a start position

This will play the song the position 37.8 seconds.

`~play -s 0:37.8 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song for a duration

This will play the song from the beginning for 15.3 seconds.

`~play -d 15.3 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song at half volume

`~play -v 0.5 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song at double volume (adding some saturation)

`~play -v 2 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song at double tempo

We're using the `atempo` filter to increase the tempo.
Note that we're setting `realtime` with `-r false`.
This is because "realtime" is relative to the original playback speed;
when the audio is playing back faster than the original, ffmpeg will need to
be told to pre-process to keep up.

`~play -r false -f atempo=2 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song at half tempo

We're using the `atempo` filter to decrease the tempo.
Since halving the tempo will reduce the playback speed compared to the original
there's no need for the `-r false` option, and `realtime` will default to `true`.

`~play -f atempo=0.5 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song with BASS BOOSTED

Headphone users be warned

`~play -v 1000 -f lowpass=f=750 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song in NIGHTCORE MODE

This assumes the original sample rate is 48kHz. Both pitch and tempo will be increased by 30%.

`~play -r false -f asetrate=48000*1.3 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song with sickening tremolo

This will make it sound like when you talk into a spinning fan.

`~play -f tremolo=d=1.0:f=12.0 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song with too much vibrato

This sounds like that TikTok filter that makes the voice's pitch modulate rapidly.
Well, that's just what vibarto *is*. Anyway..
If you crank the f value you could do some basic sine wave frequency modulation.

`~play -f vibrato=d=0.8:f=15 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song with some crunchy FM

The vibrato modulates pitch with a since wave. If we lower the d (depth) a bit
and set the f (frequency) to some octave of the song's root key, F in this case,
we can get some pleasant, crunchy frequency modulation.

`~play -f vibrato=d=0.05:f=698.46 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Play a song with a wide chorus effect

A chorus is similar to a phaser or flanger.

`~play -f chorus=0.5:0.9:50|60|40:0.4|0.32|0.3:0.25|0.4|0.3:2|2.3|1.3 https://www.youtube.com/watch?v=b4RJ-QGOtw4`

### Bringing it all together

Now let's try to play something with way too many filters added together to make it sound kind of lo-fi and trippy.

This will start the song at the 50 second timestamp, slow the sample rate down to 73% of the original lowering pitch and tempo,
add a vibrato for crunchy FM, add another vibrato for trippy, slow pitch bending, put a lowpass at 1200 Hz, add a slow phaser, and turn the volume to 3 (heavy saturation).

`~play -v 3 -s 50 -f asetrate=48000*0.73 -f vibrato=d=0.05:f=698.46 -f vibrato=f=1:d=0.8 -f lowpass=f=1200 -f aphaser=in_gain=0.4:out_gain=0.5:delay=3.0:decay=0.3:speed=0.3:type=t https://www.youtube.com/watch?v=b4RJ-QGOtw4`

# Troubleshooting

If you upset `ffmpeg` with bad parameters or otherwise and the bot isn't playing when it's supposed to, run the `~stop` command and try playing again.

If the sound is choppy or cuts out on occasion, it probably is at least partially due to packet loss. Try toggling `-r {true|false}` as some have better luck with on over another.