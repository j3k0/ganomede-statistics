# Types used by the statistics module

```
Type: String

Username: String

GetArchivesCallback: Error -> Array<GameOutcome> -> Void

GameWithArchives: {
  game: Game
  archives: Array<PlayerArchive>
  index: Int
}

PlayerArchive: = {
    username: String,
    games: Array<GameOutcome>
}

GameOutcome: {
  game: {
    date: Timestamp,
    id: String,
    players: Array<PlayerScore>
  }
  outcome: {
    newLevel: Int
  }
}

PlayerGameOutcome: {
  username: String
  type: String
  game: GameOutcome
}

GameRank: {
  game: {
    date: Timestamp,
    id: String,
    players: Array<PlayerScore>
  }
  outcome: {
    newLevel: Int
    newRank: Int
  }
}

PlayerGameRank: {
  username: String
  type: String
  game: GameRank
}

StorageConfig: {
  host: String
  port: String
  prefix: String
}

PlayerScore: {
  username: String,
  score: Int
}

GamesBody: {
  last_seq: Int
  results: Array<Game>
}

ProcessOutcome: {
  last_seq: Int
}

Game: {
  id: String
  type: String,
  gameOverData: {
    players: Array<PlayerScore>
  }
}

PlayerScore: {
  score: Int
  name: String
}

AkGame: {
  date: Float
  id: String
  players: Array<AkPlayerScore>
}
see alkindi.Game

AkPlayerScore: = {
  username: String,
  score: Int
}
see alkindi.PlayerScore
```
