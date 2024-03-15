#!/bin/sh

cleanup() {
    echo "Cleaning up processes..."
    # Add any cleanup tasks here
    kill -9 $pid  # Forcefully terminate cloudflared
    exit 0
}

trap cleanup SIGINT SIGTERM

if [ -z "$token" ]; then
    echo "Error: 'token' environment variable is not set."
    exit 1
fi

cloudflared tunnel --no-autoupdate run --token $token &
pid=$!

wait_cloudflared() {
    echo "Waiting for cloudflared process..."
    wait $pid
}

trap wait_cloudflared EXIT

wait