import base64
import re

def bundle():
    # Read the files
    with open('build/web/index.wasm', 'rb') as f:
        wasm_b64 = base64.b64encode(f.read()).decode('utf-8')
    with open('build/web/index.pck', 'rb') as f:
        pck_b64 = base64.b64encode(f.read()).decode('utf-8')
    with open('build/web/index.html', 'r', encoding='utf-8') as f:
        html = f.read()
    with open('build/web/index.js', 'r', encoding='utf-8') as f:
        js = f.read()

    # Create the data URLs
    wasm_url = f"data:application/wasm;base64,{wasm_b64}"
    pck_url = f"data:application/octet-stream;base64,{pck_b64}"

    # 1. Inline the JS file (Regex is safer than exact string match)
    html = re.sub(r'<script src="index\.js".*?></script>', f'<script>\n{js}\n</script>', html, flags=re.DOTALL)

    # 2. Inject the base64 strings directly into the Godot config JSON
    html = re.sub(r'"wasm"\s*:\s*"index\.wasm"', f'"wasm":"{wasm_url}"', html)
    html = re.sub(r'"mainPack"\s*:\s*"index\.pck"', f'"mainPack":"{pck_url}"', html)

    # Save the file
    with open('build/web/game.html', 'w', encoding='utf-8') as f:
        f.write(html)
    print("Successfully created game.html! Final size:", len(html))

if __name__ == '__main__':
    bundle()
