#!/usr/bin/env bash
# Arrête la pile Supabase locale en conservant les données (volumes).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$ROOT_DIR"
supabase stop
