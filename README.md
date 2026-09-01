# Lauffy

Lauffy is a Discord slash-command music bot written in Lua for Luvit runtime. It uses `discord.lua` for Discord interactions and Lavalink for search, track metadata, queue playback, and voice connections and etc.

## Features

- Slash commands with `/play` search autocomplete.
- Lavalink-backed text search, URL loading, playlists, queueing, and playback.
- Per-guild favorites and music settings stored on disk.
- Queue browsing, movement, removal, clearing, shuffle, loop modes, seeking, and volume controls.
- Optional now-playing announcements and delayed disconnect after the queue ends.
- Guild-only commands and voice-channel checks that prevent users from controlling a player in another channel.

## Requirements

- [Luvit](https://luvit.io/) and Lit, its package manager.
- A Discord application and bot token.
- A reachable Lavalink node with a password that matches `LAVALINK_PASS`. The node must support `ytsearch` for text searches and any URL providers you plan to use.
- Discord permissions appropriate for the target channels, including viewing channels, connecting, speaking, and sending messages.
 - `filispeen/discord.lua@v1.0.2` and `filispeen/lavalink.lua@v0.3.5`.

## Installation

```sh
git clone https://github.com/filispeen/Lauffy.git
cd Lauffy
lit install
cp .env.example .env
```

Edit `.env` before starting the bot. Environment variables already set by the host take precedence over values in `.env`.

## Configuration

Use `.env.example` as the envoriment example. Create `.env` file and set your env variables.

```dotenv
TOKEN=<your_discord_bot_token>

LAVALINK_HOST=localhost
LAVALINK_PORT=2333
LAVALINK_PASS=<your_lavalink_password>
LAVALINK_SECURE=false

LAVALINK_RESUME=true
LAVALINK_RESUME_TIMEOUT=60
LAVALINK_RECONNECT_TRIES=5
LAVALINK_RECONNECT_DELAY=5000
```

## Lavalink

Run Lavalink separately, then point Lauffy at it through the variables above. Lauffy connects after Discord signals that the bot is ready. If the node is unreachable, commands respond that Lavalink is not ready.

Lauffy does not download, cache, transcode, or play media locally. Plain-text input is sent to Lavalink as a YouTube search with `ytsearch`; HTTP and HTTPS URLs are sent to Lavalink unchanged. Lavalink resolves the tracks and performs playback.

## Run

```sh
luvit main.lua
```

Commands are registered before the bot starts, so `discord.lua` can synchronize the slash commands after the Discord READY event.

## Commands

All commands are guild-only. `/play` and `/favorites use` require you to be in a voice channel. If the bot already has a player, you must be in that same channel. Commands that control an active player also require the bot to be connected and the caller to share its voice channel.

### Play and favorites

| Command | Options | Behavior |
| --- | --- | --- |
| `/play` | `query` (required), `immediate`, `shuffle`, `skip` | Searches a query or loads a URL. `immediate` adds tracks to the front, `shuffle` shuffles playlist tracks, and `skip` advances after adding. |
| `/favorites` | `action` (required: `use`, `list`, `create`, `remove`), `name`, `query`, `immediate`, `shuffle`, `skip` | Saves, lists, removes, or queues a per-guild favorite. `use` accepts the same queue options as `/play`; `create` needs `name` and `query`. Users can remove only their own favorites. |

`/play` autocomplete runs a Lavalink `ytsearch` for non-empty text and returns up to 10 distinct track URLs. It does not suggest URLs. Favorite-name autocomplete returns up to 25 matching saved favorites; for `remove`, it shows only the caller's favorites.

### Queue and playback

| Command | Options | Behavior |
| --- | --- | --- |
| `/queue` | `page`, `page_size` | Shows the current track and upcoming queue. `page` starts at 1; `page_size` is 1-30 and defaults to the guild setting. |
| `/nowplaying` | none | Shows the current track, position, requestor, volume, and loop mode. |
| `/clear` | none | Removes upcoming tracks and keeps the current track. |
| `/remove` | `position` (required), `range` | Removes one or more upcoming tracks. |
| `/move` | `from` (required), `to` (required) | Moves an upcoming track to another queue position. |
| `/shuffle` | none | Shuffles upcoming tracks; at least two are required. |
| `/skip` | `number` | Skips the current track or jumps to an upcoming queue position. |
| `/unskip` | none | Returns to the previous track when one is available. |
| `/pause` and `/resume` | none | Pause or resume playback. |
| `/stop` | none | Stops playback and clears the queue. |
| `/disconnect` | none | Leaves the current voice channel. |
| `/replay` | none | Restarts the current track. |
| `/seek` | `time` (required) | Seeks to an absolute position. |
| `/fseek` | `time` (required) | Seeks forward from the current position. |
| `/loop` | `mode` (required: `off`, `track`, `queue`) | Sets the repeat mode. |
| `/volume` | `level` (required) | Sets playback volume from 0 to 1000. |

`/seek` and `/fseek` accept seconds (`90`), unit notation (`1m30s`), `MM:SS`, or `HH:MM:SS`. Live streams cannot be seeked.

### Guild settings

| Command | Options | Behavior |
| --- | --- | --- |
| `/config get` | none | Shows the guild's music settings privately. |
| `/config set` | `setting`, `value` | Changes a setting privately. Requires Manage Server permission. |

`/config set` supports `playlist_limit` (integer at least 1), `queue_page_size` (1-30), `default_volume` (0-1000), `queue_add_hidden` (boolean), `auto_announce` (boolean), and `queue_end_delay` (whole seconds, 0 or more).

Settings and favorites are stored per guild in `data/guild-settings.json`, relative to the bot's working directory. `queue_add_hidden` makes queue-add responses private. `auto_announce` posts a now-playing message in the text channel last used to queue music. When the queue ends, the bot waits for `queue_end_delay` seconds before disconnecting if the player is still idle; a delay of `0` keeps it connected.

## Troubleshooting

- **`TOKEN is required`**: Set `TOKEN` in `.env` or in the process environment.
- **Lavalink is not ready**: Start Lavalink, verify the host, port, secure flag, and password, then confirm the node supports the requested source.
- **No tracks found**: Check the query or URL and Lavalink's provider support.
- **Voice-channel error**: Join a voice channel before `/play` or `/favorites use`. To control an existing player, join the bot's channel first.
- **Commands do not appear**: Confirm the bot is online and the application is installed in the target guild; command synchronization runs after READY.
