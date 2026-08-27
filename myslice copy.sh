#!/bin/bash

# ====================================================================================================
# MySlice Protocol Handler - Modified to download to macOS Downloads folder
# ====================================================================================================

# Desktop log file path
DESKTOP_LOG_FILE="$HOME/Desktop/my_logs.txt"

# Directories
# Changed DOWNLOAD_DIR to the standard macOS Downloads folder
DOWNLOAD_DIR="$HOME/Downloads"

# Create directories if they don't exist (though Downloads usually exists)
mkdir -p "$DOWNLOAD_DIR"

# Log to desktop function
log_desktop() {
    echo "$(date +"%Y-%m-%dT%H:%M:%S%z") $1" >> "$DESKTOP_LOG_FILE"
}

# Initialize desktop log
if [ ! -f "$DESKTOP_LOG_FILE" ] || [ "$(head -n 1 "$DESKTOP_LOG_FILE")" != "=== MySlice Protocol Handler Log ===" ]; then
    echo "=== MySlice Protocol Handler Log ===" > "$DESKTOP_LOG_FILE"
fi

log_desktop "Script started with args: $*"

# Check if URL argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <url>"
    log_desktop "ERROR: No URL provided"
    exit 1
fi

initial_url="$1"
log_desktop "Received initial URL from wrapper: $initial_url"

# Extract the full HTTPS URL part
url_temp=$(echo "$initial_url" | sed -E -n 's/^(myslicelts|myslicetest|mysliceLTS):\/\/(.*)/\2/p')
if [ -z "$url_temp" ]; then
    log_desktop "ERROR: Could not extract main URL part from: $initial_url. Expected myslicelts:// or myslicetest:// prefix."
    echo "ERROR: Malformed custom protocol URL or unsupported prefix."
    exit 1
fi

# Fix the https// to https://
url=$(echo "$url_temp" | sed 's|^https//|https://|')
log_desktop "Extracted and fixed main file URL: $url"

# Extract parameters
file_id=$(echo "$url" | sed -n 's/.*file_id=\([^?]*\).*/\1/p')
ext=$(echo "$url" | sed -n 's/.*ext=\([^?]*\).*/\1/p')
permissions=$(echo "$url" | sed -n 's/.*p=\([^?]*\).*/\1/p')

# Extract and clean original filename
original_filename=$(basename "$url")
cleaned_filename=$(echo "$original_filename" | sed 's/^[0-9]*\.*//' | sed 's/\..*$//')
cleaned_filename=$(echo "$cleaned_filename" | sed 's/%20/ /g' | sed 's/%2B/+/g' | xargs)

# Log extracted parameters
log_desktop "EXTRACTED PARAMETERS (from parsed URL):"
log_desktop "  ext: $ext"
log_desktop "  permission: $permissions"
log_desktop "  File ID: $file_id"
log_desktop "  File Name: $cleaned_filename"
log_desktop "  File URL: $url"

# ====================================================================================================
# Permanent File Storage - Now in standard Downloads folder
# Files will be stored in the user's Downloads directory and will not be automatically deleted.
# ====================================================================================================

# Create the new filename format with file ID and timestamp.
# This ensures unique names for downloaded files.
LOCAL_FILE_NAME="${cleaned_filename}.${ext}(${file_id}+$(date +'%Y%m%d%H%M%S'))"

# Full path to the permanent file.
LOCAL_FILE_PATH="$DOWNLOAD_DIR/$LOCAL_FILE_NAME"

# Downloading to the permanent file path
echo "Downloading to: $LOCAL_FILE_PATH"
log_desktop "Download path: $LOCAL_FILE_PATH"

# Download file
curl -f -s --max-time 30 --retry 3 -o "$LOCAL_FILE_PATH" "$url"
if [ $? -eq 0 ]; then
    echo "✓ File downloaded successfully"
    log_desktop "Download successful"

    if [ -f "$LOCAL_FILE_PATH" ]; then
        FILE_SIZE=$(ls -lah "$LOCAL_FILE_PATH" | awk '{print $5}')
        echo "File size: $FILE_SIZE"
        log_desktop "File size: $FILE_SIZE"
    fi
else
    echo "✗ Download failed"
    log_desktop "ERROR: Download failed (curl exit code: $?)"
    # If download fails, remove the incomplete file
    rm -f "$LOCAL_FILE_PATH"
    exit 1
fi

# Determine app to open file
case "$ext" in
    docx|doc|dotx|dot)
        OFFICE_APP="Microsoft Word"
        OPEN_COMMAND="open -a \"$OFFICE_APP\""
        ;;
    xlsx|xls|xltx|xlt)
        OFFICE_APP="Microsoft Excel"
        OPEN_COMMAND="open -a \"$OFFICE_APP\""
        ;;
    pptx|ppt|potx|pot)
        OFFICE_APP="Microsoft PowerPoint"
        OPEN_COMMAND="open -a \"$OFFICE_APP\""
        ;;
    txt)
        if command -v code >/dev/null 2>&1; then
            OFFICE_APP="Visual Studio Code"
            OPEN_COMMAND="code"
        elif [ -d "/Applications/Xcode.app" ]; then
            OFFICE_APP="Xcode"
            OPEN_COMMAND="open -a Xcode"
        else
            OFFICE_APP="TextEdit"
            OPEN_COMMAND="open -a TextEdit"
        fi
        ;;
    *)
        echo "Unsupported file type: $ext"
        log_desktop "ERROR: Unsupported file type: $ext"
        exit 1
        ;;
esac

# Open file
echo "Opening with: $OFFICE_APP"
log_desktop "Opening with: $OFFICE_APP"

# Run the open command in the background (`&`) so the script can exit immediately.
# The file will remain in the DOWNLOAD_DIR.
eval "$OPEN_COMMAND \"$LOCAL_FILE_PATH\" &"
if [ $? -eq 0 ]; then
    echo "✓ File opened successfully"
    log_desktop "File opened successfully"
else
    echo "✗ Failed to open file"
    log_desktop "ERROR: Failed to open file"
    exit 1
fi

echo "Script completed successfully"
log_desktop "Script completed successfully"

# The script exits here. The downloaded file remains in the DOWNLOAD_DIR.
exit 0

