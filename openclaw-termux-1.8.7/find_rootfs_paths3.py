import urllib.request, re

# Check cdimage base path on tsinghua
url = 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/releases/24.04.3/'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    r = urllib.request.urlopen(req, timeout=15)
    html = r.read().decode('utf-8', errors='ignore')
    r.close()
    links = re.findall(r'href="([^"]+)"', html)
    print(f"Tsinghua cdimage 24.04.3 ({len(links)} entries):")
    for l in sorted(links):
        if not l.startswith('http') and not l.startswith('?') and not l.startswith('#'):
            print(f'  {l}')
except Exception as e:
    print(f'Tsinghua cdimage: {e}')

# Also check if aliyun has cdimage
print("\n\nAliyun cdimage releases:")
url2 = 'https://mirrors.aliyun.com/ubuntu-cdimage/releases/24.04.3/'
req2 = urllib.request.Request(url2, headers={'User-Agent': 'Mozilla/5.0'})
try:
    r2 = urllib.request.urlopen(req2, timeout=15)
    html2 = r2.read().decode('utf-8', errors='ignore')
    r2.close()
    links2 = re.findall(r'href="([^"]+)"', html2)
    for l in sorted(links2):
        if 'base' in l.lower() or 'ubuntu' in l.lower():
            print(f'  {l}')
except Exception as e:
    print(f'Aliyun cdimage: {e}')

# Try direct test of known working paths
print("\n\nDirect URL tests:")
test_urls = [
    ("阿里云 netboot arm64", "https://mirrors.aliyun.com/ubuntu-releases/24.04.3/netboot/arm64-initrd"),
    ("清华 cdimage base dir", "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/base/releases/"),
]
for name, url in test_urls:
    req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
    try:
        r = urllib.request.urlopen(req, timeout=10)
        print(f"  ✅ {name}: HTTP {r.status}")
        r.close()
    except Exception as e:
        print(f"  ❌ {name}: {e}")
