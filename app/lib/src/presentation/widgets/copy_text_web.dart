import 'dart:js_interop';

@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(JSString tag);
  external _Element? get body;
  external _Element? get activeElement;
  external JSBoolean execCommand(JSString command);
}

extension type _Element._(JSObject _) implements JSObject {
  external set value(JSString value);
  external void setAttribute(JSString name, JSString value);
  external void append(_Element child);
  external void remove();
  external void focus();
  external void select();
}

/// Copie de secours par une zone de texte cachée et `execCommand('copy')`, qui fonctionne aussi hors contexte sécurisé.
/// À appeler pendant le geste de l'utilisateur (clic), avant tout `await`. Renvoie `false` si le navigateur refuse.
bool legacyCopy(String text) {
  final body = _document.body;
  if (body == null) return false;
  final previous = _document.activeElement;
  final field = _document.createElement('textarea'.toJS)
    ..value = text.toJS
    ..setAttribute('readonly'.toJS, ''.toJS)
    ..setAttribute('style'.toJS, 'position:fixed;top:0;left:0;opacity:0;'.toJS);
  body.append(field);
  try {
    field.focus();
    field.select();
    return _document.execCommand('copy'.toJS).toDart;
  } finally {
    field.remove();
    previous?.focus();
  }
}
