#!/usr/bin/env python3
"""
Seed Firefly III with transactions from the existing expense tracker.

Usage:
    1. Get a Firebase JWT token from the expense tracker (browser dev tools -> Network -> Authorization header)
    2. Run: python3 seed_firefly.py --expense-token <JWT> --firefly-url https://firefly.sirius.moonblade.work

    Or if using PAT:
    python3 seed_firefly.py --expense-token <JWT> --firefly-url https://firefly.sirius.moonblade.work --firefly-token <PAT>

    The script pulls 3 months of transactions from expense.moonblade.work and
    creates them in Firefly III via its API.
"""

import argparse
import requests
import time
from datetime import datetime, timedelta

EXPENSE_URL = "https://expense.moonblade.work"

# Category mapping from expense tracker to Firefly III
CATEGORY_MAP = {
    "uncategorized": "Uncategorized",
    "travel": "Travel",
    "family": "Family",
    "food": "Food & Dining",
    "friends": "Friends",
    "health": "Health",
    "home": "Home",
    "charity": "Charity",
    "shopping": "Shopping",
    "investment": "Investment",
    "entertainment": "Entertainment",
}


def fetch_transactions(expense_token: str, months: int = 3):
    """Fetch transactions from the expense tracker."""
    now = int(time.time())
    from_date = int((datetime.now() - timedelta(days=months * 30)).timestamp())

    headers = {"Authorization": f"Bearer {expense_token}"}
    params = {"from_date": from_date, "to_date": now}

    resp = requests.get(f"{EXPENSE_URL}/transactions", headers=headers, params=params)
    resp.raise_for_status()
    data = resp.json()
    return data.get("transactions", [])


def create_firefly_transaction(firefly_url: str, firefly_token: str, txn: dict):
    """Create a single transaction in Firefly III."""
    headers = {
        "Authorization": f"Bearer {firefly_token}",
        "Content-Type": "application/json",
        "Accept": "application/vnd.api+json",
    }

    # Determine transaction type
    if txn.get("transactiontype") == "credit":
        ff_type = "deposit"
    else:
        ff_type = "withdrawal"

    # Parse date
    ts = txn.get("timestamp", 0)
    if ts > 1e10:
        ts = ts / 1000
    date_str = datetime.fromtimestamp(ts).strftime("%Y-%m-%d") if ts else datetime.now().strftime("%Y-%m-%d")

    amount = abs(txn.get("amount", 0))
    if amount == 0:
        return None

    merchant = txn.get("merchant", "Unknown")
    category = CATEGORY_MAP.get(txn.get("category", "uncategorized"), txn.get("category", "Uncategorized"))
    account = txn.get("account", "Cash")
    reason = txn.get("reason", "")
    message = txn.get("message", "")
    notes = f"{reason}\n{message}".strip() if reason or message else ""

    payload = {
        "error_if_duplicate_hash": False,
        "transactions": [
            {
                "type": ff_type,
                "date": date_str,
                "amount": str(amount),
                "description": merchant,
                "category_name": category,
                "source_name": account if ff_type == "withdrawal" else merchant,
                "destination_name": merchant if ff_type == "withdrawal" else account,
                "notes": notes,
            }
        ],
    }

    resp = requests.post(f"{firefly_url}/api/v1/transactions", headers=headers, json=payload)
    if resp.status_code in (200, 201):
        return resp.json()
    else:
        print(f"  FAILED ({resp.status_code}): {merchant} {amount} - {resp.text[:200]}")
        return None


def get_firefly_token_via_remote_user(firefly_url: str):
    """
    When using remote_user_guard, you need a Personal Access Token.
    Generate one from Firefly III UI: Options -> Profile -> OAuth -> Personal Access Tokens.
    """
    print("Firefly III is using remote_user_guard (no built-in login).")
    print("You need a Personal Access Token (PAT) from Firefly III.")
    print("1. Open Firefly III via the Authentik-protected URL")
    print("2. Go to Options -> Profile -> OAuth")
    print("3. Create a Personal Access Token")
    print("4. Re-run this script with --firefly-token <PAT>")
    return None


def main():
    parser = argparse.ArgumentParser(description="Seed Firefly III from expense tracker")
    parser.add_argument("--expense-token", required=True, help="Firebase JWT from expense tracker")
    parser.add_argument("--firefly-url", required=True, help="Firefly III base URL (e.g. https://firefly.sirius.moonblade.work)")
    parser.add_argument("--firefly-token", required=False, help="Firefly III Personal Access Token")
    parser.add_argument("--months", type=int, default=3, help="How many months of data to pull (default: 3)")
    parser.add_argument("--dry-run", action="store_true", help="Fetch and display transactions without pushing")
    args = parser.parse_args()

    if not args.firefly_token and not args.dry_run:
        get_firefly_token_via_remote_user(args.firefly_url)
        return

    print(f"Fetching {args.months} months of transactions from expense tracker...")
    transactions = fetch_transactions(args.expense_token, args.months)
    print(f"Found {len(transactions)} transactions")

    # Filter out ignored transactions
    active = [t for t in transactions if not t.get("ignore", False)]
    print(f"Active (non-ignored): {len(active)}")

    if args.dry_run:
        for t in active[:20]:
            ts = t.get("timestamp", 0)
            if ts > 1e10:
                ts = ts / 1000
            date = datetime.fromtimestamp(ts).strftime("%Y-%m-%d") if ts else "?"
            print(f"  {date} | {t.get('transactiontype','?'):6} | {t.get('amount',0):>10.2f} | {t.get('merchant','?')[:30]:30} | {t.get('category','?')}")
        if len(active) > 20:
            print(f"  ... and {len(active) - 20} more")
        return

    print(f"\nPushing to Firefly III at {args.firefly_url}...")
    success = 0
    failed = 0
    for i, t in enumerate(active):
        result = create_firefly_transaction(args.firefly_url, args.firefly_token, t)
        if result:
            success += 1
        else:
            failed += 1
        if (i + 1) % 50 == 0:
            print(f"  Progress: {i+1}/{len(active)} (success={success}, failed={failed})")

    print(f"\nDone! Created {success} transactions, {failed} failed.")


if __name__ == "__main__":
    main()
