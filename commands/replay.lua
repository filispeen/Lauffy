local music = require("../services/music")

return {
  name = "replay",
  description = "Restart the current track",
  callback = function(ctx)
    music.replay(ctx)
  end,
}
