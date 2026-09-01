local M = {}

local function text(value, fallback)
  if value == nil or value == "" then return fallback or "Unknown" end
  return tostring(value)
end

function M.duration(milliseconds)
  if not milliseconds or milliseconds < 0 then return "LIVE" end
  local seconds = math.floor(milliseconds / 1000)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  seconds = seconds % 60
  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, seconds)
  end
  return string.format("%d:%02d", minutes, seconds)
end

function M.track_title(track)
  return text(track and track.info and track.info.title, "Untitled track")
end

function M.track_line(track)
  local info = track and track.info or {}
  local title = M.track_title(track)
  local url = info.uri
  local label = url and ("[" .. title .. "](" .. url .. ")") or ("**" .. title .. "**")
  local author = text(info.author, "Unknown artist")
  local duration = info.isStream and "LIVE" or M.duration(info.length)
  return string.format("%s — %s [%s]", label, author, duration)
end

function M.now_playing_embed(player)
  local track = player.queue.current
  local info = track and track.info or {}
  local position = player:getPosition()
  local length = info.isStream and "LIVE" or (M.duration(position) .. " / " .. M.duration(info.length))
  local state = player.paused and "Paused" or "Now playing"
  local requested_by = track and track.requestedBy and ("<@" .. tostring(track.requestedBy) .. ">") or "Unknown"
  local progress = ""
  if not info.isStream and type(info.length) == "number" and info.length > 0 then
    local ratio = math.max(0, math.min(1, position / info.length))
    local filled = math.floor(ratio * 10)
    progress = "\n" .. string.rep("▬", filled) .. "🔘" .. string.rep("▬", 10 - filled)
  end

  local embed = {
    title = state,
    color = player.paused and 0xE67E22 or 0x2ECC71,
    description = M.track_line(track) .. "\nRequested by: " .. requested_by .. progress,
    fields = {
      { name = "Position", value = length, inline = true },
      { name = "Volume", value = tostring(player.volume) .. "%", inline = true },
      { name = "Loop", value = player.repeatMode or "off", inline = true },
    },
  }
  if info.artworkUrl then embed.thumbnail = { url = info.artworkUrl } end
  return embed
end

function M.play_embed(tracks, playlist_name)
  local first = tracks[1]
  local count = #tracks
  local description
  if count == 1 then
    description = M.track_line(first)
  else
    description = string.format("Added **%d tracks** from playlist **%s**.\nFirst: %s",
      count, text(playlist_name, "Untitled playlist"), M.track_line(first))
  end

  return {
    title = count == 1 and "Added to queue" or "Playlist added to queue",
    color = 0x3498DB,
    description = description,
  }
end

function M.queue_embed(player, page, per_page)
  local tracks = player.queue.tracks
  local total_pages = math.max(1, math.ceil(#tracks / per_page))
  local start_index = (page - 1) * per_page + 1
  local finish_index = math.min(start_index + per_page - 1, #tracks)
  local lines = {}

  for index = start_index, finish_index do
    table.insert(lines, string.format("%d. %s", index, M.track_line(tracks[index])))
  end

  local current = player.queue.current
  local description = "**Now playing:**\n" .. M.track_line(current)
  if #lines > 0 then
    description = description .. "\n\n**Up next:**\n" .. table.concat(lines, "\n")
  else
    description = description .. "\n\nThe queue is empty."
  end

  local total_length = 0
  for _, track in ipairs(tracks) do
    local info = track.info or {}
    if not info.isStream and type(info.length) == "number" then
      total_length = total_length + info.length
    end
  end

  return {
    title = "Playback queue",
    color = 0x5865F2,
    description = description,
    fields = {
      { name = "Queued", value = tostring(#tracks), inline = true },
      { name = "Upcoming time", value = M.duration(total_length), inline = true },
      { name = "Page", value = string.format("%d / %d", page, total_pages), inline = true },
    },
  }, total_pages
end

return M
