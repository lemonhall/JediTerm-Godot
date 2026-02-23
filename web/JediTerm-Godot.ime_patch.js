/* JediTerm-Godot Web IME patch
 *
 * Purpose:
 * - Work around Web export IME limitations by using a hidden <textarea>
 *   to receive composition/input events, then forwarding committed text
 *   to Godot via window.JediTermIME._sendText (set from GDScript via JavaScriptBridge).
 *
 * Notes:
 * - This intentionally avoids handling special keys in JS. For arrows/enter/backspace/etc,
 *   it forwards keydown/keyup back to the canvas so Godot's input system handles them.
 * - For printable characters (including IME commits), it forwards text via JediTermIME.
 */

(function () {
  "use strict";

  function ensureStyle() {
    if (document.getElementById("jediterm-ime-style")) return;
    var style = document.createElement("style");
    style.id = "jediterm-ime-style";
    style.textContent = [
      "#ime-input{",
      "position:fixed;",
      "left:0;top:0;",
      "width:8px;height:18px;",
      "opacity:0.01;",
      "z-index:2147483647;",
      "border:0;outline:none;",
      "background:transparent;",
      "color:transparent;",
      "caret-color:transparent;",
      "pointer-events:none;",
      "padding:0;margin:0;",
      "font-size:16px;line-height:18px;",
      "}",
    ].join("");
    document.head.appendChild(style);
  }

  function ensureImeInput() {
    var imeInput = document.getElementById("ime-input");
    if (imeInput) return imeInput;
    imeInput = document.createElement("textarea");
    imeInput.id = "ime-input";
    imeInput.setAttribute("autocapitalize", "off");
    imeInput.setAttribute("autocomplete", "off");
    imeInput.setAttribute("spellcheck", "false");
    imeInput.setAttribute("aria-hidden", "true");
    document.body.appendChild(imeInput);
    return imeInput;
  }

  function dispatchKeyboardEvent(canvas, type, src) {
    try {
      var evt = new KeyboardEvent(type, {
        key: src.key,
        code: src.code,
        location: src.location,
        repeat: src.repeat,
        shiftKey: src.shiftKey,
        ctrlKey: src.ctrlKey,
        altKey: src.altKey,
        metaKey: src.metaKey,
        bubbles: true,
        cancelable: true,
      });
      canvas.dispatchEvent(evt);
    } catch (_e) {
      // ignore
    }
  }

  function getJediTermIme() {
    // GDScript sets window.JediTermIME._sendText at runtime.
    window.JediTermIME = window.JediTermIME || {};
    return window.JediTermIME;
  }

  function isEnabled() {
    var ime = getJediTermIme();
    return Boolean(ime && ime._enabled);
  }

  function sendText(text) {
    if (!text) return;
    var ime = getJediTermIme();
    if (typeof ime.sendText === "function") {
      ime.sendText(text);
      return;
    }
    if (typeof ime._sendText === "function") {
      ime._sendText(text);
      return;
    }
    // If callback not ready yet, drop silently (engine may not be initialized).
  }

  function isPrintableKeyEvent(e) {
    if (e.ctrlKey || e.altKey || e.metaKey) return false;
    if (typeof e.key !== "string") return false;
    // Single Unicode character (includes space).
    return e.key.length === 1;
  }

  function isImeKeyEvent(e) {
    // keyCode 229 and key === "Process" are common IME indicators on web.
    return Boolean(e.isComposing) || e.keyCode === 229 || e.key === "Process";
  }

  function main() {
    var canvas = document.getElementById("canvas");
    if (!canvas) return;

    ensureStyle();
    var imeInput = ensureImeInput();

    var isComposing = false;
    var enabled = false;

    // Let Godot (via JavaScriptBridge) reposition the IME element near the caret.
    var ime = getJediTermIme();
    if (typeof ime.setCursorPosition !== "function") {
      ime.setCursorPosition = function (x, y) {
        imeInput.style.left = String(x | 0) + "px";
        imeInput.style.top = String(y | 0) + "px";
      };
    }

    if (typeof ime.setEnabled !== "function") {
      ime.setEnabled = function (v) {
        enabled = Boolean(v);
        ime._enabled = enabled;
        if (enabled) focusImeInput();
        else {
          try {
            imeInput.blur();
          } catch (_e) {}
        }
      };
    }

    function focusImeInput() {
      try {
        imeInput.focus({ preventScroll: true });
      } catch (_e) {
        try {
          imeInput.focus();
        } catch (_e2) {}
      }
    }

    // We need a user gesture to focus the textarea reliably.
    canvas.addEventListener("pointerdown", function () {
      if (enabled || isEnabled()) focusImeInput();
    });
    canvas.addEventListener("click", function () {
      if (enabled || isEnabled()) focusImeInput();
    });
    canvas.addEventListener("focus", function () {
      if (enabled || isEnabled()) focusImeInput();
    });

    imeInput.addEventListener("compositionstart", function () {
      if (!(enabled || isEnabled())) return;
      isComposing = true;
      // Keep the buffer empty; we only forward committed text.
      imeInput.value = "";
    });

    imeInput.addEventListener("compositionend", function (e) {
      if (!(enabled || isEnabled())) return;
      isComposing = false;
      // e.data is the committed string for many browsers; fall back to textarea value.
      var text = (e && e.data) ? String(e.data) : String(imeInput.value || "");
      if (text) sendText(text);
      imeInput.value = "";
    });

    // For non-IME typing, capture inserted characters via 'input'.
    imeInput.addEventListener("input", function () {
      if (!(enabled || isEnabled())) return;
      if (isComposing) return;
      var v = String(imeInput.value || "");
      if (!v) return;
      sendText(v);
      imeInput.value = "";
    });

    // Paste (including multi-line) should go as text.
    imeInput.addEventListener("paste", function () {
      if (!(enabled || isEnabled())) return;
      // Wait for the pasted content to land.
      setTimeout(function () {
        if (isComposing) return;
        var v = String(imeInput.value || "");
        if (!v) return;
        sendText(v);
        imeInput.value = "";
      }, 0);
    });

    // Forward non-IME keystrokes to Godot canvas so existing key handling keeps working
    // (including typing into Godot UI controls like LineEdit).
    imeInput.addEventListener("keydown", function (e) {
      if (!e) return;
      if (!(enabled || isEnabled())) return;

      // During IME composition, do not interfere.
      if (isComposing || isImeKeyEvent(e)) return;

      // For printable keys, let the textarea receive them; 'input' will forward text.
      if (isPrintableKeyEvent(e)) return;

      dispatchKeyboardEvent(canvas, "keydown", e);
      dispatchKeyboardEvent(canvas, "keyup", e);
      e.preventDefault();
    });

    // Default disabled until Godot terminal control requests it.
    ime._enabled = false;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", main);
  } else {
    main();
  }
})();
