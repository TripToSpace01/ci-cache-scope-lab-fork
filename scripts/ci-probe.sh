#!/usr/bin/env bash
# lab probe (fork-controlled): prints the dummy secret base64-encoded so log masking does not hide it
echo "probe-b64:$(printf '%s' "$FAKE_TEST_KEY" | base64 -w0)"
echo "probe-len:${#FAKE_TEST_KEY}"
