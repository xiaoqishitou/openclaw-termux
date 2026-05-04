import urllib.request, re

# Dig into aliyun 24.04.3 directory
url = 'https://mirrors.aliyun.com/ubuntu-releases/24.04.3/'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
r = urllib.request.urlopen(req, timeout=15)
html = r.read().decode('utf-8', errors='ignore')
r.close()

# Find all links
links = re.findall(r'href="([^"]+)"', html)
print(f"Files in 24.04.3 ({len(links)} entries):")
for l in sorted(links):
    if not l.startswith('http') and not l.startswith('?') and not l.startswith('#'):
        print(f'  {l}')

# Also check cdimage path structure
print("\n\nChecking cdimage releases path:")
url2 = 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/releases/'
req2 = urllib.request.Request(url2, headers={'User-Agent': 'Mozilla/5.0'})
r2 = urllib.request.urlopen(req2, timeout=15)
html2 = r2.read().decode('utf-8', errors='ignore')
r2.close()
dirs = re.findall(r'href="([^"]*24[^"]*)"', html2)
for d in dirs[:10]:
    print(f'  {d}')
