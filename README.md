# Lauffy

Lauffy is a Discord slash-command music bot written in Lua for the Luvit runtime. It uses `discord.lua` for Discord interactions and NodeLink v3 as its audio service through the Lavalink API v4.

## Features

- Slash commands with `/play` search autocomplete.
- NodeLink-backed text search, URL loading, playlists, queueing, and playback.
- Per-guild favorites and music settings stored on disk.
- Queue browsing, movement, removal, clearing, shuffle, loop modes, seeking, and volume controls.
- Optional now-playing announcements and delayed disconnect after the queue ends.
- Guild-only commands and voice-channel checks that prevent users from controlling a player in another channel.

## Requirements

- [Luvit](https://luvit.io/) and Lit, its package manager.
- A Discord application and bot token.
- NodeLink v3 with a password that matches `NODELINK_PASSWORD`. The bundled Compose stack supplies it; for an external node, it must expose the Lavalink API v4.
- Discord permissions appropriate for the target channels, including viewing channels, connecting, speaking, and sending messages.
- The Lua dependencies declared in `package.lua`, installed with Lit.

## Installation

```sh
git clone https://github.com/filispeen/Lauffy.git
cd Lauffy
lit install
cp .env.example .env
```

Edit `.env` before starting the bot. Environment variables already set by the host take precedence over values in `.env`.

## Configuration

Use `.env.example` as a template. Create `.env` and set its variables.

```dotenv
TOKEN=<your_discord_bot_token>

NODELINK_HOST=localhost
NODELINK_PORT=2333
NODELINK_PASSWORD=<a_long_random_password>
NODELINK_TLS=false
NODELINK_API_VERSION=4
NODELINK_SEARCH_SOURCE=ytmsearch

NODELINK_RESUME=true
NODELINK_RESUME_TIMEOUT=60
NODELINK_RECONNECT_TRIES=5
NODELINK_RECONNECT_DELAY=5000
```

## NodeLink and Lavalink API v4

Lauffy pins `filispeen/lavalink.lua` v0.4.0 and explicitly sets `apiVersion = 4`. Its audio client uses `wss?://HOST:PORT/v4/websocket`, `GET /v4/loadtracks`, and player/session calls below `/v4/sessions/...`; it never uses NodeLink `/v3` routes. The discord.lua integration forwards both Discord `VOICE_STATE_UPDATE` and `VOICE_SERVER_UPDATE` gateway events to the player automatically.

The WebSocket session is resumed when `NODELINK_RESUME=true`. Failed sockets use the configured reconnect count and exponential reconnect delay. Node, session, reconnect, REST/info, and player errors are logged with a NodeLink-specific prefix.

Plain-text input uses `NODELINK_SEARCH_SOURCE`, which defaults to `ytmsearch`. Set it to `spsearch` when you specifically want NodeLink's Spotify search, `ytsearch` for YouTube, or `search` for NodeLink's unified search. HTTP and HTTPS URLs are sent unchanged, so NodeLink can load tracks and playlists from enabled providers.

## Run

```sh
luvit main.lua
```

Commands are registered before the bot starts, so `discord.lua` can synchronize the slash commands after the Discord READY event.

## Docker

Both Compose configurations persist guild settings and favorites in the `lauffy-data` Docker volume.

### Bot with bundled NodeLink v3

Copy the template, set `TOKEN` and replace `NODELINK_PASSWORD` with a long random value. Do not reuse a real secret from another system.

```sh
cp .env.example .env
docker compose up -d --build
docker compose logs -f
```

To stop the stack, run:

```sh
docker compose down
```

The `nodelink` service is pinned to `performanc/nodelink:v3.3.0` and mounts [nodelink/config.js](nodelink/config.js). Its HTTP/WebSocket port is published only on `127.0.0.1` for local diagnostics; the bot uses the private Compose network. The health check waits for `/version` before the bot starts. Set `NODELINK_SPONSORBLOCK_ENABLED=true` only after basic playback works; NodeLink filters remain available through its Lavalink v4 player endpoints.

### Bot with external NodeLink

Set `TOKEN`, `NODELINK_HOST`, `NODELINK_PORT`, `NODELINK_PASSWORD`, `NODELINK_TLS`, and `NODELINK_API_VERSION=4` in `.env`, then run the bot-only Compose configuration:

```sh
docker compose -f docker-compose.external-nodelink.yml up -d --build
docker compose -f docker-compose.external-nodelink.yml logs -f
```

This configuration starts only the bot. It does not create a local NodeLink service.

To stop it, run:

```sh
docker compose -f docker-compose.external-nodelink.yml down
```

## Commands

All commands are guild-only. `/play` and `/favorites use` require you to be in a voice channel. If the bot already has a player, you must be in that same channel. Commands that control an active player also require the bot to be connected and the caller to share its voice channel.

### Play and favorites

| Command | Options | Behavior |
| --- | --- | --- |
| `/play` | `query` (required), `immediate`, `shuffle`, `skip` | Searches a query or loads a URL/playlist. `immediate` adds tracks to the front, `shuffle` shuffles playlist tracks, and `skip` advances after adding. |
| `/favorites` | `action` (required: `use`, `list`, `create`, `remove`), `name`, `query`, `immediate`, `shuffle`, `skip` | Saves, lists, removes, or queues a per-guild favorite. `use` accepts the same queue options as `/play`; `create` needs `name` and `query`. Users can remove only their own favorites. |

`/play` autocomplete uses the configured NodeLink source for non-empty text and returns up to 10 distinct track URLs. It does not suggest URLs. Favorite-name autocomplete returns up to 25 matching saved favorites; for `remove`, it shows only the caller's favorites.

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
| `/join` | none | Joins the caller's voice channel without starting playback. |
| `/leave` | none | Leaves the current voice channel. |
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
- **NodeLink is not ready**: Run `docker compose logs nodelink`, verify the host, port, TLS flag, API version `4`, and password, then confirm the node supports the requested source.
- **No tracks found**: Check the query or URL and NodeLink's enabled provider support.
- **Voice-channel error**: Join a voice channel before `/play` or `/favorites use`. To control an existing player, join the bot's channel first.
- **Commands do not appear**: Confirm the bot is online and the application is installed in the target guild; command synchronization runs after READY.
