#!/usr/bin/env bash
# Recharge la base locale avec les migrations et le jeu de démonstration (supabase/seed.sql).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$ROOT_DIR"
supabase db reset
echo
echo "Comptes de démonstration (mot de passe : Akonta-Demo-2026!) :"
echo "  associe@akonta.demo (associé, TOTP à enrôler à la première connexion)"
echo "  chef@akonta.demo (chef de mission)   assistant@akonta.demo   stagiaire@akonta.demo   admin@akonta.demo"
