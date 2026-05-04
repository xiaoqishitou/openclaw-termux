import os, sys, urllib.request, shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, 'flutter_app', 'assets', 'bundle')
os.makedirs(ASSETS_DIR, exist_ok=True)

def download(url, dest, description):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print(f'  [SKIP] {description} (already exists: {os.path.getsize(dest)/1024/1024:.1f}MB)')
        return
    print(f'  [DOWNLOAD] {description}')
    print(f'    URL: {url}')
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=300) as r:
        total = int(r.headers.get('Content-Length', 0))
        with open(dest + '.tmp', 'wb') as f:
            downloaded = 0
            while True:
                chunk = r.read(1024*1024)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    pct = downloaded / total * 100
                    print(f'    ... {downloaded/1024/1024:.1f}MB / {total/1024/1024:.1f}MB ({pct:.1f}%)', end='\r')
    print()
    os.rename(dest + '.tmp', dest)
    print(f'  [DONE] {description} ({os.path.getsize(dest)/1024/1024:.1f}MB)')

print('=' * 60)
print('Downloading bundled assets for offline installation')
print(f'Target: {ASSETS_DIR}')
print('(Using Chinese mirrors where available)')
print('=' * 60)

# 1. Ubuntu rootfs (arm64 - most common Android arch)
# NOTE: No Chinese mirror available for ubuntu-base; using original source
rootfs_url = 'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-arm64.tar.gz'
rootfs_dest = os.path.join(ASSETS_DIR, 'ubuntu-base-24.04-arm64.tar.gz')
download(rootfs_url, rootfs_dest, 'Ubuntu 24.04 rootfs (arm64) [original]')

# 2. Node.js v22.14.0 (arm64) - npmmirror
node_url = 'https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-arm64.tar.xz'
node_dest = os.path.join(ASSETS_DIR, 'node-v22.14.0-linux-arm64.tar.xz')
download(node_url, node_dest, 'Node.js v22.14.0 (arm64) [npmmirror]')

# Also get armeabi-v7a for wider compatibility
print()
print('-' * 60)
print('Optional: armeabi-v7a downloads (for older devices)')
print('-' * 60)

rootfs_arm_url = 'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-armhf.tar.gz'
rootfs_arm_dest = os.path.join(ASSETS_DIR, 'ubuntu-base-24.04-armhf.tar.gz')
download(rootfs_arm_url, rootfs_arm_dest, 'Ubuntu 24.04 rootfs (armhf) [original]')

node_arm_url = 'https://registry.npmmirror.com/-/binary/node/v22.14.0/node-v22.14.0-linux-armv7l.tar.xz'
node_arm_dest = os.path.join(ASSETS_DIR, 'node-v22.14.0-linux-armv7l.tar.xz')
download(node_arm_url, node_arm_dest, 'Node.js v22.14.0 (armv7l) [npmmirror]')

# 3. OpenClaw npm package - npmmirror
print()
print('-' * 60)
print('OpenClaw package (npmmirror)')
print('-' * 60)
openclaw_url = 'https://registry.npmmirror.com/openclaw/-/openclaw-2026.5.2.tgz'
openclaw_dest = os.path.join(ASSETS_DIR, 'openclaw-2026.5.2.tgz')
download(openclaw_url, openclaw_dest, 'OpenClaw 2026.5.2 [npmmirror]')

print()
print('=' * 60)
print('Bundle summary:')
for f in sorted(os.listdir(ASSETS_DIR)):
    path = os.path.join(ASSETS_DIR, f)
    size_mb = os.path.getsize(path) / 1024 / 1024
    print(f'  {f}: {size_mb:.1f}MB')
total = sum(os.path.getsize(os.path.join(ASSETS_DIR, f)) for f in os.listdir(ASSETS_DIR))
print(f'  Total: {total/1024/1024:.1f}MB')
print('=' * 60)
