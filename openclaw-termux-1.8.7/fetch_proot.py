import os, sys, urllib.request, tempfile, shutil, tarfile, io

TERMUX_REPO = 'https://packages.termux.dev/apt/termux-main'
JNI_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flutter_app', 'android', 'app', 'src', 'main', 'jniLibs')

def fetch_pkg(pkg_name, deb_arch, extract_dir):
    print(f'  Fetching {pkg_name} for {deb_arch}...')
    try:
        req = urllib.request.Request(
            f'{TERMUX_REPO}/dists/stable/main/binary-{deb_arch}/Packages',
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=60) as r:
            content = r.read().decode('utf-8')
        pkg_url = None
        found = False
        for line in content.split('\n'):
            if line == f'Package: {pkg_name}':
                found = True
            elif found and line.startswith('Filename: '):
                pkg_url = line[10:]
                break
        if not pkg_url:
            print(f'    WARN: {pkg_name} not found')
            return False
        os.makedirs(extract_dir, exist_ok=True)
        deb_file = os.path.join(extract_dir, f'{pkg_name}-{deb_arch}.deb')
        print(f'    Downloading {pkg_url}...')
        req2 = urllib.request.Request(f'{TERMUX_REPO}/{pkg_url}', headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req2, timeout=120) as r:
            with open(deb_file, 'wb') as df:
                df.write(r.read())
        print(f'    Downloaded {os.path.getsize(deb_file)} bytes')
        # Extract .deb (ar archive)
        with open(deb_file, 'rb') as f:
            magic = f.read(8)
            if magic != b'!<arch>\n':
                print(f'    ERROR: Not a valid ar archive')
                return False
            while True:
                header = f.read(60)
                if len(header) < 60:
                    break
                name = header[0:16].decode('ascii', errors='ignore').strip().rstrip('/')
                size_str = header[48:58].decode('ascii', errors='ignore').strip()
                size = int(size_str) if size_str else 0
                if name.startswith('data.tar'):
                    data = f.read(size)
                    print(f'    Found {name} ({len(data)} bytes)')
                    # Decompress tar
                    if name.endswith('.xz'):
                        import lzma
                        tar_data = lzma.decompress(data)
                    elif name.endswith('.gz'):
                        import gzip
                        tar_data = gzip.decompress(data)
                    else:
                        tar_data = data
                    # Extract with Python tarfile
                    print(f'    Extracting tar...')
                    with tarfile.open(fileobj=io.BytesIO(tar_data), mode='r:') as tf:
                        for member in tf.getmembers():
                            # Strip leading ./data/data/com.termux/files/usr/
                            parts = member.name.split('/')
                            if len(parts) > 6 and parts[1] == 'data' and parts[5] == 'usr':
                                new_name = '/'.join(parts[6:])
                                if new_name:
                                    member.name = new_name
                                    tf.extract(member, extract_dir)
                            elif member.name.startswith('./'):
                                member.name = member.name[2:]
                                if member.name:
                                    tf.extract(member, extract_dir)
                    break
                elif size > 0:
                    f.read(size)
                    if f.tell() % 2 != 0:
                        f.read(1)
        return True
    except Exception as e:
        import traceback
        print(f'    ERROR: {e}')
        traceback.print_exc()
        return False

abis = [('arm64-v8a', 'aarch64'), ('armeabi-v7a', 'arm'), ('x86_64', 'x86_64')]
for jni_abi, deb_arch in abis:
    out_dir = os.path.join(JNI_DIR, jni_abi)
    os.makedirs(out_dir, exist_ok=True)
    print(f'[{jni_abi}]')
    tmp = tempfile.mkdtemp()
    print(f'  Temp dir: {tmp}')
    proot_dir = os.path.join(tmp, 'proot')
    if fetch_pkg('proot', deb_arch, proot_dir):
        found_proot = False
        found_loader = False
        for root, dirs, files in os.walk(proot_dir):
            for f in files:
                if f == 'proot' and 'bin' in root and not found_proot:
                    src = os.path.join(root, f)
                    dst = os.path.join(out_dir, 'libproot.so')
                    shutil.copy2(src, dst)
                    print(f'    -> libproot.so ({os.path.getsize(dst)} bytes)')
                    found_proot = True
                elif f == 'loader' and 'proot' in root and not found_loader:
                    src = os.path.join(root, f)
                    dst = os.path.join(out_dir, 'libprootloader.so')
                    shutil.copy2(src, dst)
                    print(f'    -> libprootloader.so ({os.path.getsize(dst)} bytes)')
                    found_loader = True
                elif f == 'loader32' and 'proot' in root:
                    src = os.path.join(root, f)
                    dst = os.path.join(out_dir, 'libprootloader32.so')
                    shutil.copy2(src, dst)
                    print(f'    -> libprootloader32.so ({os.path.getsize(dst)} bytes)')
    talloc_dir = os.path.join(tmp, 'talloc')
    if fetch_pkg('libtalloc', deb_arch, talloc_dir):
        for root, dirs, files in os.walk(talloc_dir):
            for f in files:
                if f.startswith('libtalloc.so'):
                    src = os.path.join(root, f)
                    dst = os.path.join(out_dir, 'libtalloc.so')
                    shutil.copy2(src, dst)
                    print(f'    -> libtalloc.so ({os.path.getsize(dst)} bytes)')
                    break
    shutil.rmtree(tmp, ignore_errors=True)

print('\n=== Results ===')
for root, dirs, files in os.walk(JNI_DIR):
    for f in files:
        if f.endswith('.so'):
            path = os.path.join(root, f)
            print(f'{path} ({os.path.getsize(path)} bytes)')
