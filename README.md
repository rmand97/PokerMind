# PokerMind

PokerMind is a multiplayer Texas Hold'em poker engine with an HTTP API, built for developers who want to create and test pokerbots.

---

## Getting Started

### Prerequisites

- **Elixir**: ~> 1.19
- **Erlang**: OTP 25+
- **Node.js**: 18+ (for asset building)

### Setup

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

---

## API Documentation

The API follows RESTful conventions and requires authentication. 

OpenAPI/Swagger documentation is available at `/swaggerui`.

### Authentication

All API endpoints require an apikey in the `Authorization` header.

The secret is configured via the `API_AUTH_SECRET` environment variable (defaults to `test-secret` in dev/test environments).

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/start_suite` | POST | Creates a new suite with players |
| `/api/next_games` | GET | Gets upcoming games for a player |
| `/api/action` | POST | Submits a player action |
| `/api/close_suite` | DELETE | Closes and cleans up a suite |
| `/api/suites` | GET | Lists all active suites |

### Full Game Flow Example

```bash
# 1. Start a new suite with players
curl -X POST http://localhost:4000/api/start_suite \
  -H "Authorization: test-secret" \
  -H "Content-Type: application/json" \
  -d '{"players": [{"id": "player1", "chips": 10_000}, {"id": "player2", "chips": 10_000}]}'

# Response includes suite_id and first game details

# 2. Get next games for a player
curl "http://localhost:4000/api/next_games?suite_id=<SUITE_ID>&player_id=player1" \
  -H "Authorization: test-secret"

# 3. Submit player actions (loop until game is finished)
curl -X POST http://localhost:4000/api/action \
  -H "Authorization: test-secret" \
  -H "Content-Type: application/json" \
  -d '{
    "suite_id": "<SUITE_ID>",
    "player_id": "player1",
    "action": "call"
  }'

# Supported actions: fold, check, call, raise, all_in
# For raise: {"action": "raise", "amount": 200}

# 4. Close the suite when done
curl -X DELETE "http://localhost:4000/api/close_suite?suite_id=<SUITE_ID>" \
  -H "Authorization: test-secret"
```

---

## Game Rules

### Terminology

- **Suite**: A collection of games that run sequentially. Each suite has its own Coordinator that tracks overall performance.
- **Game**: A single game of poker untill only one player has remaining chips
- **Hand**: A single hand of poker from deal to showdown.

### Supported Actions

| Action | Description |
|--------|-------------|
| **fold** | Player folds their hand, forfeiting the current round |
| **check** | Player checks (no bet to match) - only available when no bet is pending |
| **call** | Player matches the current bet |
| **raise** | Player raises by a specific amount |
| **all_in** | Player commits all remaining chips |

### Blind Rotation

- Blinds are posted by two players before the pre_flop
- **Small Blind**: Posted by a random player
- **Big Blind**: Posted by the player left of the small blind (2x the small blind)
- Blinds rotate after each hand
- Blind levels increase every 10 hands (doubles each level)

### Game Phases

1. **pre_flop**: Cards are dealt, blinds posted
2. **flop**: First 3 community cards revealed
3. **turn**: 4th community card revealed
4. **river**: 5th community card revealed
5. **showdown**: Hands are compared, pot awarded
6. **hand_finished**: Hand complete, ready for next hand
7. **game_finished**: Game complete, winner found

### Player States

- `:active_in_hand` - Player is still in the hand
- `:inactive_in_hand` - Player folded
- `:all_in` - Player went all in
- `:out_of_chips` - Player has no chips left

---

## Important libraries

- **[Boundary](https://hexdocs.pm/boundary/0.10.4/Boundary.html)** is used to keep a strict boundary between our backend and frontend.

- **[Test Watch](https://hexdocs.pm/mix_test_watch/readme.html)** is used to automatically run your Elixir project's tests each time you save a file.

## Notes

We have copied and changed the code from https://github.com/wojtekmach/poker_elixir, as the library was not up to date with our version of Elixir
