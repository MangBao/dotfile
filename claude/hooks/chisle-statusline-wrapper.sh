#!/bin/bash
CHISLE_DIR="$HOME/.claude/plugins/cache/chisle/chisle"
LATEST=$(ls "$CHISLE_DIR" | sort -V | tail -1)
exec bash "$CHISLE_DIR/$LATEST/hooks/chisle-statusline.sh"
