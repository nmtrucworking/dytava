#!/usr/bin/env python3
import os
import glob
import re

def process_illustrations():
    illustration_files = glob.glob('branding/DYTAVA_Illustration_Library_v1/mobile/assets/dytava/illustrations/svg/**/*.svg', recursive=True)
    print(f"Processing {len(illustration_files)} illustrations...")
    
    # Replacement mapping for illustrations
    replacements = [
        # Gradients
        (r'stop-color="#06B6D4"', 'stop-color="#C8FF4A"'),
        (r'stop-color="#3B82F6"', 'stop-color="#86E63A"'),
        (r'stop-color="#2563EB"', 'stop-color="#86E63A"'),
        (r'stop-color="#A78BFA"', 'stop-color="#BAE6FD"'),
        (r'stop-color="#7C3AED"', 'stop-color="#38BDF8"'),
        (r'stop-color="#8CEBFF"', 'stop-color="#E2FF85"'),
        (r'stop-color="#22C3EC"', 'stop-color="#C8FF4A"'),
        (r'stop-color="#EEF5FF"', 'stop-color="#EDEBE4"'),
        (r'stop-color="#F3F6FD"', 'stop-color="#EDEBE4"'),
        
        # Colors: Blue -> Lime / Green accent
        (r'#2563EB\b', '#86E63A'),
        (r'#3B82F6\b', '#86E63A'),
        (r'#1850EB\b', '#86E63A'),
        (r'#153EC5\b', '#76D028'),
        (r'#428DFF\b', '#C8FF4A'),
        (r'#5CA6FF\b', '#C8FF4A'),
        
        # Colors: Purple -> Source B Blue / Accent
        (r'#8B5CF6\b', '#38BDF8'),
        (r'#A18AFF\b', '#7DD3FC'),
        (r'#6E46ED\b', '#0284C7'),
        (r'#A78BFA\b', '#BAE6FD'),
        (r'#7C3AED\b', '#0284C7'),
        
        # Colors: Cyan -> Source A Lime Primary
        (r'#06B6D4\b', '#C8FF4A'),
        (r'#34DBF2\b', '#E2FF85'),
        (r'#029BDB\b', '#86E63A'),
        (r'#8CEBFF\b', '#E2FF85'),
        (r'#22C3EC\b', '#C8FF4A'),
        
        # Shadow / Navy -> Graphite
        (r'#142253\b', '#0F1A1C'),
        (r'#0F172A\b', '#0F1A1C'),
        
        # Grid lines / dividers -> Subtle border
        (r'#D9E4F4\b', '#D8D5CC'),
        (r'#CAD8EF\b', '#D8D5CC'),
        (r'#D3DFF0\b', '#D8D5CC'),
        (r'#CCD9EE\b', '#D8D5CC'),
        (r'#DCE9F8\b', '#D8D5CC'),
        
        # Soft blue backgrounds -> Warm surface
        (r'#EEF5FF\b', '#EDEBE4'),
        (r'#E7F0FF\b', '#EDEBE4'),
        (r'#F5F8FF\b', '#F7F6F2'),
        (r'#D9E4F6\b', '#EDEBE4'),
        (r'#EAF2FF\b', '#EDEBE4'),
        
        # Muted text
        (r'#5E7095\b', '#5F6B6D'),
        (r'#64748B\b', '#5F6B6D'),
    ]
    
    modified_count = 0
    for path in illustration_files:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        orig = content
        for pattern, repl in replacements:
            content = re.sub(pattern, repl, content, flags=re.IGNORECASE)
        
        if content != orig:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            modified_count += 1
            
    print(f"Updated {modified_count} illustration files.")

def process_color_icons():
    icon_files = glob.glob('branding/mobile/assets/dytava/icons/svg/color/*.svg')
    print(f"Processing {len(icon_files)} color icons...")
    
    modified_count = 0
    for path in icon_files:
        filename = os.path.basename(path)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        orig = content
        
        # Update tile backgrounds & strokes
        content = re.sub(r'stroke="#D6DFEE"', 'stroke="#D8D5CC"', content, flags=re.IGNORECASE)
        content = re.sub(r'fill="#EAF2FF"', 'fill="#EDEBE4"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#F3F6FD"', 'stop-color="#EDEBE4"', content, flags=re.IGNORECASE)
        
        # The top-right accent dot: make it Lime Primary (#C8FF4A)
        content = re.sub(r'<circle cx="397" cy="119" r="32" fill="[^"]+"', '<circle cx="397" cy="119" r="32" fill="#C8FF4A"', content)
        
        # Semantics check for icon color
        if filename in ['exact.svg', 'success.svg', 'success-compare.svg', 'success-export.svg', 'success-import.svg']:
            target_color = '#10B981' # Exact Green
        elif filename in ['equivalent.svg']:
            target_color = '#86E63A' # Equivalent Lime-600
        elif filename in ['different.svg', 'error.svg', 'delete.svg', 'removed.svg']:
            target_color = '#E97965' # Difference Coral
        elif filename in ['unresolved.svg', 'warning.svg', 'pending.svg']:
            target_color = '#F59E0B' # Unresolved Amber
        else:
            target_color = '#0F1A1C' # Graphite for clean, technical precision icons
            
        content = re.sub(r'color="#2563EB"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        content = re.sub(r'color="#8B5CF6"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        content = re.sub(r'color="#06B6D4"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        
        # Update gradient defs if any
        content = re.sub(r'stop-color="#3B82F6"', 'stop-color="#C8FF4A"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#1850EB"', 'stop-color="#86E63A"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#34DBF2"', 'stop-color="#C8FF4A"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#029BDB"', 'stop-color="#86E63A"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#A18AFF"', 'stop-color="#38BDF8"', content, flags=re.IGNORECASE)
        content = re.sub(r'stop-color="#6E46ED"', 'stop-color="#0284C7"', content, flags=re.IGNORECASE)
        
        if content != orig:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            modified_count += 1
            
    print(f"Updated {modified_count} color icons.")

def process_outline_and_glyph_icons():
    outline_files = glob.glob('branding/mobile/assets/dytava/icons/svg/outline/*.svg')
    glyph_files = glob.glob('branding/mobile/assets/dytava/icons/svg/glyph/*.svg')
    
    all_files = outline_files + glyph_files
    print(f"Processing {len(all_files)} outline & glyph icons...")
    
    modified_count = 0
    for path in all_files:
        filename = os.path.basename(path)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        orig = content
        
        if filename in ['exact.svg', 'success.svg']:
            target_color = '#10B981'
        elif filename in ['equivalent.svg']:
            target_color = '#86E63A'
        elif filename in ['different.svg', 'error.svg', 'delete.svg', 'removed.svg']:
            target_color = '#E97965'
        elif filename in ['unresolved.svg', 'warning.svg', 'pending.svg']:
            target_color = '#F59E0B'
        else:
            target_color = '#0F1A1C'
            
        content = re.sub(r'color="#2563EB"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        content = re.sub(r'color="#8B5CF6"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        content = re.sub(r'color="#06B6D4"', f'color="{target_color}"', content, flags=re.IGNORECASE)
        
        if content != orig:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            modified_count += 1
            
    print(f"Updated {modified_count} outline & glyph icons.")

def process_format_icons():
    format_files = glob.glob('branding/mobile/assets/dytava/formats/svg/*.svg')
    modified_count = 0
    for path in format_files:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        orig = content
        content = re.sub(r'#2563EB', '#86E63A', content, flags=re.IGNORECASE)
        if content != orig:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            modified_count += 1
    print(f"Updated {modified_count} format icons.")

if __name__ == '__main__':
    process_illustrations()
    process_color_icons()
    process_outline_and_glyph_icons()
    process_format_icons()
    print("Done updating all SVGs!")
