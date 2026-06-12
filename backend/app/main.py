"""Kanjoos API: SSE chat endpoint backed by the Claude Agent SDK, plus budget CRUD."""

import asyncio
import json

from claude_agent_sdk import AssistantMessage, ClaudeSDKClient, TextBlock, ToolUseBlock
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

load_dotenv()

from . import budget  # noqa: E402  (needs env loaded first)
from .agent import build_options  # noqa: E402
from .prompts import budget_context_block  # noqa: E402

app = FastAPI(title="Kanjoos")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# One agent session (with conversation memory) per chat session id.
_sessions: dict[str, ClaudeSDKClient] = {}
_locks: dict[str, asyncio.Lock] = {}


@app.on_event("startup")
def startup() -> None:
    budget.init_db()


async def _get_client(session_id: str) -> tuple[ClaudeSDKClient, asyncio.Lock]:
    if session_id not in _sessions:
        client = ClaudeSDKClient(options=build_options())
        await client.connect()
        _sessions[session_id] = client
        _locks[session_id] = asyncio.Lock()
    return _sessions[session_id], _locks[session_id]


class ChatRequest(BaseModel):
    session_id: str
    message: str


def _sse(payload: dict) -> str:
    return f"data: {json.dumps(payload)}\n\n"


@app.post("/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    client, lock = await _get_client(req.session_id)

    async def stream():
        async with lock:
            status = budget.get_status()
            prompt = f"{budget_context_block(status)}\n\n{req.message}"
            try:
                await client.query(prompt)
                async for message in client.receive_response():
                    if isinstance(message, AssistantMessage):
                        for block in message.content:
                            if isinstance(block, TextBlock) and block.text.strip():
                                yield _sse({"type": "text", "text": block.text})
                            elif isinstance(block, ToolUseBlock):
                                yield _sse({"type": "tool", "name": block.name})
            except Exception as exc:  # surface agent failures to the app
                yield _sse({"type": "error", "text": str(exc)})
            yield _sse({"type": "done", "status": budget.get_status()})

    return StreamingResponse(stream(), media_type="text/event-stream")


@app.get("/budget")
def get_budget() -> dict:
    return budget.get_status()


class BudgetRequest(BaseModel):
    monthly_budget: float


@app.post("/budget")
def set_budget(req: BudgetRequest) -> dict:
    budget.set_monthly_budget(req.monthly_budget)
    return budget.get_status()


class SpendRequest(BaseModel):
    amount: float
    description: str


@app.post("/spend")
def add_spend(req: SpendRequest) -> dict:
    budget.log_spend(req.amount, req.description, source="manual")
    return budget.get_status()


@app.get("/spends")
def list_spends() -> list[dict]:
    return budget.recent_spends()


class SimDateRequest(BaseModel):
    date: str | None  # ISO date to simulate, or null to return to real time


@app.post("/debug/date")
def set_sim_date(req: SimDateRequest) -> dict:
    budget.set_sim_date(req.date)
    return budget.get_status()
