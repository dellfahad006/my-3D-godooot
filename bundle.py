import base64
import re
import os

def bundle():
    # 1. Base64 encode the files
    with open('build/web/index.wasm', 'rb') as f:
        wasm_b64 = base64.b64encode(f.read()).decode('utf-8')
        
    with open('build/web/index.pck', 'rb') as f:
        pck_b64 = base64.b64encode(f.read()).decode('utf-8')

    # 2. Read the HTML file
    with open('build/web/index.html', 'r', encoding='utf-8') as f:
        html = f.read()

    # 3. Read the JS file to inline it
    with open('build/web/index.js', 'r', encoding='utf-8') as f:
        js = f.read()

    # 4. Inline the JS
    html = html.replace('<script src="index.js"></script>', f'<script>\n{js}\n</script>')

    # 5. Replace the Engine initialization with our Base64 data URLs
    wasm_url = f"data:application/wasm;base64,{wasm_b64}"
    pck_url = f"data:application/octet-stream;base64,{pck_b64}"
    
    engine_init = f"""
    var engine = new Engine({{
        "wasm": "{wasm_url}",
        "pck": "{pck_url}"
    }});
    engine.startGame();
    """
    
    # Find the script block that starts the engine and replace it
    html = re.sub(r'var engine = new Engine\(.*?\);\s*engine\.startGame\(\);', engine_init, html, flags=re.DOTALL)

    # 6. Save the single file
    with open('build/web/game.html', 'w', encoding='utf-8') as f:
        f.write(html)
        
    print("Successfully created game.html!")

if __name__ == '__main__':
    bundle()
