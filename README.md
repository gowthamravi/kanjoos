# Kanjoos 🪙

**A food-ordering agent with a financial conscience.** Order from Swiggy through chat — but Kanjoos
knows your monthly food budget, tracks every spend, and gets progressively more protective as the
month runs out:

- 🟢 **Green** — orders what you ask, no commentary.
- 🟡 **Yellow** — finds deals and offers one cheaper alternative before ordering.
- 🔴 **Red (month-end mode)** — counter-offers a Swiggy Instamart *cook-at-home cart* with a
  side-by-side price comparison ("Delivered ₹350 vs make it ₹140"). You can always override —
  it's your money. It will just make you look at the math first.

Built for the [Swiggy Builders Club](https://mcp.swiggy.com/builders/docs/) using the
**Swiggy Food + Instamart MCP servers**, the **Claude Agent SDK**, **FastAPI**, and a native
**SwiftUI iOS app**.

## Architecture

```
iOS app (SwiftUI chat + budget gauge)
   → FastAPI  (/chat SSE, /budget, /spend, /debug/date)
      → Claude Agent SDK (ClaudeSDKClient, one session per chat)
         → Swiggy Food MCP        (restaurants, menus, deals, ordering)
         → Swiggy Instamart MCP   (ingredient search, cart building)
         → budget MCP (in-process) (SQLite ledger + green/yellow/red state)
```

The budget state is computed server-side (`remaining ÷ days left` vs the monthly baseline) and
injected into every agent turn, so the personality shift is driven by real numbers.

## Backend setup

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env   # fill in ANTHROPIC_API_KEY and the Swiggy MCP URLs
.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0   # 0.0.0.0 so a physical iPhone can reach it
```

Requirements:
- The Claude Agent SDK uses the Claude Code runtime — install it if you haven't
  (`npm install -g @anthropic-ai/claude-code`).
- **Swiggy MCP URLs**: get the exact endpoints from the
  [Swiggy builders docs](https://mcp.swiggy.com/builders/docs/) and put them in `.env`.
  Without a `SWIGGY_MCP_TOKEN`, the backend connects through `npx mcp-remote <url>`, which opens
  Swiggy's OAuth 2.1 PKCE login in your browser on first run and caches the token.
- With the Swiggy URLs left blank the app still runs — budget tracking and the personality work,
  the agent just can't pull live restaurant data.

## iOS setup

```bash
cd ios
xcodegen generate     # brew install xcodegen if needed
open Kanjoos.xcodeproj
```

Run on the simulator — it reaches the backend at `http://127.0.0.1:8000` out of the box.
On a physical device, open Settings (gear icon) in the app and point the server URL at your
Mac's LAN IP.

## Demo script (90 seconds)

1. Settings → set budget ₹8000. It's day 4: ask **"order me a biryani"** → instant, friendly order.
2. Settings → *Time travel* → jump to day 26, log ₹7300 of outside spends.
3. Ask **"order me a biryani"** again → month-end mode: the math, the guilt, and an Instamart
   counter-cart at 40% of the price.
4. Say **"just order it anyway"** → it complies graciously. One guilt line. Logged to the ledger.

## API

| Method | Path          | Body                                | Purpose |
|--------|---------------|-------------------------------------|---------|
| POST   | `/chat`       | `{session_id, message}`             | SSE stream of agent events |
| GET    | `/budget`     | —                                   | Budget snapshot + state |
| POST   | `/budget`     | `{monthly_budget}`                  | Set monthly budget |
| POST   | `/spend`      | `{amount, description}`             | Log an outside spend |
| GET    | `/spends`     | —                                   | Recent spends |
| POST   | `/debug/date` | `{date: "YYYY-MM-DD" \| null}`      | Time travel for demos |
