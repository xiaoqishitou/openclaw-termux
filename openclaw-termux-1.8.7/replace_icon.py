import os, sys
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FLUTTER_DIR = os.path.join(SCRIPT_DIR, 'flutter_app')

# Source image - update this path to your lobster image
SOURCE_IMAGE = os.path.join(FLUTTER_DIR, 'assets', 'ic_launcher_new.png')

# Android mipmap sizes
SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

RES_DIR = os.path.join(FLUTTER_DIR, 'android', 'app', 'src', 'main', 'res')

def make_rounded(img, size):
    """Create a rounded square icon with the image centered."""
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    # Create rounded rectangle mask
    mask = Image.new('L', (size, size), 0)
    radius = int(size * 0.2)
    for y in range(size):
        for x in range(size):
            # Distance from corners
            dx = max(0, abs(x - radius) - (size - 1 - 2 * radius) / 2)
            dy = max(0, abs(y - radius) - (size - 1 - 2 * radius) / 2)
            dist = (dx ** 2 + dy ** 2) ** 0.5
            if dist <= radius:
                mask.putpixel((x, y), 255)
            elif dist <= radius + 1:
                alpha = int(255 * (1 - (dist - radius)))
                mask.putpixel((x, y), min(255, max(0, alpha)))
    
    # Resize source image to fit
    resized = img.resize((size, size), Image.LANCZOS)
    # Apply mask
    output.paste(resized, (0, 0))
    return output

def main():
    if not os.path.exists(SOURCE_IMAGE):
        print(f'ERROR: Source image not found at {SOURCE_IMAGE}')
        print('Please save your lobster image to: {SOURCE_IMAGE}')
        sys.exit(1)

    img = Image.open(SOURCE_IMAGE).convert('RGBA')
    print(f'Source image: {img.size[0]}x{img.size[1]}')

    # Generate adaptive icon foreground (108dp = 432px for xxxhdpi)
    fg_size = 432
    fg_dir = os.path.join(RES_DIR, 'drawable-anydpi-v26')
    os.makedirs(os.path.dirname(fg_dir), exist_ok=True)
    fg_path = os.path.join(fg_dir, 'ic_launcher_foreground.png') if os.path.isdir(fg_dir) else os.path.join(RES_DIR, 'drawable', 'ic_launcher_foreground.png')

    # Replace assets/ic_launcher.png (used by Flutter)
    asset_path = os.path.join(FLUTTER_DIR, 'assets', 'ic_launcher.png')
    img_512 = img.resize((512, 512), Image.LANCZOS)
    img_512.save(asset_path, 'PNG')
    print(f'  -> {asset_path} (512x512)')

    # Generate each mipmap size
    for folder, size in SIZES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, 'ic_launcher.png')
        
        resized = img.resize((size, size), Image.LANCZOS)
        resized.save(out_path, 'PNG')
        print(f'  -> {out_path} ({size}x{size})')

    print('\nDone! All icons replaced.')

if __name__ == '__main__':
    main()
