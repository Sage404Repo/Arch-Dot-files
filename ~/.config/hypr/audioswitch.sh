#!/usr/bin/env bash

# Step 1: Get wpctl status and remove ALL box-drawing characters
CLEAN_OUTPUT=$(wpctl status | tr -cd '[:print:]\n' | sed 's/[^a-zA-Z0-9 .*\(\)\[\]_-//g')

# Step 2: Extract ALL sink IDs from the Sinks section
ALL_SINK_LIST=$(echo "$CLEAN_OUTPUT" | \
    awk '/^[ ]*Sinks:/,/^[ ]*Sources:/ { 
        if (/^\*?[ ]*[0-9]+\./) { 
            gsub(/[^0-9]/, "", $1); 
            if ($1 != "") print $1 
        } 
    }')

if [ -z "$ALL_SINK_LIST" ]; then
    # Fallback to pactl if wpctl parsing fails completely
    if command -v pactl &>/dev/null; then
        ALL_SINK_LIST=$(pactl list sinks short 2>/dev/null | awk '{print $1}')
        if [ -z "$ALL_SINK_LIST" ]; then
            notify-send "Audio Error" "No sinks found via any method!"
            exit 1
        fi
        USE_PACTL=true
    else
        notify-send "Audio Error" "No sinks found and no fallback available!"
        exit 1
    fi
fi

mapfile -t ALL_SINKS < <(echo "$ALL_SINK_LIST")

# Step 3: FILTER TO ONLY SINKS 51 AND 52
TARGET_SINKS=(51 52)
SINK_LIST=()

for id in "${TARGET_SINKS[@]}"; do
    # Check if this sink ID exists in our full list
    found=false
    for sink_id in "${ALL_SINKS[@]}"; do
        if [[ "$sink_id" == "$id" ]]; then
            SINK_LIST+=("$id")
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Warning: Sink $id not found on system, skipping..."
    fi
done

# Validate we have at least one target sink
if [ ${#SINK_LIST[@]} -eq 0 ]; then
    notify-send "Audio Error" "None of target sinks (51, 52) found!"
    exit 1
fi

mapfile -t SINKS < <(printf '%s\n' "${SINK_LIST[@]}")

if [ ${#SINKS[@]} -eq 0 ]; then
    notify-send "Audio Error" "Empty filtered sink list detected"
    exit 1
fi

echo "Found ${#SINKS[@]} active target sinks: ${SINKS[*]}"

# Get current default
if [ "${USE_PACTL:-false}" = true ]; then
    CURRENT=$(pactl get-default-sink 2>/dev/null)
else
    # Find the active sink (marked with *)
    CURRENT=$(echo "$CLEAN_OUTPUT" | \
        awk '/^[ ]*Sinks:/,/^[ ]*Sources:/ { 
            if (/^\*/) { 
                gsub(/[^0-9]/, "", $2); 
                if ($2 != "") { print $2; exit } 
            } 
        }')
fi

if [ -z "$CURRENT" ]; then
    CURRENT=${SINKS[0]}
    echo "Warning: Could not detect current sink, using first: $CURRENT"
fi

# Validate that current is actually a number
if ! [[ "$CURRENT" =~ ^[0-9]+$ ]]; then
    CURRENT=${SINKS[0]}
    echo "Warning: Current sink '$CURRENT' is not valid, using first: $CURRENT"
fi

echo "Current sink: $CURRENT"

# Round-robin logic
INDEX=-1
for i in "${!SINKS[@]}"; do
    if [[ "${SINKS[$i]}" == "$CURRENT" ]]; then
        INDEX=$i
        break
    fi
done

if [ $INDEX -eq -1 ]; then
    # If current isn't in our filtered list, switch to first target sink
    NEXT=${SINKS[0]}
    echo "Current ($CURRENT) not in target list. Switching to first: $NEXT"
else
    NEXT_IDX=$(( (INDEX + 1) % ${#SINKS[@]} ))
    NEXT=${SINKS[$NEXT_IDX]}
    echo "Switching from $CURRENT to $NEXT"
fi

# Validate next is a number
if ! [[ "$NEXT" =~ ^[0-9]+$ ]]; then
    notify-send "Audio Error" "Invalid sink ID: $NEXT"
    exit 1
fi

# Execute switch
if [ "${USE_PACTL:-false}" = true ]; then
    pactl set-default-sink "$NEXT"
else
    wpctl set-default "$NEXT"
fi

# Get friendly name for notification
if [ "${USE_PACTL:-false}" = true ]; then
    NAME=$(pactl list sinks short 2>/dev/null | grep "^$NEXT " | cut -f2 | cut -d' ' -f1)
else
    # Try to extract name from cleaned output
    NAME=$(echo "$CLEAN_OUTPUT" | grep -E "\b$NEXT\." | head -1 | sed 's/.*[.:]\s*//' | sed 's/\[.*//g' | xargs)
fi

if [ -z "$NAME" ]; then NAME="Sink $NEXT"; fi

notify-send "Audio Switched" "To: $NAME (ID: $NEXT)"
echo "Done!"