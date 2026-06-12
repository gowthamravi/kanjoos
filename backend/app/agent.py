"""Claude Agent SDK wiring: budget tools + Swiggy MCP servers."""

import os
from typing import Any

from claude_agent_sdk import ClaudeAgentOptions, create_sdk_mcp_server, tool

from . import budget
from .prompts import SYSTEM_PROMPT


@tool("get_budget_status", "Get the current month's food budget snapshot: remaining money, days left, daily allowance, and state (green/yellow/red).", {})
async def get_budget_status(args: dict[str, Any]) -> dict[str, Any]:
    status = budget.get_status()
    return {"content": [{"type": "text", "text": str(status)}]}


@tool("log_spend", "Record a food spend against this month's budget. Call this right after an order or cart handoff completes, with the actual amount in rupees.", {"amount": float, "description": str})
async def log_spend(args: dict[str, Any]) -> dict[str, Any]:
    budget.log_spend(float(args["amount"]), str(args["description"]), source="agent")
    status = budget.get_status()
    return {"content": [{"type": "text", "text": f"Logged ₹{args['amount']} — {args['description']}. Remaining: ₹{status['remaining']}"}]}


@tool("list_recent_spends", "List the most recent logged food spends this month.", {})
async def list_recent_spends(args: dict[str, Any]) -> dict[str, Any]:
    return {"content": [{"type": "text", "text": str(budget.recent_spends())}]}


budget_server = create_sdk_mcp_server(
    name="budget",
    version="1.0.0",
    tools=[get_budget_status, log_spend, list_recent_spends],
)


def _swiggy_server(url: str) -> dict:
    """Connect to a Swiggy MCP server.

    With SWIGGY_MCP_TOKEN set, connects directly over streamable HTTP.
    Without it, proxies through mcp-remote, which runs Swiggy's OAuth 2.1
    PKCE browser flow on first use and caches the token locally.
    """
    token = os.getenv("SWIGGY_MCP_TOKEN")
    if token:
        return {"type": "http", "url": url, "headers": {"Authorization": f"Bearer {token}"}}
    return {"command": "npx", "args": ["-y", "mcp-remote", url]}


def build_options() -> ClaudeAgentOptions:
    mcp_servers: dict[str, Any] = {"budget": budget_server}
    allowed = ["mcp__budget"]

    food_url = os.getenv("SWIGGY_FOOD_MCP_URL")
    instamart_url = os.getenv("SWIGGY_INSTAMART_MCP_URL")
    if food_url:
        mcp_servers["swiggy_food"] = _swiggy_server(food_url)
        allowed.append("mcp__swiggy_food")
    if instamart_url:
        mcp_servers["swiggy_instamart"] = _swiggy_server(instamart_url)
        allowed.append("mcp__swiggy_instamart")

    return ClaudeAgentOptions(
        model=os.getenv("KANJOOS_MODEL", "claude-opus-4-8"),
        system_prompt=SYSTEM_PROMPT,
        mcp_servers=mcp_servers,
        allowed_tools=allowed,
        max_turns=30,
    )
