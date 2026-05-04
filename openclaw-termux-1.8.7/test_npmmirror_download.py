import urllib.request

# Test actual download from npmmirror (just first 1MB to verify)
url = 'https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-arm64.tar.xz'
print(f'Testing download from: {url}')
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=30) as r:
    size = int(r.headers.get('Content-Length', 0))
    print(f'File size: {size/1024/1024:.1f}MB')
    # Download first 100KB to verify
    data = r.read(1024*100)
    print(f'Downloaded first {len(data)/1024:.0f}KB successfully - ✅ Mirror works!')
