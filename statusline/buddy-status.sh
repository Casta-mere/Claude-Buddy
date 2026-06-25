#!/usr/bin/env bash
# claude-buddy status line — animated, right-aligned multi-line companion
# Uses Braille Blank (U+2800) for padding — survives JS .trim()

# UTF-8 locale so ${#str} counts display columns (block glyphs = 1 col), keeping
# the right-alignment width math exact even with Unicode bars.
export LC_ALL=en_US.UTF-8

STATE="$HOME/.claude-buddy/status.json"
COMPANION="$HOME/.claude-buddy/companion.json"

[ -f "$STATE" ] || exit 0
[ -f "$COMPANION" ] || exit 0

MUTED=$(jq -r '.muted // false' "$STATE" 2>/dev/null)
[ "$MUTED" = "true" ] && exit 0

NAME=$(jq -r '.name // ""' "$STATE" 2>/dev/null)
[ -z "$NAME" ] && exit 0

SPECIES=$(jq -r '.species // ""' "$STATE" 2>/dev/null)
HAT=$(jq -r '.hat // "none"' "$STATE" 2>/dev/null)
RARITY=$(jq -r '.rarity // "common"' "$STATE" 2>/dev/null)
REACTION=$(jq -r '.reaction // ""' "$STATE" 2>/dev/null)
E=$(jq -r '.bones.eye // "o"' "$COMPANION" 2>/dev/null)

INPUT=$(cat)  # Claude Code status JSON on stdin

# ─── Status bar inputs (all optional; missing fields collapse cleanly) ────────
SB_MODEL=$(printf '%s' "$INPUT"   | jq -r '.model.display_name // empty' 2>/dev/null)
SB_EFFORT=$(printf '%s' "$INPUT"  | jq -r '.effort.level // empty' 2>/dev/null)
SB_THINKON=$(printf '%s' "$INPUT" | jq -r '.thinking.enabled // false' 2>/dev/null)
SB_FAST=$(printf '%s' "$INPUT"    | jq -r '.fast_mode // false' 2>/dev/null)
SB_CWD=$(printf '%s' "$INPUT"     | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
SB_WINSIZE=$(printf '%s' "$INPUT" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)
SB_CTXPCT=$(printf '%s' "$INPUT"  | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
SB_DURMS=$(printf '%s' "$INPUT"   | jq -r '.cost.total_duration_ms // empty' 2>/dev/null)
SB_5HPCT=$(printf '%s' "$INPUT"   | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
SB_5HRST=$(printf '%s' "$INPUT"   | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
SB_7DPCT=$(printf '%s' "$INPUT"   | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
SB_7DRST=$(printf '%s' "$INPUT"   | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
# Account identity from CLAUDE_CONFIG_DIR (e.g. ~/.claude-work → "claude-work").
SB_CFGDIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SB_ACCT=$(basename "$SB_CFGDIR"); SB_ACCT="${SB_ACCT#.}"; [ -z "$SB_ACCT" ] && SB_ACCT="claude"
SB_EMAIL=$(jq -r '.oauthAccount.emailAddress // empty' "$SB_CFGDIR/.claude.json" 2>/dev/null)
[ -z "$SB_EMAIL" ] && SB_EMAIL=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
SB_BRANCH=""
[ -n "$SB_CWD" ] && SB_BRANCH=$(git -C "$SB_CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Shared write-through usage cache: each account leaves its latest rate-limit
# snapshot here so the bar can show every account, not just the active session's.
SB_USAGE_DIR="$HOME/.claude-buddy/usage"
SB_NOW=$(date +%s)
if [ -n "$SB_5HPCT" ]; then
    mkdir -p "$SB_USAGE_DIR" 2>/dev/null
    SB_TMP="$SB_USAGE_DIR/.${SB_ACCT}.$$.tmp"
    printf '{"label":"%s","email":"%s","five_hour":{"pct":%s,"resets_at":%s},"seven_day":{"pct":%s,"resets_at":%s},"ts":%s}\n' \
        "$SB_ACCT" "$SB_EMAIL" "${SB_5HPCT:-0}" "${SB_5HRST:-0}" "${SB_7DPCT:-0}" "${SB_7DRST:-0}" "$SB_NOW" \
        > "$SB_TMP" 2>/dev/null && mv -f "$SB_TMP" "$SB_USAGE_DIR/${SB_ACCT}.json" 2>/dev/null
fi

# ─── Animation ───────────────────────────────────────────────────────────────
SEQ=(0 0 0 0 1 0 0 0 -1 0 0 2 0 0 0)
SEQ_LEN=${#SEQ[@]}
NOW=$(date +%s)
FRAME=${SEQ[$(( NOW % SEQ_LEN ))]}

BLINK=0
if [ "$FRAME" -eq -1 ]; then
    BLINK=1
    FRAME=0
fi

# ─── Rarity color ────────────────────────────────────────────────────────────
NC=$'\033[0m'
case "$RARITY" in
  common)    C=$'\033[38;2;153;153;153m' ;;
  uncommon)  C=$'\033[38;2;78;186;101m'  ;;
  rare)      C=$'\033[38;2;177;185;249m' ;;
  epic)      C=$'\033[38;2;175;135;255m' ;;
  legendary) C=$'\033[38;2;255;193;7m'   ;;
  *)         C=$'\033[0m' ;;
esac

B=$'\xe2\xa0\x80'  # Braille Blank U+2800 — survives .trim()

# ─── Terminal width (walk process tree to find real TTY on macOS) ─────────────
COLS=0
PID=$$
for _ in 1 2 3 4 5; do
    PID=$(ps -o ppid= -p "$PID" 2>/dev/null | tr -d ' ')
    [ -z "$PID" ] || [ "$PID" = "1" ] && break
    TTY=$(ps -o tty= -p "$PID" 2>/dev/null | tr -d ' ')
    if [ -n "$TTY" ] && [ "$TTY" != "??" ] && [ "$TTY" != "-" ]; then
        COLS=$(stty size < "/dev/$TTY" 2>/dev/null | awk '{print $2}')
        [ "${COLS:-0}" -gt 40 ] 2>/dev/null && break
        COLS=0
    fi
done
[ "${COLS:-0}" -lt 40 ] && COLS=$(tput cols 2>/dev/null || echo 0)
[ "${COLS:-0}" -lt 40 ] && COLS=${COLUMNS:-0}
[ "${COLS:-0}" -lt 40 ] && COLS=125

# Override reaction with this terminal's session (TTY-scoped isolation)
if [ -n "$TTY" ] && [ "$TTY" != "??" ] && [ "$TTY" != "-" ]; then
  SID=$(cat "$HOME/.claude-buddy/tty-sessions/$TTY" 2>/dev/null)
  if [ -n "$SID" ]; then
    SESSION_FILE="$HOME/.claude-buddy/sessions/${SID}.json"
    if [ -f "$SESSION_FILE" ]; then
      SESSION_REACTION=$(jq -r '.reaction // ""' "$SESSION_FILE" 2>/dev/null)
      [ -n "$SESSION_REACTION" ] && REACTION="$SESSION_REACTION"
    fi
  fi
fi

# ─── Species art: 3 frames, 4 lines each ─────────────────────────────────────
case "$SPECIES" in
  duck)
    case $FRAME in
      0) L1="   __";      L2=" <(${E} )___"; L3="  (  ._>";   L4="   \`--'" ;;
      1) L1="   __";      L2=" <(${E} )___"; L3="  (  ._>";   L4="   \`--'~" ;;
      2) L1="   __";      L2=" <(${E} )___"; L3="  (  .__>";  L4="   \`--'" ;;
    esac ;;
  goose)
    case $FRAME in
      0) L1="  (${E}>";    L2="   ||";       L3=" _(__)_";   L4="  ^^^^" ;;
      1) L1=" (${E}>";     L2="   ||";       L3=" _(__)_";   L4="  ^^^^" ;;
      2) L1="  (${E}>>";   L2="   ||";       L3=" _(__)_";   L4="  ^^^^" ;;
    esac ;;
  blob)
    case $FRAME in
      0) L1=" .----.";    L2="( ${E}  ${E} )"; L3="(      )";  L4=" \`----'" ;;
      1) L1=".------.";   L2="( ${E}  ${E} )"; L3="(       )"; L4="\`------'" ;;
      2) L1="  .--.";     L2=" (${E}  ${E})";  L3=" (    )";   L4="  \`--'" ;;
    esac ;;
  cat)
    case $FRAME in
      0) L1=" /\\_/\\";   L2="( ${E}   ${E})"; L3="(  w  )";  L4="(\")_(\")" ;;
      1) L1=" /\\_/\\";   L2="( ${E}   ${E})"; L3="(  w  )";  L4="(\")_(\")~" ;;
      2) L1=" /\\-/\\";   L2="( ${E}   ${E})"; L3="(  w  )";  L4="(\")_(\")" ;;
    esac ;;
  dragon)
    case $FRAME in
      0) L1="/^\\  /^\\"; L2="< ${E}  ${E} >"; L3="(  ~~  )"; L4=" \`-vvvv-'" ;;
      1) L1="/^\\  /^\\"; L2="< ${E}  ${E} >"; L3="(      )"; L4=" \`-vvvv-'" ;;
      2) L1="/^\\  /^\\"; L2="< ${E}  ${E} >"; L3="(  ~~  )"; L4=" \`-vvvv-'" ;;
    esac ;;
  octopus)
    case $FRAME in
      0) L1=" .----.";   L2="( ${E}  ${E} )"; L3="(______)"; L4="/\\/\\/\\/\\" ;;
      1) L1=" .----.";   L2="( ${E}  ${E} )"; L3="(______)"; L4="\\/\\/\\/\\/" ;;
      2) L1=" .----.";   L2="( ${E}  ${E} )"; L3="(______)"; L4="/\\/\\/\\/\\" ;;
    esac ;;
  owl)
    case $FRAME in
      0) L1=" /\\  /\\";  L2="((${E})(${E}))"; L3="(  ><  )"; L4=" \`----'" ;;
      1) L1=" /\\  /\\";  L2="((${E})(${E}))"; L3="(  ><  )"; L4=" .----." ;;
      2) L1=" /\\  /\\";  L2="((${E})(-))";    L3="(  ><  )"; L4=" \`----'" ;;
    esac ;;
  penguin)
    case $FRAME in
      0) L1=" .---.";    L2=" (${E}>${E})";   L3="/(   )\\"; L4=" \`---'" ;;
      1) L1=" .---.";    L2=" (${E}>${E})";   L3="|(   )|";  L4=" \`---'" ;;
      2) L1=" .---.";    L2=" (${E}>${E})";   L3="/(   )\\"; L4=" \`---'" ;;
    esac ;;
  turtle)
    case $FRAME in
      0) L1=" _,--._";   L2="( ${E}  ${E} )"; L3="[______]"; L4="\`\`    \`\`" ;;
      1) L1=" _,--._";   L2="( ${E}  ${E} )"; L3="[______]"; L4=" \`\`  \`\`" ;;
      2) L1=" _,--._";   L2="( ${E}  ${E} )"; L3="[======]"; L4="\`\`    \`\`" ;;
    esac ;;
  snail)
    case $FRAME in
      0) L1="${E}   .--."; L2="\\  ( @ )";   L3=" \\_\`--'"; L4="~~~~~~~" ;;
      1) L1=" ${E}  .--."; L2="|  ( @ )";   L3=" \\_\`--'"; L4="~~~~~~~" ;;
      2) L1="${E}   .--."; L2="\\  ( @ )";   L3=" \\_\`--'"; L4=" ~~~~~~" ;;
    esac ;;
  ghost)
    case $FRAME in
      0) L1=" .----.";   L2="/ ${E}  ${E} \\"; L3="|      |"; L4="~\`~\`\`~\`~" ;;
      1) L1=" .----.";   L2="/ ${E}  ${E} \\"; L3="|      |"; L4="\`~\`~~\`~\`" ;;
      2) L1=" .----.";   L2="/ ${E}  ${E} \\"; L3="|      |"; L4="~~\`~~\`~~" ;;
    esac ;;
  axolotl)
    case $FRAME in
      0) L1="}~(____)~{"; L2="}~(${E}..${E})~{"; L3="  (.--.)";  L4="  (_/\\_)" ;;
      1) L1="~}(____){~"; L2="~}(${E}..${E}){~"; L3="  (.--.)";  L4="  (_/\\_)" ;;
      2) L1="}~(____)~{"; L2="}~(${E}..${E})~{"; L3="  ( -- )";  L4="  ~_/\\_~" ;;
    esac ;;
  capybara)
    case $FRAME in
      0) L1="n______n";  L2="( ${E}    ${E} )"; L3="(  oo  )"; L4="\`------'" ;;
      1) L1="n______n";  L2="( ${E}    ${E} )"; L3="(  Oo  )"; L4="\`------'" ;;
      2) L1="u______n";  L2="( ${E}    ${E} )"; L3="(  oo  )"; L4="\`------'" ;;
    esac ;;
  cactus)
    case $FRAME in
      0) L1="n ____ n";  L2="||${E}  ${E}||"; L3="|_|  |_|"; L4="  |  |" ;;
      1) L1="  ____";    L2="n|${E}  ${E}|n"; L3="|_|  |_|"; L4="  |  |" ;;
      2) L1="n ____ n";  L2="||${E}  ${E}||"; L3="|_|  |_|"; L4="  |  |" ;;
    esac ;;
  robot)
    case $FRAME in
      0) L1=" .[||].";   L2="[ ${E}  ${E} ]"; L3="[ ==== ]"; L4="\`------'" ;;
      1) L1=" .[||].";   L2="[ ${E}  ${E} ]"; L3="[ -==- ]"; L4="\`------'" ;;
      2) L1=" .[||].";   L2="[ ${E}  ${E} ]"; L3="[ ==== ]"; L4="\`------'" ;;
    esac ;;
  rabbit)
    case $FRAME in
      0) L1=" (\\__/)";  L2="( ${E}  ${E} )"; L3="=(  ..  )="; L4="(\")__(\")" ;;
      1) L1=" (|__/)";   L2="( ${E}  ${E} )"; L3="=(  ..  )="; L4="(\")__(\")" ;;
      2) L1=" (\\__/)";  L2="( ${E}  ${E} )"; L3="=( .  . )="; L4="(\")__(\")" ;;
    esac ;;
  mushroom)
    case $FRAME in
      0) L1="-o-OO-o-";  L2="(________)";  L3="  |${E}${E}|"; L4="  |__|" ;;
      1) L1="-O-oo-O-";  L2="(________)";  L3="  |${E}${E}|"; L4="  |__|" ;;
      2) L1="-o-OO-o-";  L2="(________)";  L3="  |${E}${E}|"; L4="  |__|" ;;
    esac ;;
  chonk)
    case $FRAME in
      0) L1="/\\    /\\"; L2="( ${E}    ${E} )"; L3="(  ..  )"; L4="\`------'" ;;
      1) L1="/\\    /|";  L2="( ${E}    ${E} )"; L3="(  ..  )"; L4="\`------'" ;;
      2) L1="/\\    /\\"; L2="( ${E}    ${E} )"; L3="(  ..  )"; L4="\`------'~" ;;
    esac ;;
  *)
    L1="(${E}${E})"; L2="(  )"; L3=""; L4="" ;;
esac

# ─── Blink: replace eyes with "-" ────────────────────────────────────────────
if [ "$BLINK" -eq 1 ]; then
    L1="${L1//${E}/-}"
    L2="${L2//${E}/-}"
    L3="${L3//${E}/-}"
    L4="${L4//${E}/-}"
fi

# ─── Hat ──────────────────────────────────────────────────────────────────────
HAT_LINE=""
case "$HAT" in
  crown)     HAT_LINE=" \\^^^/" ;;
  tophat)    HAT_LINE=" [___]" ;;
  propeller) HAT_LINE="  -+-" ;;
  halo)      HAT_LINE=" (   )" ;;
  wizard)    HAT_LINE="  /^\\" ;;
  beanie)    HAT_LINE=" (___)" ;;
  tinyduck)  HAT_LINE="  ,>" ;;
esac

# ─── Build all art lines ─────────────────────────────────────────────────────
DIM=$'\033[2;3m'

ALL_LINES=()
ALL_COLORS=()
[ -n "$HAT_LINE" ] && { ALL_LINES+=("$HAT_LINE"); ALL_COLORS+=("$C"); }
ALL_LINES+=("$L1"); ALL_COLORS+=("$C")
ALL_LINES+=("$L2"); ALL_COLORS+=("$C")
ALL_LINES+=("$L3"); ALL_COLORS+=("$C")
[ -n "$L4" ] && { ALL_LINES+=("$L4"); ALL_COLORS+=("$C"); }

# Center the name
NAME_LEN=${#NAME}
ART_CENTER=4
NAME_PAD=$(( ART_CENTER - NAME_LEN / 2 ))
[ "$NAME_PAD" -lt 0 ] && NAME_PAD=0
NAME_LINE="$(printf '%*s%s' "$NAME_PAD" '' "$NAME")"
ALL_LINES+=("$NAME_LINE"); ALL_COLORS+=("$DIM")

ART_W=14
ART_COUNT=${#ALL_LINES[@]}

# ─── Speech bubble (word-wrapped box to the left) ────────────────────────────
BUBBLE_TEXT=""
if [ -n "$REACTION" ] && [ "$REACTION" != "null" ]; then
    BUBBLE_TEXT="$REACTION"
fi

INNER_W=28
TEXT_LINES=()
if [ -n "$BUBBLE_TEXT" ]; then
    read -ra WORDS <<< "$BUBBLE_TEXT"
    CUR_LINE=""
    for word in "${WORDS[@]}"; do
        if [ -z "$CUR_LINE" ]; then
            CUR_LINE="$word"
        elif [ $(( ${#CUR_LINE} + 1 + ${#word} )) -le $INNER_W ]; then
            CUR_LINE="$CUR_LINE $word"
        else
            TEXT_LINES+=("$CUR_LINE")
            CUR_LINE="$word"
        fi
    done
    [ -n "$CUR_LINE" ] && TEXT_LINES+=("$CUR_LINE")
fi

TEXT_COUNT=${#TEXT_LINES[@]}
BOX_W=$(( INNER_W + 4 ))
BUBBLE_LINES=()
BUBBLE_TYPES=()
if [ $TEXT_COUNT -gt 0 ]; then
    BORDER=$(printf '%*s' "$(( BOX_W - 2 ))" '' | tr ' ' '-')
    BUBBLE_LINES+=(".${BORDER}.")
    BUBBLE_TYPES+=("border")
    for tl in "${TEXT_LINES[@]}"; do
        tpad=$(( INNER_W - ${#tl} ))
        [ "$tpad" -lt 0 ] && tpad=0
        padding=$(printf '%*s' "$tpad" '')
        BUBBLE_LINES+=("| ${tl}${padding} |")
        BUBBLE_TYPES+=("text")
    done
    BUBBLE_LINES+=("\`${BORDER}'")
    BUBBLE_TYPES+=("border")
fi

BUBBLE_COUNT=${#BUBBLE_LINES[@]}

# ─── Right-align: Braille Blank prefix prevents .trim() ─────────────────────
GAP=2
if [ $BUBBLE_COUNT -gt 0 ]; then
    TOTAL_W=$(( BOX_W + GAP + ART_W ))
else
    TOTAL_W=$ART_W
fi
MARGIN=8
PAD=$(( COLS - TOTAL_W - MARGIN ))
[ "$PAD" -lt 0 ] && PAD=0

# Vertically center bubble on art
BUBBLE_START=0
if [ $BUBBLE_COUNT -gt 0 ] && [ $BUBBLE_COUNT -lt $ART_COUNT ]; then
    BUBBLE_START=$(( (ART_COUNT - BUBBLE_COUNT) / 2 ))
fi

# Connector line (middle text row)
CONNECTOR_BI=-1
if [ $BUBBLE_COUNT -gt 2 ]; then
    FIRST_TEXT=1
    LAST_TEXT=$(( BUBBLE_COUNT - 2 ))
    CONNECTOR_BI=$(( (FIRST_TEXT + LAST_TEXT) / 2 ))
fi

# ─── Left status bar (stacked: identity / workspace / context / one row per account) ──
# Palette (truecolor). Block glyphs are 1 display column each; LC_ALL keeps ${#} honest.
CLR_MODEL=$'\033[1;38;2;130;170;255m'   # model name (bold blue)
CLR_THINK=$'\033[38;2;199;146;234m'     # thinking level (mauve)
CLR_FAST=$'\033[38;2;255;176;102m'      # fast mode (amber)
CLR_DIR=$'\033[38;2;94;200;230m'        # working dir (cyan)
CLR_BRANCH=$'\033[38;2;120;200;120m'    # git branch (green)
CLR_TIMER=$'\033[38;2;150;160;180m'     # session timer (slate)
CLR_GREEN=$'\033[38;2;120;200;120m'     # usage < 50%
CLR_YEL=$'\033[38;2;235;200;90m'        # usage 50-79%
CLR_RED=$'\033[38;2;235;110;110m'       # usage >= 80%
CLR_TRACK=$'\033[38;2;78;82;94m'        # empty bar track
CLR_SEP=$'\033[38;2;75;79;98m'          # " | " separators
MKC="$CLR_GREEN"                         # active-account marker ▸
# Per-account tints (cycled by account, so each keeps its color regardless of which is active)
CLR_ACCT=("$(printf '\033[1;38;2;125;207;255m')" \
          "$(printf '\033[1;38;2;199;148;246m')" \
          "$(printf '\033[1;38;2;115;208;196m')" \
          "$(printf '\033[1;38;2;224;175;104m')")

sb_thr() {  # $1=pct -> echo threshold color
    if   [ "${1:-0}" -lt 50 ] 2>/dev/null; then printf '%s' "$CLR_GREEN"
    elif [ "${1:-0}" -lt 80 ] 2>/dev/null; then printf '%s' "$CLR_YEL"
    else printf '%s' "$CLR_RED"; fi
}
_BP=""; _BC=""  # last bar built: plain glyphs / colored glyphs
sb_bar() {  # $1=pct $2=width -> sets _BP and _BC (filled=threshold color, empty=track)
    local pct=$1 w=$2 fill i col switched=0
    [ "${pct:-0}" -gt 100 ] 2>/dev/null && pct=100
    [ "${pct:-0}" -lt 0 ] 2>/dev/null && pct=0
    fill=$(( (pct * w + 50) / 100 ))
    col=$(sb_thr "$pct")
    _BP=""; _BC="$col"
    for (( i=0; i<w; i++ )); do
        if [ $i -lt $fill ]; then _BP+="█"; _BC+="█"
        else
            [ $switched -eq 0 ] && { _BC+="${NC}${CLR_TRACK}"; switched=1; }
            _BP+="░"; _BC+="░"
        fi
    done
    _BC+="${NC}"
}
sb_dur() {  # $1=seconds -> "Xd Yh" / "Xh Ym" / "Zm" (spaced)
    local s=$1 d h m
    [ "${s:-0}" -lt 0 ] 2>/dev/null && s=0
    d=$(( s/86400 )); h=$(( (s%86400)/3600 )); m=$(( (s%3600)/60 ))
    if [ $d -gt 0 ]; then printf '%dd %dh' "$d" "$h"
    elif [ $h -gt 0 ]; then printf '%dh %dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}
sb_durc() {  # compact two-unit: "5d21h" / "1h57m" / "57m"
    local s=$1 d h m
    [ "${s:-0}" -lt 0 ] 2>/dev/null && s=0
    d=$(( s/86400 )); h=$(( (s%86400)/3600 )); m=$(( (s%3600)/60 ))
    if [ $d -gt 0 ]; then printf '%dd%dh' "$d" "$h"
    elif [ $h -gt 0 ]; then printf '%dh%dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}
sb_age() {  # one-unit: "2h" / "3d" / "5m"
    local s=$1 d h m
    [ "${s:-0}" -lt 0 ] 2>/dev/null && s=0
    d=$(( s/86400 )); h=$(( (s%86400)/3600 )); m=$(( (s%3600)/60 ))
    if [ $d -gt 0 ]; then printf '%dd' "$d"
    elif [ $h -gt 0 ]; then printf '%dh' "$h"
    else printf '%dm' "$m"; fi
}
sb_cap() {  # capitalize first letter
    printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}
LEFT_P=(); LEFT_D=()  # one entry per left row: plain (for width) / colored (for display)
add_row() { LEFT_P+=("$1"); LEFT_D+=("$2"); }

WINLBL=""
if [ -n "$SB_WINSIZE" ]; then
    if [ "$SB_WINSIZE" -ge 1000000 ] 2>/dev/null; then WINLBL=" (1M context)"
    elif [ "$SB_WINSIZE" -ge 1000 ] 2>/dev/null; then WINLBL=" ($(( SB_WINSIZE/1000 ))K context)"; fi
fi

# Row: identity — [model (window) | effort] · email
if [ -n "$SB_MODEL" ] || [ -n "$SB_EMAIL" ]; then
    P=""; D=""
    if [ -n "$SB_MODEL" ]; then
        effP=""; effC=""
        if [ "$SB_THINKON" = "true" ] && [ -n "$SB_EFFORT" ]; then
            e=$(sb_cap "$SB_EFFORT"); effP=" | $e"; effC="${DIM} | ${NC}${CLR_THINK}${e}${NC}"
        fi
        [ "$SB_FAST" = "true" ] && { effP="$effP | Fast"; effC="${effC}${DIM} | ${NC}${CLR_FAST}Fast${NC}"; }
        P="[${SB_MODEL}${WINLBL}${effP}]"
        D="${DIM}[${NC}${CLR_MODEL}${SB_MODEL}${NC}${DIM}${WINLBL}${NC}${effC}${DIM}]${NC}"
    fi
    if [ -n "$SB_EMAIL" ]; then
        if [ -n "$P" ]; then P+=" | ${SB_EMAIL}"; D+="${CLR_SEP} | ${NC}${DIM}${SB_EMAIL}${NC}"
        else P="$SB_EMAIL"; D="${DIM}${SB_EMAIL}${NC}"; fi
    fi
    add_row "$P" "$D"
fi

# Row: workspace — dir git:(branch) · timer
if [ -n "$SB_CWD" ]; then
    dn=$(basename "$SB_CWD")
    if [ -n "$SB_BRANCH" ]; then
        P="${dn} git:(${SB_BRANCH})"
        D="${CLR_DIR}${dn}${NC} ${DIM}git:(${NC}${CLR_BRANCH}${SB_BRANCH}${NC}${DIM})${NC}"
    else
        P="$dn"; D="${CLR_DIR}${dn}${NC}"
    fi
    if [ -n "$SB_DURMS" ]; then
        t=$(sb_dur $(( SB_DURMS/1000 )))
        P+=" | ${t}"; D+="${CLR_SEP} | ${NC}${CLR_TIMER}${t}${NC}"
    fi
    add_row "$P" "$D"
fi

# Gather cached accounts (active account's file was just refreshed above).
ACC_LBL=(); ACC_5P=(); ACC_5R=(); ACC_7P=(); ACC_7R=(); ACC_TS=(); ACC_CLR=()
MAXLBL=0; acc_i=0
if [ -d "$SB_USAGE_DIR" ]; then
    for f in "$SB_USAGE_DIR"/*.json; do
        [ -e "$f" ] || continue
        d=$(cat "$f" 2>/dev/null)
        lbl=$(printf '%s' "$d" | jq -r '.label // empty' 2>/dev/null)
        [ -z "$lbl" ] && continue
        ACC_LBL+=("$lbl")
        ACC_5P+=("$(printf '%s' "$d" | jq -r '.five_hour.pct // 0' 2>/dev/null)")
        ACC_5R+=("$(printf '%s' "$d" | jq -r '.five_hour.resets_at // 0' 2>/dev/null)")
        ACC_7P+=("$(printf '%s' "$d" | jq -r '.seven_day.pct // 0' 2>/dev/null)")
        ACC_7R+=("$(printf '%s' "$d" | jq -r '.seven_day.resets_at // 0' 2>/dev/null)")
        ACC_TS+=("$(printf '%s' "$d" | jq -r '.ts // 0' 2>/dev/null)")
        ACC_CLR+=("${CLR_ACCT[$(( acc_i % 4 ))]}")
        [ ${#lbl} -gt $MAXLBL ] && MAXLBL=${#lbl}
        acc_i=$(( acc_i + 1 ))
    done
fi

# Row: context — aligned so its bar sits under the per-account bars.
if [ -n "$SB_CTXPCT" ]; then
    sb_bar "$SB_CTXPCT" 10; pc=$(sb_thr "$SB_CTXPCT")
    clabel=$(printf '%-*s' "$(( MAXLBL + 7 ))" "Context")
    add_row "${clabel}${_BP} ${SB_CTXPCT}%" \
            "${DIM}${clabel}${NC}${_BC} ${pc}${SB_CTXPCT}%${NC}"
fi

# Row(s): one per account — 5h and 7d bars; active first, marked "> " with reset times.
# ASCII-only (marker, separators, percentages) so column widths are identical across
# rows regardless of how the terminal renders ambiguous-width Unicode glyphs.
sb_render_acct() {  # $1=index into ACC_* arrays
    local k=$1 lbl="${ACC_LBL[$1]}" p5="${ACC_5P[$1]}" r5="${ACC_5R[$1]}"
    local p7="${ACC_7P[$1]}" r7="${ACC_7R[$1]}" ts="${ACC_TS[$1]}" acol="${ACC_CLR[$1]}"
    local mkp lblpad bar5 bc5 bar7 bc7 c5 c7 tail p5f p7f
    if [ "$lbl" = "$SB_ACCT" ]; then mkp="> "; tail="$(sb_durc $(( r5 - SB_NOW )))/$(sb_durc $(( r7 - SB_NOW )))"
    else mkp="  "; tail="$(sb_age $(( SB_NOW - ts ))) ago"; fi
    lblpad=$(printf '%-*s' "$MAXLBL" "$lbl")
    p5f=$(printf '%3d' "${p5:-0}"); p7f=$(printf '%3d' "${p7:-0}")
    sb_bar "$p5" 10; bar5="$_BP"; bc5="$_BC"; c5=$(sb_thr "$p5")
    sb_bar "$p7" 10; bar7="$_BP"; bc7="$_BC"; c7=$(sb_thr "$p7")
    add_row "${mkp}${lblpad}  5h ${bar5} ${p5f}%  7d ${bar7} ${p7f}%  ${tail}" \
            "${MKC}${mkp}${NC}${acol}${lblpad}${NC}  ${DIM}5h${NC} ${bc5} ${c5}${p5f}%${NC}  ${DIM}7d${NC} ${bc7} ${c7}${p7f}%${NC}  ${DIM}${tail}${NC}"
}
for (( k=0; k<${#ACC_LBL[@]}; k++ )); do [ "${ACC_LBL[$k]}" = "$SB_ACCT" ] && sb_render_acct "$k"; done
for (( k=0; k<${#ACC_LBL[@]}; k++ )); do [ "${ACC_LBL[$k]}" != "$SB_ACCT" ] && sb_render_acct "$k"; done

# ─── Output ───────────────────────────────────────────────────────────────────
# Rows = max(buddy art height, left-bar rows); each side blanks past its own length.
# B (Braille Blank) at line start prevents JS .trim() from stripping padding.
NLEFT=${#LEFT_D[@]}
ROWS=$ART_COUNT; [ $NLEFT -gt $ROWS ] && ROWS=$NLEFT
for (( i=0; i<ROWS; i++ )); do
    if [ $i -lt $ART_COUNT ]; then art_part="${ALL_COLORS[$i]}${ALL_LINES[$i]}${NC}"; else art_part=""; fi
    if [ $i -lt $NLEFT ]; then lp="${LEFT_P[$i]}"; ld="${LEFT_D[$i]}"; else lp=""; ld=""; fi
    lplen=${#lp}
    if [ "$lplen" -le "$PAD" ]; then
        leftfield="${ld}$(printf '%*s' "$(( PAD - lplen ))" '')"
    else
        leftfield="${lp:0:$PAD}"   # truncate (drops color) when terminal is narrow
    fi

    if [ $BUBBLE_COUNT -gt 0 ]; then
        bi=$(( i - BUBBLE_START ))
        if [ $bi -ge 0 ] && [ $bi -lt $BUBBLE_COUNT ]; then
            bline="${BUBBLE_LINES[$bi]}"
            btype="${BUBBLE_TYPES[$bi]}"

            if [ $bi -eq $CONNECTOR_BI ]; then
                gap="${C}--${NC} "
            else
                gap="   "
            fi

            if [ "$btype" = "border" ]; then
                echo "${B}${leftfield}${C}${bline}${NC}${gap}${art_part}"
            else
                pipe_l="${bline:0:1}"
                pipe_r="${bline: -1}"
                inner="${bline:1:$(( ${#bline} - 2 ))}"
                echo "${B}${leftfield}${C}${pipe_l}${NC}${DIM}${inner}${NC}${C}${pipe_r}${NC}${gap}${art_part}"
            fi
        else
            empty=$(printf '%*s' "$BOX_W" '')
            echo "${B}${leftfield}${empty}   ${art_part}"
        fi
    else
        echo "${B}${leftfield}${art_part}"
    fi
done

exit 0
