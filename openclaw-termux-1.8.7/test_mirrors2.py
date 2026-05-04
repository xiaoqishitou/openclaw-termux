import urllib.request, urllib.error, time

def test_url(url):
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            elapsed = (time.time() - start) * 1000
            size = int(r.headers.get('Content-Length', 0))
            return True, size / 1024 / 1024, elapsed
    except Exception as e:
        return False, 0, (time.time() - start) * 1000

print("Testing more mirror URLs for Ubuntu rootfs...")
print("=" * 70)

# Test various possible URLs for ubuntu-base on Chinese mirrors
urls_to_test = [
    # Aliyun
    ("阿里云 ubuntu-releases", "https://mirrors.aliyun.com/ubuntu-releases/24.04.3/ubuntu-24.04.3-base-arm64.tar.gz"),
    ("阿里云 ubuntu-releases(alt)", "https://mirrors.aliyun.com/ubuntu-releases/24.04/ubuntu-24.04-base-arm64.tar.gz"),
    # Tsinghua
    ("清华 ubuntu-releases", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04.3/ubuntu-24.04.3-base-arm64.tar.gz"),
    ("清华 ubuntu-releases(alt)", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04/ubuntu-24.04-base-arm64.tar.gz"),
    # USTC
    ("中科大 ubuntu-releases", "https://mirrors.ustc.edu.cn/ubuntu-releases/24.04.3/ubuntu-24.04.3-base-arm64.tar.gz"),
    ("中科大 ubuntu-releases(alt)", "https://mirrors.ustc.edu.cn/ubuntu-releases/24.04/ubuntu-24.04-base-arm64.tar.gz"),
    # Aliyun with different path patterns
    ("阿里云 cloud-images", "https://mirrors.aliyun.com/cloud-images/releases/server/releases/24.04/release-20250415/ubuntu-24.04-server-cloudimg-arm64-root.tar.xz"),
    ("清华 cloud-images", "https://mirrors.tuna.tsinghua.edu.cn/cloud-images/releases/server/releases/24.04/release-20250415/ubuntu-24.04-server-cloudimg-arm64-root.tar.xz"),
]

for name, url in urls_to_test:
    ok, size_mb, ms = test_url(url)
    status = f"✅ {size_mb:.1f}MB" if ok else f"❌ FAIL"
    print(f"  [{name:25s}] {status:20s} | {ms:.0f}ms")
    if not ok:
        print(f"                         {url}")

# Also check if we can find the correct path by testing base dirs
print("\n\nTesting base directory availability:")
base_dirs = [
    ("阿里云 ubuntu-cdimage", "https://mirrors.aliyun.com/ubuntu-cdimage/"),
    ("阿里云 ubuntu-releases", "https://mirrors.aliyun.com/ubuntu-releases/"),
    ("阿里云 cloud-images", "https://mirrors.aliyun.com/cloud-images/"),
    ("清华 ubuntu-cdimage", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/"),
    ("清华 ubuntu-releases", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/"),
    ("中科大 ubuntu-releases", "https://mirrors.ustc.edu.cn/ubuntu-releases/"),
]
for name, url in base_dirs:
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    try:
        r = urllib.request.urlopen(req, timeout=10)
        print(f"  ✅ {name}: HTTP {r.status}")
        r.close()
    except Exception as e:
        print(f"  ❌ {name}: {e}")
