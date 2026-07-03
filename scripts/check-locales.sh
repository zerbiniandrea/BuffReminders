#!/usr/bin/env bash
# Locale diagnostics tool for BuffReminders
#
# Usage:
#   scripts/check-locales.sh              Show summary for all locales
#   scripts/check-locales.sh zhCN         Show details for one locale
#   scripts/check-locales.sh zhCN koKR    Show details for multiple locales
#
# The enUS <-> source sync check always runs (missing/unused keys are errors).
# Non-English locales report coverage stats but never fail the script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCALES_DIR="$ROOT/Locales"

# --- Collect keys -----------------------------------------------------------
defined=$(grep -oP 'english\["[^"]+"\]' "$LOCALES_DIR/enUS.lua" | sed 's/english\["\(.*\)"\]/\1/' | sort -u)
enUS_count=$(echo "$defined" | wc -l)

# Every dotted string literal in source. This is intentionally broad: it catches
# keys however they reach L[] - directly (L["Foo.Bar"]), as a role-key value
# (labelKey = "Foo.Bar"), passed positionally (ToggleCaption(g, "Foo.Bar", ...)),
# or as a table value (SCOPE_LABELS = { raid = "Loadout.Scope.Raid" }). It also
# sweeps in non-label strings like config paths ("defaults.iconWidth"), but those
# are filtered out below by intersecting with the defined keys - a literal only
# counts as a used key when enUS actually defines it. The regex matches dotted
# identifier tokens only (no spaces), so English text never leaks in.
literals=$(grep -rhoP '"[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+"' "$ROOT" --include='*.lua' --exclude-dir=Locales --exclude-dir=Libs --exclude-dir=.ignored | tr -d '"' | sort -u)

# Concatenation prefixes: L["Options.Glow." .. spec.labelKey]. The full key never
# appears as a literal, so mark every defined key under such a prefix as used.
concat_prefixes=$(grep -rhoP 'L\["[^"]+"\s*\.\.' "$ROOT" --include='*.lua' --exclude-dir=Locales --exclude-dir=Libs --exclude-dir=.ignored | sed -E 's/^L\["//' | sed -E 's/"[[:space:]]*\.\..*$//' | sort -u)
prefix_used=""
if [ -n "$concat_prefixes" ]; then
    while IFS= read -r prefix; do
        [ -z "$prefix" ] && continue
        match=$(awk -v p="$prefix" 'index($0, p) == 1' <<< "$defined" || true)
        [ -n "$match" ] && prefix_used="$prefix_used"$'\n'"$match"
    done <<< "$concat_prefixes"
fi

# A defined key is "used" when it appears as a literal or is covered by a prefix.
used=$(printf '%s\n%s\n' "$(comm -12 <(echo "$literals") <(echo "$defined"))" "$prefix_used" | grep -v '^$' | sort -u)

# Direct L["..."] references - the only reliable signal for "referenced a key that
# doesn't exist" (a bare dotted literal could just be a config path, not a typo).
direct_used=$(grep -rhoP 'L\["[^"]+"\]' "$ROOT" --include='*.lua' --exclude-dir=Locales --exclude-dir=Libs --exclude-dir=.ignored | sed 's/L\["\(.*\)"\]/\1/' | sort -u)

errors=0

# --- enUS <-> source sync (always checked, always errors) --------------------
missing_src=$(comm -23 <(echo "$direct_used") <(echo "$defined"))
unused_src=$(comm -13 <(echo "$used") <(echo "$defined") | grep -v '^ChatRequest\.' || true)

if [ -n "$missing_src" ]; then
    echo "ERROR  Used in source but not defined in enUS.lua:"
    echo "$missing_src" | sed 's/^/  /'
    errors=1
fi

if [ -n "$unused_src" ]; then
    echo "ERROR  Defined in enUS.lua but not used in source:"
    echo "$unused_src" | sed 's/^/  /'
    errors=1
fi

# --- ChatRequest.* restricted to Asian locales only --------------------------
asian_locales="zhCN zhTW koKR"
for file in "$LOCALES_DIR"/*.lua; do
    locale=$(basename "$file" .lua)
    [ "$locale" = "enUS" ] && continue
    # Skip Asian locales - they're allowed to translate ChatRequest keys
    case " $asian_locales " in
        *" $locale "*) continue ;;
    esac
    chat_keys=$(grep -v '^\s*--' "$file" | grep -oP 'L\["ChatRequest\.[^"]+"\]' 2>/dev/null || true)
    if [ -n "$chat_keys" ]; then
        echo "ERROR  $locale.lua must not translate ChatRequest.* keys (chat messages stay in English on non-Asian servers):"
        echo "$chat_keys" | sed 's/^/  /'
        errors=1
    fi
done

# --- Helpers -----------------------------------------------------------------
get_locale_keys() {
    local file="$1"
    grep -v '^\s*--' "$file" | grep -oP 'L\["[^"]+"\]' 2>/dev/null | sed 's/L\["\(.*\)"\]/\1/' | sort -u || true
}

lookup_english() {
    local key="$1"
    local needle="english[\"$key\"]"
    awk -v needle="$needle" '
        index($0, needle) {
            sub(/^[^=]*=[ \t]*/, "")
            val = $0
            while (val !~ /"[^"]*"$/ && val !~ /\]$/) {
                getline
                sub(/^[ \t]*/, "")
                if (val == "") val = $0
                else val = val " " $0
            }
            gsub(/^"/, "", val)
            gsub(/"$/, "", val)
            print val
            exit
        }
    ' "$LOCALES_DIR/enUS.lua"
}

print_locale_detail() {
    local locale="$1"
    local file="$LOCALES_DIR/$locale.lua"
    if [ ! -f "$file" ]; then
        echo "No file: $file"
        return
    fi

    local trans_keys
    trans_keys=$(get_locale_keys "$file")
    local count
    count=$([ -n "$trans_keys" ] && echo "$trans_keys" | wc -l || echo 0)
    local pct=$((count * 100 / enUS_count))

    echo ""
    echo "── $locale ($count/$enUS_count - ${pct}%) ──"

    if [ "$count" -eq "$enUS_count" ]; then
        local extra
        extra=$(comm -23 <(echo "$trans_keys") <(echo "$defined"))
        if [ -z "$extra" ]; then
            echo "  Complete ✓"
        fi
    fi

    # Missing keys (in enUS but not in this locale)
    if [ -n "$trans_keys" ]; then
        local missing
        missing=$(comm -23 <(echo "$defined") <(echo "$trans_keys"))
        if [ -n "$missing" ]; then
            echo "  Missing ($(echo "$missing" | wc -l)):"
            while IFS= read -r key; do
                local val
                val=$(lookup_english "$key")
                echo "    $key = $val"
            done <<< "$missing"
        fi
    else
        echo "  No translations (empty file)"
    fi

    # Extra keys (in this locale but not in enUS - stale/typos)
    if [ -n "$trans_keys" ]; then
        local extra
        extra=$(comm -23 <(echo "$trans_keys") <(echo "$defined"))
        if [ -n "$extra" ]; then
            echo "  Extra ($(echo "$extra" | wc -l)):"
            echo "$extra" | sed 's/^/    /'
        fi
    fi
}

# --- Locale filter -----------------------------------------------------------
filter_locales=()
for arg in "$@"; do
    filter_locales+=("$arg")
done

# --- Per-locale report -------------------------------------------------------
if [ ${#filter_locales[@]} -gt 0 ]; then
    # Detailed view for requested locales
    for locale in "${filter_locales[@]}"; do
        print_locale_detail "$locale"
    done
else
    # Summary table for all locales
    echo ""
    printf "  %-8s %6s  %s\n" "Locale" "Keys" "Coverage"
    printf "  %-8s %6s  %s\n" "------" "----" "--------"
    for file in "$LOCALES_DIR"/*.lua; do
        locale=$(basename "$file" .lua)
        [ "$locale" = "enUS" ] && continue
        trans_keys=$(get_locale_keys "$file")
        count=$([ -n "$trans_keys" ] && echo "$trans_keys" | wc -l || echo 0)
        pct=$((count * 100 / enUS_count))

        extra=""
        if [ -n "$trans_keys" ]; then
            extra_keys=$(comm -23 <(echo "$trans_keys") <(echo "$defined"))
            if [ -n "$extra_keys" ]; then
                extra="  ⚠ $(echo "$extra_keys" | wc -l) extra"
            fi
        fi

        bar_filled=$((pct / 5))
        bar_empty=$((20 - bar_filled))
        bar=""
        [ "$bar_filled" -gt 0 ] && bar=$(printf '█%.0s' $(seq 1 $bar_filled))
        [ "$bar_empty" -gt 0 ] && bar="$bar$(printf '░%.0s' $(seq 1 $bar_empty))"

        printf "  %-8s %3d/%-3d %s %3d%%%s\n" "$locale" "$count" "$enUS_count" "$bar" "$pct" "$extra"
    done
    echo ""
    echo "  enUS: $enUS_count keys (source of truth)"
    echo ""
    echo "  Run with locale name(s) for details: scripts/check-locales.sh zhCN koKR"
fi

exit $errors
