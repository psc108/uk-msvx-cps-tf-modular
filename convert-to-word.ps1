# Convert Markdown files to Word documents
# This script does NOT modify the original markdown files

param(
    [switch]$UsePandoc = $false,
    [switch]$InstallDependencies = $false,
    [string[]]$Files = @()
)

Write-Host "Converting Markdown files to Word documents..." -ForegroundColor Green

# Function to validate markdown files
function Test-MarkdownFiles {
    param([string[]]$FilePaths)
    
    $validFiles = @()
    foreach ($file in $FilePaths) {
        if (-not (Test-Path $file)) {
            Write-Host "✗ File not found: $file" -ForegroundColor Red
            continue
        }
        if (-not $file.EndsWith('.md')) {
            Write-Host "✗ Not a markdown file: $file" -ForegroundColor Red
            continue
        }
        if ((Get-Item $file).Length -eq 0) {
            Write-Host "✗ Empty file: $file" -ForegroundColor Red
            continue
        }
        Write-Host "✓ Valid markdown file: $file" -ForegroundColor Green
        $validFiles += $file
    }
    return $validFiles
}

# Determine files to convert
if ($Files.Count -eq 0) {
    # Default files if none specified
    $Files = @("readme\README.md", "readme\FUTURE.md")
    Write-Host "No files specified, using default files" -ForegroundColor Yellow
} else {
    Write-Host "Processing specified files: $($Files -join ', ')" -ForegroundColor Cyan
}

# Validate markdown files
$validFiles = Test-MarkdownFiles -FilePaths $Files
if ($validFiles.Count -eq 0) {
    Write-Host "No valid markdown files found. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($validFiles.Count) valid markdown file(s)" -ForegroundColor Green

# Function to install Chocolatey if not present
function Install-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "✓ Chocolatey installed" -ForegroundColor Green
    }
}

# Function to install Pandoc
function Install-Pandoc {
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Pandoc..." -ForegroundColor Yellow
        Install-Chocolatey
        choco install pandoc -y
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "✓ Pandoc installed" -ForegroundColor Green
    }
}

# Install dependencies if requested
if ($InstallDependencies) {
    Install-Pandoc
    $UsePandoc = $true
}

# Check if pandoc is available
$pandocAvailable = Get-Command pandoc -ErrorAction SilentlyContinue

if ($UsePandoc -and $pandocAvailable) {
    Write-Host "Using Pandoc for conversion..." -ForegroundColor Yellow
    
    # Convert using Pandoc (best quality)
    foreach ($file in $validFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $outputFile = "$baseName.docx"
        pandoc $file -o $outputFile --toc
        Write-Host "✓ Created $outputFile" -ForegroundColor Green
    }
} else {
    Write-Host "Using PowerShell Word automation..." -ForegroundColor Yellow
    
    try {
        # Create Word application
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        
        # Convert each file
        foreach ($file in $validFiles) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $outputFile = "$baseName.docx"
            $content = Get-Content $file -Raw
            $doc = $word.Documents.Add()
            $doc.Content.Text = $content
            $doc.SaveAs([System.IO.Path]::Combine($PWD, $outputFile))
            $doc.Close()
            Write-Host "✓ Created $outputFile" -ForegroundColor Green
        }
        
        $word.Quit()
    } catch {
        Write-Host "Word automation failed. Creating formatted text files instead..." -ForegroundColor Yellow
        
        # Fallback: Create Word-ready text files
        foreach ($file in $validFiles) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $outputFile = "$baseName-for-Word.txt"
            $content = Get-Content $file | 
                ForEach-Object { 
                    $_ -replace '^# ', 'HEADING 1: ' -replace '^## ', 'HEADING 2: ' -replace '^### ', 'HEADING 3: ' -replace '```.*', 'CODE BLOCK:' -replace '\*\*(.*?)\*\*', 'BOLD: $1'
                }
            $content | Out-File $outputFile -Encoding UTF8
            Write-Host "✓ Created $outputFile (copy/paste into Word)" -ForegroundColor Green
        }
    }
}

Write-Host "`nConversion complete!" -ForegroundColor Green
Write-Host "Original markdown files remain unchanged." -ForegroundColor Cyan

if (-not $pandocAvailable) {
    Write-Host "`nTip: Install Pandoc for better conversion quality:" -ForegroundColor Yellow
    Write-Host "  .\convert-to-word.ps1 -InstallDependencies" -ForegroundColor Gray
    Write-Host "  Or manually: choco install pandoc" -ForegroundColor Gray
}