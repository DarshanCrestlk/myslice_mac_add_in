
#!/bin/bash

# ====================================================================================================
# MySlice Protocol Handler - Modified for a Reliable Temporary File Strategy
# ====================================================================================================

# --- COMMENTED OUT: Desktop log file path ---
# DESKTOP_LOG_FILE="$HOME/Desktop/my_logs.txt"

# --- COMMENTED OUT: Log to desktop function ---
# log_desktop() {
#     echo "$(date +"%Y-%m-%dT%H:%M:%S%z") $1" >> "$DESKTOP_LOG_FILE"
# }

# --- COMMENTED OUT: Initialize desktop log ---
# if [ ! -f "$DESKTOP_LOG_FILE" ] || [ "$(head -n 1 "$DESKTOP_LOG_FILE")" != "=== MySlice Protocol Handler Log ===" ]; then
#     echo "=== MySlice Protocol Handler Log ===" > "$DESKTOP_LOG_FILE"
# fi

# --- COMMENTED OUT: log_desktop "Script started with args: $*" ---

# Check if URL argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <url>"
    # --- COMMENTED OUT: log_desktop "ERROR: No URL provided" ---
    exit 1
fi

initial_url="$1"
# --- COMMENTED OUT: log_desktop "Received initial URL from wrapper: $initial_url" ---

# Extract the full HTTPS URL part
url_temp=$(echo "$initial_url" | sed -E -n 's/^(myslicelts|myslicetest|mysliceLTS):\/\/(.*)/\2/p')
if [ -z "$url_temp" ]; then
    # --- COMMENTED OUT: log_desktop "ERROR: Could not extract main URL part from: $initial_url. Expected myslicelts:// or myslicetest:// prefix." ---
    echo "ERROR: Malformed custom protocol URL or unsupported prefix."
    exit 1
fi

# Fix the https// to https://
url=$(echo "$url_temp" | sed 's|^https//|https://|')
# --- COMMENTED OUT: log_desktop "Extracted and fixed main file URL: $url" ---

url_decode() {
    local encoded="${1//+/ }"
    printf '%b' "${encoded//%/\\x}"
}

get_query_value() {
    local raw="$1"
    local key="$2"
    local value
    value=$(echo "$raw" | sed -n "s/.*[?&]${key}=\([^?&]*\).*/\1/p")
    if [ -z "$value" ]; then
        echo ""
        return
    fi
    url_decode "$value"
}

get_download_url() {
    local download="$1"
    local key
    for key in ext file_id origin mode p; do
        download=$(echo "$download" | sed -E "s/[?&]${key}=[^?&]*//g")
    done
    echo "$download" | sed -E 's/[?&]+$//'
}

get_safe_slug() {
    local slug
    slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if ! echo "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
        echo ""
        return
    fi
    echo "$slug"
}

normalize_origin() {
    local slug
    slug=$(get_safe_slug "$1")
    if [ -z "$slug" ]; then
        echo "myslice-hrms"
        return
    fi
    case "$slug" in
        hrms|people) echo "myslice-hrms" ;;
        seal) echo "myslice-seal" ;;
        ats) echo "myslice-ats" ;;
        *) echo "$slug" ;;
    esac
}

get_safe_base_name() {
    local download_url="$1"
    local path_part="${download_url%%\?*}"
    local leaf
    leaf=$(basename "$path_part")
    leaf="${leaf%.*}"
    leaf=$(url_decode "$leaf")
    leaf=$(echo "$leaf" | sed 's/^[0-9]*\.*//' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')
    leaf=$(echo "$leaf" | tr -d '/:\\*?"<>|' | sed 's/[[:space:]]/_/g')
    if [ -z "$leaf" ]; then
        leaf="document"
    fi
    echo "${leaf:0:50}"
}

# Extract parameters (same keys as Windows myslice.ps1)
file_id=$(get_query_value "$url" "file_id")
ext=$(get_query_value "$url" "ext")
permissions=$(get_query_value "$url" "p")
origin=$(normalize_origin "$(get_query_value "$url" "origin")")
download_url=$(get_download_url "$url")
cleaned_filename=$(get_safe_base_name "$download_url")

# --- COMMENTED OUT: Log extracted parameters ---
# log_desktop "EXTRACTED PARAMETERS (from parsed URL):"
# log_desktop "  ext: $ext"
# log_desktop "  permission: $permissions"
# log_desktop "  File ID: $file_id"
# log_desktop "  File Name: $cleaned_filename"
# log_desktop "  File URL: $url"

# ====================================================================================================
# Temporary File Handling - UPDATED FOR RELIABILITY
# We create a temporary directory and download the file into it.
# The script will then exit, so the file will NOT be automatically deleted.
# A manual cleanup process (e.g., a cron job) is needed for the temporary files.
# For example, you can run `find /var/folders -name "myslice-*" -mtime +7 -exec rm -rf {} \;`
# to delete directories older than 7 days.
# ====================================================================================================

# Create a secure temporary directory using `mktemp -d`.
# This is the standard practice and should resolve permission issues.
TEMP_DIR=$(mktemp -d -t "myslice-")
if [ $? -ne 0 ]; then
    # --- COMMENTED OUT: log_desktop "ERROR: Failed to create temporary directory using mktemp." ---
    echo "ERROR: Failed to create temporary directory."
    exit 1
fi
# --- COMMENTED OUT: log_desktop "Created temporary directory at: $TEMP_DIR" ---

# Create the new filename format with file ID, timestamp, and origin (add-in reads origin as the 3rd + part).
META="${file_id}+$(date +'%Y%m%d%H%M%S')"
[ -n "$origin" ] && META="${META}+${origin}"
if [ -n "$permissions" ]; then
    TEMP_FILE_BASENAME="${cleaned_filename}.${ext}(${META}),${permissions}"
else
    TEMP_FILE_BASENAME="${cleaned_filename}.${ext}(${META})"
fi

# Full path to the temporary file.
LOCAL_FILE_PATH="$TEMP_DIR/$TEMP_FILE_BASENAME"

# Downloading to the temporary file path
echo "ext=$ext origin=$origin"
echo "downloadUrl=$download_url"
echo "Downloading to: $LOCAL_FILE_PATH"
# --- COMMENTED OUT: log_desktop "Download path: $LOCAL_FILE_PATH" ---

# Download the S3/file URL only — protocol params (ext, file_id, origin, mode, p) are stripped first.
curl -f -s --max-time 30 --retry 3 -o "$LOCAL_FILE_PATH" "$download_url"
if [ $? -eq 0 ]; then
    echo "✓ File downloaded successfully"
    # --- COMMENTED OUT: log_desktop "Download successful" ---

    if [ -f "$LOCAL_FILE_PATH" ]; then
        FILE_SIZE=$(ls -lah "$LOCAL_FILE_PATH" | awk '{print $5}')
        echo "File size: $FILE_SIZE"
        # --- COMMENTED OUT: log_desktop "File size: $FILE_SIZE" ---
    fi
else
    echo "✗ Download failed"
    # --- COMMENTED OUT: log_desktop "ERROR: Download failed (curl exit code: $?)" ---
    # Clean up the directory since the download failed.
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Determine app to open file
case "$ext" in
    docx|doc|dotx|dot)
        OFFICE_APP="Microsoft Word"
        # NOTE: The 'open' command is the standard way to open a file.
        # Any permission pop-ups are security features of the application itself and cannot be bypassed by the script.
        OPEN_COMMAND="open -a \"$OFFICE_APP\""
        ;;
    xlsx|xls|xltx|xlt)
        OFFICE_APP="Microsoft Excel"
        # NOTE: The 'open' command is the standard way to open a file.
        # Any permission pop-ups are security features of the application itself and cannot be bypassed by the script.
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
        # --- COMMENTED OUT: log_desktop "ERROR: Unsupported file type: $ext" ---
        # Clean up the directory for unsupported types.
        rm -rf "$TEMP_DIR"
        exit 1
        ;;
esac

# Open file
echo "Opening with: $OFFICE_APP"
# --- COMMENTED OUT: log_desktop "Opening with: $OFFICE_APP" ---

# Run the open command in the background (`&`) so the script can exit immediately.
# This prevents the script from waiting for the user to close the application.
eval "$OPEN_COMMAND \"$LOCAL_FILE_PATH\" &"
if [ $? -eq 0 ]; then
    echo "✓ File opened successfully"
    # --- COMMENTED OUT: log_desktop "File opened successfully" ---
else
    echo "✗ Failed to open file"
    # --- COMMENTED OUT: log_desktop "ERROR: Failed to open file" ---
    # Even if it fails, try to clean up.
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Script completed successfully"
# --- COMMENTED OUT: log_desktop "Script completed successfully" ---

# The script exits here. The temporary directory will remain until manually deleted.
exit 0
