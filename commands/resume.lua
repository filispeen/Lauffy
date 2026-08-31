local music = require("../services/music")

return {
  name = "resume",
  description = "Resume the current track",
  callback = function(ctx)
    music.resume(ctx)
  end,
}
