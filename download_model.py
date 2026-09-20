import os
import urllib.request

def download():
    os.makedirs("assets/models/embedding", exist_ok=True)
    target = "assets/models/embedding/model_quantized.onnx"

    if os.path.exists(target) and os.path.getsize(target) > 20 * 1024 * 1024:
        print(f"Model already exists ({os.path.getsize(target)} bytes).")
        return

    url = "https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/onnx/model_quantized.onnx"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    print(f"Downloading {url} to {target}...")
    with urllib.request.urlopen(req) as resp, open(target, "wb") as out:
        total = int(resp.headers.get("content-length", 0))
        downloaded = 0
        chunk_size = 1024 * 256
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            out.write(chunk)
            downloaded += len(chunk)
            if total > 0:
                pct = int(downloaded * 100 / total)
                print(f"\rProgress: {pct}% ({downloaded // (1024*1024)}MB / {total // (1024*1024)}MB)", end="", flush=True)

    print(f"\nDownloaded model ({os.path.getsize(target)} bytes).")

if __name__ == "__main__":
    download()
