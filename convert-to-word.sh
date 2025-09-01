#!/bin/bash
# Convert Markdown files to Word documents
# This script does NOT modify the original markdown files

USE_PANDOC=false
INSTALL_DEPENDENCIES=false
FILES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --use-pandoc)
            USE_PANDOC=true
            shift
            ;;
        --install-dependencies)
            INSTALL_DEPENDENCIES=true
            USE_PANDOC=true
            shift
            ;;
        --files)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^-- ]]; do
                FILES+=("$1")
                shift
            done
            ;;
        *.md)
            FILES+=("$1")
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--use-pandoc] [--install-dependencies] [--files file1.md file2.md] [file1.md file2.md]"
            exit 1
            ;;
    esac
done

echo "Converting Markdown files to Word documents..."

# Function to validate markdown files
validate_markdown_files() {
    local valid_files=()
    
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo -e "\033[31m✗ File not found: $file\033[0m"
            continue
        fi
        if [[ ! "$file" =~ \.md$ ]]; then
            echo -e "\033[31m✗ Not a markdown file: $file\033[0m"
            continue
        fi
        if [[ ! -s "$file" ]]; then
            echo -e "\033[31m✗ Empty file: $file\033[0m"
            continue
        fi
        echo -e "\033[32m✓ Valid markdown file: $file\033[0m"
        valid_files+=("$file")
    done
    
    echo "${valid_files[@]}"
}

# Determine files to convert
if [[ ${#FILES[@]} -eq 0 ]]; then
    # Default files if none specified
    FILES=("readme/README.md" "readme/FUTURE.md")
    echo -e "\033[33mNo files specified, using default files\033[0m"
else
    echo -e "\033[36mProcessing specified files: ${FILES[*]}\033[0m"
fi

# Validate markdown files
VALID_FILES=($(validate_markdown_files "${FILES[@]}"))
if [[ ${#VALID_FILES[@]} -eq 0 ]]; then
    echo -e "\033[31mNo valid markdown files found. Exiting.\033[0m"
    exit 1
fi

echo -e "\033[32mFound ${#VALID_FILES[@]} valid markdown file(s)\033[0m"

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "rhel"
        elif command -v dnf >/dev/null 2>&1; then
            echo "fedora"
        elif command -v pacman >/dev/null 2>&1; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Function to install Pandoc based on OS
install_pandoc() {
    local os=$(detect_os)
    echo "Installing Pandoc for $os..."
    
    case $os in
        "ubuntu")
            sudo apt-get update
            sudo apt-get install -y pandoc
            ;;
        "rhel")
            sudo yum install -y epel-release
            sudo yum install -y pandoc
            ;;
        "fedora")
            sudo dnf install -y pandoc
            ;;
        "arch")
            sudo pacman -S --noconfirm pandoc
            ;;
        "macos")
            if command -v brew >/dev/null 2>&1; then
                brew install pandoc
            else
                echo "Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install pandoc
            fi
            ;;
        *)
            echo "Unsupported OS. Please install Pandoc manually."
            exit 1
            ;;
    esac
    
    if command -v pandoc >/dev/null 2>&1; then
        echo "✓ Pandoc installed successfully"
    else
        echo "Failed to install Pandoc"
        exit 1
    fi
}

# Install dependencies if requested
if [ "$INSTALL_DEPENDENCIES" = true ]; then
    if ! command -v pandoc >/dev/null 2>&1; then
        install_pandoc
    else
        echo "✓ Pandoc already installed"
    fi
fi

# Check if pandoc is available
if command -v pandoc &> /dev/null && [ "$USE_PANDOC" = true ]; then
    echo "Using Pandoc for conversion..."
    
    # Convert using Pandoc (best quality)
    for file in "${VALID_FILES[@]}"; do
        basename=$(basename "$file" .md)
        output_file="${basename}.docx"
        pandoc "$file" -o "$output_file" --toc
        echo "✓ Created $output_file"
    done
else
    echo "Creating Word-ready text files..."
    
    # Create Word-ready text files
    for file in "${VALID_FILES[@]}"; do
        basename=$(basename "$file" .md)
        output_file="${basename}-for-Word.txt"
        sed -e 's/^# /HEADING 1: /' \
            -e 's/^## /HEADING 2: /' \
            -e 's/^### /HEADING 3: /' \
            -e 's/```.*$/CODE BLOCK:/' \
            -e 's/\*\*\(.*\)\*\*/BOLD: \1/g' \
            "$file" > "$output_file"
        echo "✓ Created $output_file (copy/paste into Word)"
    done
    
    if ! command -v pandoc >/dev/null 2>&1; then
        echo ""
        echo "Tip: Install Pandoc for better conversion quality:"
        echo "  ./convert-to-word.sh --install-dependencies"
        echo "  Or manually install based on your OS:"
        echo "    Ubuntu/Debian: sudo apt install pandoc"
        echo "    RHEL/CentOS: sudo yum install pandoc"
        echo "    macOS: brew install pandoc"
    fi
fi

echo ""
echo "Conversion complete!"
echo "Original markdown files remain unchanged."