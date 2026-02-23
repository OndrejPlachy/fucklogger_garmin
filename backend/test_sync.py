import requests
import json
import time

API_URL = "http://localhost:3000/api"
API_KEY = "your-secret-key-here"

def test_sync():
    print("Testing /api/sync...")
    payload = {
        "deviceId": "test-device-py",
        "syncedAt": "2026-02-17T12:00:00",
        "records": [
            {
                "date": "2026-02-17",
                "count": 10,
                "horniness": 5,
                "distribution": [0,0,0,0,10]
            }
        ]
    }
    
    try:
        response = requests.post(
            f"{API_URL}/sync",
            json=payload,
            headers={"X-API-Key": API_KEY}
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        if response.status_code == 200:
            print("PASS: Sync successful")
        else:
            print("FAIL: Sync failed")
    except Exception as e:
        print(f"FAIL: {e}")

def test_get_data():
    print("\nTesting /api/data...")
    try:
        response = requests.get(
            f"{API_URL}/data",
            headers={"X-API-Key": API_KEY}
        )
        print(f"Status: {response.status_code}")
        data = response.json()
        print(f"Records found: {len(data)}")
        if len(data) > 0:
             print(f"Sample record: {data[0]}")
        print("PASS: Data retrieval successful")
    except Exception as e:
        print(f"FAIL: {e}")

if __name__ == "__main__":
    # Wait a moment for server to be fully up if just started
    time.sleep(1)
    test_sync()
    test_get_data()
