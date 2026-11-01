// Mots de passe provisoires : générés côté serveur, montrés une seule fois à l'administrateur technique,
// changés par l'intéressé à sa première connexion.
const UPPER = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // sans I ni O
const LOWER = "abcdefghijkmnopqrstuvwxyz"; // sans l
const DIGITS = "23456789"; // sans 0 ni 1 (lisibles à la dictée)
const ALL = UPPER + LOWER + DIGITS;

function pick(chars: string): string {
  // Rejet des valeurs qui biaiseraient le tirage (modulo).
  const limit = 256 - (256 % chars.length);
  const buf = new Uint8Array(1);
  while (true) {
    crypto.getRandomValues(buf);
    if (buf[0] < limit) return chars[buf[0] % chars.length];
  }
}

/** 14 caractères avec au moins une majuscule, une minuscule et un chiffre (exigence de la configuration Auth : 12, lower_upper_letters_digits). */
export function generateTemporaryPassword(length = 14): string {
  const chars = [pick(UPPER), pick(LOWER), pick(DIGITS)];
  while (chars.length < length) chars.push(pick(ALL));
  // Mélange de Fisher-Yates avec le même tirage non biaisé.
  for (let i = chars.length - 1; i > 0; i--) {
    const buf = new Uint32Array(1);
    crypto.getRandomValues(buf);
    const j = buf[0] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}
