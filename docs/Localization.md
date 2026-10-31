# Localization

English is the source language. Every other locale falls back to it.

`Locales/enUS.lua` defines every string. Each `Locales/<locale>.lua` file overrides the
strings that it translates. If a locale does not define a key, the addon shows the English
text. A locale does not have to be complete.

Three locales have real translations: `koKR`, `zhCN`, and `zhTW`. The other seven files are
empty stubs.

The Language setting on the General page lists only the locales with real translations. A
locale file goes into the list when it registers its language name in `BR.translatedLocales`,
in the line above its locale check:

```lua
BR.translatedLocales.zhCN = "简体中文"
```

If you translate a stub locale, add this line with the name of your language in your language.

---

## Translate a locale

1. Open `Locales/<locale>.lua`, for example `Locales/itIT.lua`.
2. Read `Locales/enUS.lua` for the keys and the English text.
3. Add one line per key: `L["Category.Raid"] = "Your translation"`.
4. Run `make i18n ARGS="<locale>"` to list the keys that are still missing.
5. Open a pull request. Use the commit message `i18n(<locale>): 🌐 update localization`.

Translate the keys that you are sure about. Leave the rest.

Rules:

- Translate only the text on the right of the `=` sign. Do not translate the key.
- Keep every format specifier, such as `%s`, `%d`, and `%1$s`.
- Keep `Overlay.*` strings to 2-4 characters per line. The addon shows these strings on top
  of a buff icon.
- Translate `ChatRequest.*` only in `koKR`, `zhCN`, and `zhTW`. These strings go into chat,
  and players on other realms read them in English.
- If you want credit, add a comment at the top of the file.

To see your translation in game, set the client to your locale. Then run `/reload`. If your
locale is in the Language setting on the General page, you can select it there. The game client
does not have to change.

---

## Why a translated line gets removed

If the English text changes meaning, the line for that key goes out of the translated files.

This is not a complaint about the translation. No translator was harmed, and the line comes
back when somebody translates the new text. There are two reasons:

- The old translation now says the wrong thing. English replaces it immediately.
- `make i18n ARGS="<locale>"` lists the keys that a locale does not define, with their
  English text. A stale line hides the key from that list. Then nobody learns that the
  string moved.

If the wording changed but the meaning is the same, the translation stays.
