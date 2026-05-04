import urllib.request, re

for name, url in [
    ('阿里云 releases', 'https://mirrors.aliyun.com/ubuntu-releases/'),
    ('清华 cdimage', 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/'),
]:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        r = urllib.request.urlopen(req, timeout=15)
        html = r.read().decode('utf-8', errors='ignore')
        matches = re.findall(r'href="([^"]*(?:ubuntu-base|24\.04)[^"]*\.tar\.(?:gz|xz))"', html)
        print(f'{name}: found {len(matches)} tarball links')
        for m in matches[:10]:
            print(f'  {m}')
        if not matches:
            dirs = re.findall(r'href="([^"]*24[^"]*)"', html)[:10]
            for d in dirs:
                print(f'  dir: {d}')
        r.close()
    except Exception as e:
        print(f'{name}: ERROR {e}')
