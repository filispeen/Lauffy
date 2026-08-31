local music = require("../services/music")

return {
  name = "nowplaying",
  description = "Show the currently playing track",
  callback = function(ctx)
    music.nowplaying(ctx)
  end,
}
