from PIL import Image
import os

img_path = r"d:\Dev\best_flutter_ui_templates\assets\images\signin_logo.png"

try:
    img = Image.open(img_path).convert("RGBA")
    datas = img.getdata()

    newData = []
    # Let's say the logo is white and everything else is dark.
    # If pixel is bright (e.g. all R,G,B > 200), keep it white. Else make it transparent.
    for item in datas:
        # item is (R, G, B, A)
        if item[0] > 180 and item[1] > 180 and item[2] > 180:
            # It's part of the white logo
            newData.append((255, 255, 255, item[3]))
        else:
            # Make it transparent
            newData.append((0, 0, 0, 0))

    img.putdata(newData)
    img.save(img_path, "PNG")
    print("Successfully removed background!")
except Exception as e:
    print(f"Error: {e}")
