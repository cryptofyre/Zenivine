# Enable dry run mode by setting this to $true
$dryRun = $false

# Define a logging function
function Log-Message {
    param (
        [string]$message,
        [switch]$important
    )
    
    if ($important) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $message" -ForegroundColor Yellow
    } else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $message"
    }
}

# Define a function to gracefully stop the zen.exe process
function Stop-ZenProcess {
    $process = Get-Process -Name "zen" -ErrorAction SilentlyContinue
    if ($process) {
        Log-Message "zen.exe is running. Attempting to stop it gracefully."
        if ($dryRun) {
            Log-Message "Dry run enabled. Skipping stopping zen.exe."
        } else {
            Stop-Process -Name "zen" -Force -Confirm:$false
            Start-Sleep -Seconds 5  # Wait a few seconds to ensure the process has stopped
        }
    } else {
        Log-Message "zen.exe is not running."
    }
}

# Start script
Log-Message "Starting Widevine CDM installation script."

# Stop zen.exe if running
Stop-ZenProcess

# Define the URL for the JSON file
$jsonUrl = "https://raw.githubusercontent.com/mozilla/gecko-dev/master/toolkit/content/gmp-sources/widevinecdm.json"

# Download and parse the JSON file
Log-Message "Downloading and parsing JSON file from $jsonUrl."
$jsonData = Invoke-RestMethod -Uri $jsonUrl

# Determine the operating system and architecture
$os = $null
$arch = $null
$regularArch = if ([System.Environment]::Is64BitProcess) { "x64" } else { "x86" }

if ($IsWindows) {
    $os = "WINNT"
    $arch = if ([System.Environment]::Is64BitProcess) { "x86_64-msvc" } else { "x86-msvc" }
} elseif ($IsMacOS) {
    $os = "Darwin"
    $arch = if ([System.Environment]::Is64BitProcess) { "x86_64-gcc3" } else { "aarch64-gcc3" }
} elseif ($IsLinux) {
    $os = "Linux"
    $arch = "x86_64-gcc3"
} else {
    Log-Message "Unsupported operating system. Exiting script." -important
    exit 1
}

Log-Message "Detected OS: $os, Architecture: $arch."

# Get the platform details from the JSON data
$platformKey = "$os" + "_$arch"
$platformData = $jsonData.vendors."gmp-widevinecdm".platforms.$platformKey

# Resolve alias if exists
if ($platformData.alias) {
    Log-Message "Alias detected for $platformKey. Resolving to $($platformData.alias)."
    $platformData = $jsonData.vendors."gmp-widevinecdm".platforms.$($platformData.alias)
}

# Log file details
$zipUrl = $platformData.fileUrl
$version = $jsonData.vendors."gmp-widevinecdm".version
Log-Message "Will download ZIP file from: $zipUrl"
Log-Message "Widevine version: $version"

# Download the ZIP file
$zipFile = "$env:TEMP\widevine.zip"
if ($dryRun) {
    Log-Message "Dry run enabled. Skipping download of $zipUrl."
} else {
    Log-Message "Downloading ZIP file to $zipFile."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
}

# Define the base directory path where profiles might be stored
$baseDir = "$env:APPDATA\zen\Profiles"
Log-Message "Searching for profiles in $baseDir."

# Recursively search for all user profile folders at the root level
$profileDirs = Get-ChildItem -Path $baseDir -Directory

foreach ($profileDir in $profileDirs) {
    # Define the target directory path for each profile
    $targetDir = Join-Path -Path $profileDir.FullName -ChildPath "gmp-widevinecdm\$version"
    
    # Clean out the gmp-widevinecdm folder if it exists
    if (Test-Path -Path $targetDir) {
        Log-Message "Cleaning out existing files in $targetDir"
        if ($dryRun) {
            Log-Message "Dry run enabled. Skipping cleaning of $targetDir."
        } else {
            Remove-Item -Path $targetDir\* -Recurse -Force
        }
    }

    # Log directory creation
    Log-Message "Preparing to create directory: $targetDir"
    if ($dryRun) {
        Log-Message "Dry run enabled. Skipping directory creation."
    } else {
        if (-not (Test-Path -Path $targetDir)) {
            Log-Message "Creating directory: $targetDir"
            New-Item -Path $targetDir -ItemType Directory -Force
        } else {
            Log-Message "Directory already exists: $targetDir"
        }
    }

    # Log ZIP extraction
    Log-Message "Preparing to extract ZIP to: $targetDir"
    if ($dryRun) {
        Log-Message "Dry run enabled. Skipping ZIP extraction."
    } else {
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
    }

    # Create or modify the user.js file in the root of the profile directory
    $userJsFile = Join-Path -Path $profileDir.FullName -ChildPath "user.js"
    Log-Message "Preparing to update user.js at: $userJsFile"
    if ($dryRun) {
        Log-Message "Dry run enabled. Skipping user.js modification."
    } else {
        # Prepare the new preferences
        $widevinePrefs = @(
            "user_pref('media.gmp-widevinecdm.abi', '$arch');",
            "user_pref('media.gmp-widevinecdm.version', '$version-$regularArch');"
            "user_pref('media.gmp-widevinecdm.visible', true);"
            "user_pref('media.gmp-widevinecdm.enabled', true);"
            "user_pref('media.gmp-manager.url', 'https://aus5.mozilla.org/update/3/GMP/%VERSION%/%BUILD_ID%/%BUILD_TARGET%/%LOCALE%/%CHANNEL%/%OS_VERSION%/%DISTRIBUTION%/%DISTRIBUTION_VERSION%/update.xml');"
            "user_pref('media.gmp-provider.enabled', true);"
        )

        # Read existing user.js content if it exists
        $existingContent = @()
        if (Test-Path -Path $userJsFile) {
            $existingContent = Get-Content -Path $userJsFile
        }

        # Check if the preferences already exist
        $newPrefs = @()
        foreach ($pref in $widevinePrefs) {
            if (-not ($existingContent -contains $pref)) {
                $newPrefs += $pref
            }
        }

        # Add the new preferences if they are not already present
        if ($newPrefs.Count -gt 0) {
            Log-Message "Adding new preferences to user.js"
            Add-Content -Path $userJsFile -Value $newPrefs
        } else {
            Log-Message "Preferences already exist in user.js, no need to add."
        }
    }
}

# Clean up the ZIP file
if ($dryRun) {
    Log-Message "Dry run enabled. Skipping ZIP file cleanup."
} else {
    Log-Message "Cleaning up ZIP file: $zipFile"
    Remove-Item -Path $zipFile
}

Log-Message "Widevine CDM installation script completed."
