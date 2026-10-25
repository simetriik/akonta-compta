#!/usr/bin/env bash
# Recrée la base locale depuis les migrations puis rejoue le seed (données de démonstration).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$ROOT_DIR"
supabase db reset
