#!/usr/bin/env bash
# Démarre la pile Supabase locale (PostgreSQL, Auth, Storage, Edge Functions, Studio) sous Podman.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
ensure_podman_socket
cd "$ROOT_DIR"
supabase start
supabase status
