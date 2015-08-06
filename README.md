Statistics
----------

Manage player statistics.

Relations
---------

The statistics module will:

 * Listen for changes in the coordinator.
    * Retrieve player games.
 * Store player statistics in the `redis_statistics` database.
   * `(gametype, username) -> (gameId) -> { "level": 12, "bestScore": 320, "bestSpree": 22 }`
 * Update the player `level` metadata in `users`.

Configuration
-------------

 * `COORDINATOR_PORT_8080_TCP_ADDR` - IP of the coordinator service
 * `COORDINATOR_PORT_8080_TCP_PORT` - Port of the coordinator service
 * `REDIS_STATISTICS_PORT_6379_TCP_ADDR` - IP of the games redis
 * `REDIS_STATISTICS_PORT_6379_TCP_PORT` - Port of the games redis
 * `RANKING_STRATEGY` - (simple)

API
---

All requests made to the turngame API require an auth token, passed in the request URL.

# Player statistics [/statistics/v1/:gametype/player/:username/stats]

    + Parameters
        + username (string) ... Player's username

## Retrieve player stats [GET]

### response [200] OK

    {
        "alltimes": {
            "numGames": 12,
            "numVictories: 6,
            "ranking": 121,
            "bestScore": 420,
            "bestSpree": 21
        },
        "weekly": {
            "numGames": 3,
            "numVictories: 2,
            "ranking": 28,
            "bestScore": 381,
            "bestSpree": 2
        }
    }

# Games archive [/statistics/v1/:gametype/player/:username/archive]

    + Parameters
        + username (string) ... Player's username

## List users game [GET]

    + ?after=timestamp (int) ... Only gets after a given timestamp

### response [200] OK

    [
        {
            "id": "123456788",
            "date": 149202010847293,
            "players" : [{
                "username": "jeko",
                "score": 33,
                "newLevel": 770
            }, {
                "username": "sousou",
                "score": 319,
                "newLevel": 640
            }]
        },
        {
            "id": "123456789",
            "date": 149202039203920,
            "players" : [{
                "username": "jeko",
                "score": 93,
                "newLevel": 750
            }, {
                "username": "TheChicken",
                "score": 218,
                "newLevel": 1834
            }]
        }
    ]
