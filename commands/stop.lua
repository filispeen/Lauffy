local music = require("../services/music")

return {
  name = "stop",
  description = "Stop playback and clear the queue",
  callback = function(ctx)
    music.stop(ctx)
  end,
}
