import urllib.request, re

# Check tsinghua cdimage release/ subdirectory
url = 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/releases/24.04.3/release/'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    r = urllib.request.urlopen(req, timeout=15)
    html = r.read().decode('utf-8', errors='ignore')
    r.close()
    links = re.findall(r'href="([^"]+)"', html)
    print(f"Tsinghua cdimage 24.04.3/release/ ({len(links)} entries):")
    for l in sorted(links):
        if not l.startswith('/') and not l.startswith('http') and not l.startswith('?') and l.endswith('.tar.gz'):
            print(f'  {l}')
except Exception as e:
    print(f'Tsinghua: {e}')

# Final: test the exact original URL path on mirrors
print("\n\nFinal mirror URL tests:")
final_tests = [
    ("清华 base releases", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz"),
    ("清华 base releases(alt)", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-base/releases/24.04/release/ubuntu-base-24.04-base-arm64.tar.gz"),
]
for name, url in final_tests:
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    try:
        r = urllib.request.urlopen(req, timeout=10)
        size = int(r.headers.get('Content-Length', 0))
        print(f"  ✅ {name}: HTTP {r.status} ({size/1024/1024:.1f}MB)")
        r.close()
    except Exception as e:
        print(f"  ❌ {name}: {e}")
