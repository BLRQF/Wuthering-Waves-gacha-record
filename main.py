
import json
from pathlib import Path
from datetime import datetime
from urllib.parse import urlparse, parse_qs
import requests

API_URL = "https://gmserver-api.aki-game2.com/gacha/record/query"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0",
    "Content-Type": "application/json",
    "Referer": "https://aki-gm-resources.aki-game.com/",
    "Origin": "https://aki-gm-resources.aki-game.com"
}

CARD_POOL_MAP = {
    1: "角色活动唤取",
    2: "武器活动唤取",
    3: "角色常驻唤取",
    4: "武器常驻唤取",
    5: "新手唤取",
    6: "新手自选唤取",
    7: "新手自选唤取（感恩定向唤取）",
    8: "角色新旅唤取",
    9: "武器新旅唤取"
}


def parse_time_str(time_str):
    """把字符串解析为 datetime 对象"""
    return datetime.strptime(time_str, "%Y-%m-%d %H:%M:%S")


def parse_gacha_url(url):
    """解析抽卡分享链接，生成 API 查询负载模板。"""
    parsed = urlparse(url)
    hash_params = parse_qs(parsed.fragment.split("?", 1)[1])
    params = {k: v[0] for k, v in hash_params.items()}
    return {
        "playerId": params["player_id"],
        "cardPoolId": params["resources_id"],
        "serverId": params["svr_id"],
        "languageCode": params["lang"],
        "recordId": params["record_id"],
        "cardPoolType": None
    }


def empty_record():
    """返回空抽卡记录结构。"""
    return {"date": "", "number": 0, "data": []}


def fetch_gacha_records(session, payload_template, pool_type):
    """请求指定池类型的抽卡记录。"""
    payload = payload_template.copy()
    payload["cardPoolType"] = pool_type
    response = session.post(API_URL, json=payload)
    response.raise_for_status()
    data = response.json()
    if data.get("code") != 0:
        raise ValueError(f"API 返回错误: {data.get('message')}")
    return data.get("data", [])


def merge_new_records(existing, new):
    """合并新旧抽卡记录"""
    if not existing:
        return new
    try:
        latest_time = parse_time_str(existing[0]["time"])
    except Exception:
        latest_time = None
    merged = []
    for rec in new:
        try:
            dt = parse_time_str(rec.get("time"))
        except Exception:
            continue
        if latest_time is None or dt > latest_time:
            merged.append(rec)
        else:
            break
    return merged + existing if merged else existing


def update_record_file(all_records):
    """一次性写入所有抽卡池记录到文件。"""
    out_path = Path("./鸣潮抽卡记录.json")
    out_data = {}
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if out_path.exists():
        with out_path.open("r", encoding="utf-8") as f:
            existing = json.load(f)
    else:
        existing = {name: empty_record() for name in CARD_POOL_MAP.values()}

    for pool_name, records in all_records.items():
        prev = existing.get(pool_name, empty_record())
        merged = merge_new_records(prev.get("data", []), records)
        out_data[pool_name] = {
            "date": now if merged else prev.get("date", ""),
            "number": len(merged),
            "data": merged,
        }

    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out_data, f, ensure_ascii=False, indent=4)


def main():
    session = requests.Session()
    session.headers.update(HEADERS)
    gacha_url = input("请输入抽卡记录链接: ").strip()
    payload_template = parse_gacha_url(gacha_url)
    all_records = {}
    for pool_type, pool_name in CARD_POOL_MAP.items():
        print(f"正在抓取 {pool_name} 的抽卡记录...")
        records = fetch_gacha_records(session, payload_template, pool_type)
        all_records[pool_name] = records
    update_record_file(all_records)
    session.close()
    print("所有抽卡记录抓取并保存完毕。")


if __name__ == "__main__":
    main()
