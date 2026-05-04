import urllib.request, urllib.error, time

MIRRORS = {
    "Ubuntu rootfs (阿里云镜像)": [
        ("https://mirrors.aliyun.com/ubuntu-cdimage/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz", "arm64"),
        ("https://mirrors.aliyun.com/ubuntu-cdimage/releases/24.04/release/ubuntu-base-24.04.3-base-armhf.tar.gz", "armhf"),
        ("https://mirrors.aliyun.com/ubuntu-cdimage/releases/24.04/release/ubuntu-base-24.04.3-base-amd64.tar.gz", "amd64"),
    ],
    "Ubuntu rootfs (清华镜像)": [
        ("https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz", "arm64"),
        ("https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/releases/24.04/release/ubuntu-base-24.04.3-base-armhf.tar.gz", "armhf"),
    ],
    "Node.js (npmmirror镜像)": [
        ("https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-arm64.tar.xz", "arm64"),
        ("https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-armv7l.tar.xz", "armv7l"),
        ("https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-x64.tar.xz", "x64"),
    ],
    "npm 包 (npmmirror)": [
        ("https://registry.npmmirror.com/openclaw/-/openclaw-2026.5.2.tgz", "openclaw tgz"),
    ],
}

def test_url(url, label=""):
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            elapsed = (time.time() - start) * 1000
            size = int(r.headers.get('Content-Length', 0))
            size_mb = size / 1024 / 1024
            status = r.status
            return True, status, size_mb, elapsed
    except urllib.error.HTTPError as e:
        elapsed = (time.time() - start) * 1000
        return False, e.code, 0, elapsed
    except Exception as e:
        elapsed = (time.time() - start) * 1000
        return False, str(e), 0, elapsed

print("=" * 80)
print("Testing Chinese mirror sources for bundled dependencies")
print("=" * 80)

results = {}
for name, urls in MIRRORS.items():
    print(f"\n{'─' * 70}")
    print(f"  {name}")
    print(f"{'─' * 70}")
    for url, arch in urls:
        ok, status, size_mb, ms = test_url(url)
        status_str = "✅ OK" if ok else f"❌ FAIL ({status})"
        size_str = f"{size_mb:.1f}MB" if size_mb > 0 else "N/A"
        print(f"  [{arch:8s}] {status_str:15s} | {size_str:>10s} | {ms:.0f}ms")
        if not ok:
            print(f"           URL: {url}")
        results[name] = results.get(name, True) and ok

print(f"\n{'=' * 80}")
print("Summary:")
for name, ok in results.items():
    status = "✅ Available" if ok else "❌ Unavailable"
    print(f"  {name}: {status}")
print("=" * 80)
