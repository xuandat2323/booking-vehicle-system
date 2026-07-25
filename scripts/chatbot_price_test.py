"""Kiểm tra parse giá của chatbot (đặc biệt 'trên/hơn/dưới')."""

import json
import urllib.request

BASE = "http://localhost:8080"
QUESTIONS = [
    "xe giá trên 2 triệu",
    "xe hơn 2 triệu",
    "xe trên 1 triệu",
    "xe dưới 2 triệu",
    "xe từ 1 đến 2 triệu",
    "xe khoảng 1 triệu",
    "xe giá rẻ",
    "xe cao cấp",
]


def post(path, payload, token=None):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        BASE + path, data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    login = post("/api/auth/login", {"phone": "+84123456789", "password": "Password123!"})
    token = login["data"].get("accessToken") or login["data"].get("token")
    for q in QUESTIONS:
        res = post("/api/chatbot/ask", {"question": q}, token)["data"]
        print("\nQ:", q)
        print("  filters:", json.dumps(res.get("filters"), ensure_ascii=False))
        prices = [c.get("pricePerDay") for c in (res.get("cars") or [])[:5]]
        print("  prices :", prices)


if __name__ == "__main__":
    main()
