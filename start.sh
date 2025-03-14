#!/bin/bash

# Start ttyd with a shell command in the background
echo "Starting ttyd..."
ttyd -p 7681 bash &
TTYD_PID=$!

# Wait a moment for ttyd to initialize
sleep 3

# Check if ttyd is running
if ! ps -p $TTYD_PID > /dev/null; then
  echo "ttyd failed to start with 'bash'. Trying with full path '/bin/bash'..."
  ttyd -p 7681 /bin/bash &
  TTYD_PID=$!
  sleep 3
  
  if ! ps -p $TTYD_PID > /dev/null; then
    echo "Failed to start ttyd with '/bin/bash'. Trying with 'sh'..."
    ttyd -p 7681 sh &
    TTYD_PID=$!
    sleep 3
    
    if ! ps -p $TTYD_PID > /dev/null; then
      echo "All attempts to start ttyd failed. Exiting."
      exit 1
    fi
  fi
fi

echo "ttyd started successfully with PID: $TTYD_PID"

# Test ttyd connection
echo "Testing ttyd connection..."
if curl -s http://localhost:7681 | grep -q "ttyd"; then
  echo "ttyd is responding correctly"
else
  echo "Warning: ttyd might not be responding correctly"
fi

# Start Node.js proxy server in the foreground
echo "Starting Node.js proxy server..."
cd /app && node server.js
