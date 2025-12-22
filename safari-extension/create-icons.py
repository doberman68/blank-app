#!/usr/bin/env python3
"""
Simple icon generator for the Safari extension.
Requires PIL/Pillow: pip install Pillow
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os

    def create_icon(size):
        # Create a new image with blue background
        img = Image.new('RGB', (size, size), color='#0066cc')
        draw = ImageDraw.Draw(img)

        # Scale factor
        scale = size / 128

        # Draw three white rectangles representing folders
        folder_color = (255, 255, 255)

        # Folder 1
        x1, y1 = int(32 * scale), int(34 * scale)
        w1, h1 = int(24 * scale), int(18 * scale)
        draw.rectangle([x1, y1, x1 + w1, y1 + h1], fill=folder_color)

        # Folder 2
        x2, y2 = int(48 * scale), int(54 * scale)
        w2, h2 = int(24 * scale), int(18 * scale)
        draw.rectangle([x2, y2, x2 + w2, y2 + h2], fill=folder_color)

        # Folder 3
        x3, y3 = int(64 * scale), int(74 * scale)
        w3, h3 = int(24 * scale), int(18 * scale)
        draw.rectangle([x3, y3, x3 + w3, y3 + h3], fill=folder_color)

        return img

    # Create icons directory if it doesn't exist
    icons_dir = os.path.join(os.path.dirname(__file__), 'icons')
    os.makedirs(icons_dir, exist_ok=True)

    # Generate icons in different sizes
    for size in [48, 96, 128]:
        icon = create_icon(size)
        icon.save(os.path.join(icons_dir, f'icon-{size}.png'))
        print(f'Created icon-{size}.png')

    print('All icons created successfully!')

except ImportError:
    print('PIL/Pillow not installed.')
    print('Please install it with: pip install Pillow')
    print('Or use the generate-icons.html file in a web browser to create icons manually.')
