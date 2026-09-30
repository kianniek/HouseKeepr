import os

# Configuration: Directories and files to ignore relative to project root
EXCLUDE_DIRS = {
    '.git', '.dart_tool', '.idea', 'build', 
    'ios', 'android', 'windows', 'macos', 'linux', 'web',
    'test', 'assets', 'images'
}
EXCLUDE_FILES = {'pubspec.lock', 'project_context.txt', 'export_project.py'}
ALLOWED_EXTENSIONS = {'.dart', '.yaml', '.json', '.md'}

def should_skip_dir(dirname):
    return dirname in EXCLUDE_DIRS or dirname.startswith('.')

def should_skip_file(filename):
    if filename in EXCLUDE_FILES:
        return True
    return not any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS)

def generate_project_context():
    # Get the script's directory and move one level up to the project root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    output_file = os.path.join(project_root, 'project_context.txt')
    
    with open(output_file, 'w', encoding='utf-8') as outfile:
        outfile.write("=== PROJECT CONTEXT EXPORT (lib/ focused) ===\n\n")
        
        for root, dirs, files in os.walk(project_root):
            # Modify dirs in-place to prevent os.walk from entering excluded directories
            dirs[:] = [d for d in dirs if not should_skip_dir(d)]
            
            for file in files:
                if should_skip_file(file):
                    continue
                
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, project_root)
                
                # Prioritize /lib files and pubspec.yaml at the root
                if not relative_path.startswith('lib') and relative_path != 'pubspec.yaml':
                    continue
                
                print(f"Exporting: {relative_path}")
                
                outfile.write(f"\n--- FILE: {relative_path} ---\n")
                try:
                    with open(file_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())
                except Exception as e:
                    outfile.write(f"[Error reading file: {e}]")
                outfile.write("\n\n")
                
    print(f"\nSuccess! Project context saved to {output_file}")

if __name__ == '__main__':
    generate_project_context()