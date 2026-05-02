import os
import re

chapters_dir = 'chapters'

# DOI keys to remove
keys_to_remove = [
    "10_1057_s42214_020_00062_w",
    "10_1057_s42214_020_00071_9",
    "10_1057_s41599_023_02234_4",
    "10_1016_j_techfore_2020_119937"
]

# Replacement map
replacements = {
    "10_1016_j_respol_2023_104863": "andreoni2023"
}

citation_pattern = re.compile(r'\\cite[p]?\{([^}]+)\}')

def fix_citations(text):
    def replacer(match):
        command = match.group(0).split('{')[0]
        keys = match.group(1).split(',')
        valid_keys = []
        for key in keys:
            key = key.strip()
            if key in keys_to_remove:
                continue
            if key in replacements:
                key = replacements[key]
            valid_keys.append(key)
        
        if not valid_keys:
            return ''
        else:
            return f"{command}{{{', '.join(valid_keys)}}}"
            
    new_text = citation_pattern.sub(replacer, text)
    # clean up any leftover spaces if citation was removed
    new_text = re.sub(r'\s+~?\s*(?=[.,;])', '', new_text) # remove space before punctuation
    new_text = re.sub(r' \s+', ' ', new_text) # remove double spaces
    return new_text

for filename in os.listdir(chapters_dir):
    if filename.endswith('.tex'):
        filepath = os.path.join(chapters_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        cleaned_content = fix_citations(content)
        
        if cleaned_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            print(f"Fixed {filename}")
