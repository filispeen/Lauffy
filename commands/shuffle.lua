local music = require("../services/music")

return {
  name = "shuffle",
  description = "Shuffle upcoming tracks",
  callback = function(ctx)
    music.shuffle(ctx)
  end,
}
