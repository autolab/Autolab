function strToBase64(str) {
    return bytesToBase64(new TextEncoder().encode(str));
}

// https://developer.mozilla.org/en-US/docs/Glossary/Base64#the_unicode_problem
function bytesToBase64(bytes) {
  const binString = String.fromCodePoint(...bytes);
  return btoa(binString);
}
