# Djbot

This is simple music bot based on Elixir's Nostrum library. I implemented Discord Voice for Nostrum and this bot is basically a wrapper around the voice functions with a few features like queuing. It's not meant to be pretty so don't @ me.

# Interacting

Using the `~help` command will show the following:

```
~help - Show all commands - ~help
~leave - Make the bot leave your voice channel - ~leave
~pause - Pause the currently playing sound - ~pause
~play - Play URLs from common service - ~play {URL}
~playfile - Play files from URL - ~playfile {FILE_URL}
~resume - Resume the currently paused sound - ~resume
~skip - Skip to next queued track - ~skip
~stop - Stop the currently playing sound - ~stop
~summon - Make the bot join your voice channel - ~summon
```

The command prefix is hardcoded as `~`.
The play and playfile commands will start playing right away, or will queue if something's already playing.
I might add a feature to start playing from a given timestamp. Stay tuned.
