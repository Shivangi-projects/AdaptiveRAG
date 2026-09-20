from PIL import Image, ImageDraw
import os

def create_icon():
    os.makedirs("assets/icons", exist_ok=True)
    size = (512, 512)
    img = Image.new("RGBA", size, (11, 19, 37, 255))
    draw = ImageDraw.Draw(img)

    # Gradient circle background
    for r in range(230, 0, -2):
        alpha = int(255 * (r / 230))
        color = (15 + int(20 * (1 - r/230)), 37 + int(40 * (1 - r/230)), 87 + int(60 * (1 - r/230)), 255)
        draw.ellipse([256 - r, 256 - r, 256 + r, 256 + r], fill=color)

    # Outer shield / border ring
    draw.ellipse([56, 56, 456, 456], outline=(56, 189, 248, 200), width=8)

    # EdgeRAG nodes and connection lines
    nodes = [
        (256, 150), # Top
        (160, 220), # Mid left
        (352, 220), # Mid right
        (190, 330), # Bot left
        (322, 330), # Bot right
        (256, 260), # Center
    ]

    # Draw connection lines
    connections = [
        (0, 1), (0, 2), (1, 5), (2, 5), (1, 3), (2, 4), (3, 5), (4, 5), (3, 4)
    ]
    for n1, n2 in connections:
        draw.line([nodes[n1], nodes[n2]], fill=(56, 189, 248, 220), width=5)

    # Draw nodes
    for x, y in nodes:
        draw.ellipse([x - 14, y - 14, x + 14, y + 14], fill=(37, 99, 235, 255), outline=(56, 189, 248, 255), width=3)

    # Central glowing core
    cx, cy = nodes[5]
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(56, 189, 248, 255))

    # Local indicator badge (green pulse at bottom right)
    draw.ellipse([360, 360, 420, 420], fill=(16, 185, 129, 255), outline=(255, 255, 255, 230), width=4)

    icon_path = "assets/icons/icon.png"
    img.save(icon_path)
    print(f"Saved icon to {icon_path}")

    # Generate mipmap sizes for Android
    mipmaps = {
        "mipmap-mdpi": (48, 48),
        "mipmap-hdpi": (72, 72),
        "mipmap-xhdpi": (96, 96),
        "mipmap-xxhdpi": (144, 144),
        "mipmap-xxxhdpi": (192, 192),
    }

    for folder, dim in mipmaps.items():
        dir_path = f"android/app/src/main/res/{folder}"
        os.makedirs(dir_path, exist_ok=True)
        resized = img.resize(dim, Image.Resampling.LANCZOS)
        resized.save(f"{dir_path}/ic_launcher.png")

    print("Generated all Android mipmap launcher icons.")

if __name__ == "__main__":
    create_icon()
