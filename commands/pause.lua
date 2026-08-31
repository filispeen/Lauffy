local music = require("../services/music")

return {
  name = "pause",
  description = "Pause the current track",
  callback = function(ctx)
    music.pause(ctx)
  end,
}
