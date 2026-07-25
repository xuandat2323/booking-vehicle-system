"""Smoke test cho chatbot tìm xe: kiểm tra parse tiêu chí và độ khớp AND.

Chạy: python scripts/chatbot_smoke_test.py
"""

import json
import urllib.request

BASE = "http://localhost:8080"
QUESTIONS = [
    "Toyota 7 chỗ",
    "Mercedes 7 chỗ",
    "xe 7 chỗ dưới 1 triệu",
    "VinFast điện ở Cầu Giấy",
    "xe 5 chỗ số tự động ở Thanh Xuân dưới 1.5 triệu",
    "kia 5 cho gia re",
]


def post(path, payload, token=None):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        BASE + path,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    login = post("/api/auth/login", {"phone": "+84123456789", "password": "Password123!"})
    token = login["data"].get("accessToken") or login["data"].get("token")
    print("login ok:", bool(token))

    for q in QUESTIONS:
        res = post("/api/chatbot/ask", {"question": q}, token)["data"]
        print("\n" + "=" * 70)
        print("Q       :", q)
        print("filters :", json.dumps(res.get("filters"), ensure_ascii=False))
        print("matched :", " | ".join(res.get("matchedCriteria") or []))
        print("unmatch :", " | ".join(res.get("unmatchedCriteria") or []))
        print("relaxed :", res.get("relaxed"), "| total:", res.get("totalFound"))
        print("answer  :", (res.get("answer") or "").replace("\n", "\n          "))
        for car in (res.get("cars") or [])[:3]:
            print(
                f"   - {car.get('brand')} {car.get('name')} | {car.get('seats')} chỗ "
                f"| {car.get('pricePerDay')} | {car.get('branchName')}"
            )


if __name__ == "__main__":
    main()
