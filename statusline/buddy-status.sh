#!/usr/bin/env bash
# claude-buddy status line — animated, right-aligned multi-line companion
# Uses Braille Blank (U+2800) for padding — survives JS .trim()

# UTF-8 char handling so ${#str} counts display columns (block glyphs = 1 col),
# keeping the right-alignment width math exact. LC_CTYPE only — not LC_ALL — so
# subprocess collation/messages are untouched; no-op if already UTF-8.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8|*[Uu][Tt][Ff]8) ;;
    *) unset LC_ALL
       if locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then export LC_CTYPE=en_US.UTF-8
       else export LC_CTYPE=C.UTF-8; fi ;;
esac

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

INPUT=""
[ -t 0 ] || INPUT=$(cat)  # Claude Code status JSON on stdin (skip when run by hand)

# ─── Status bar inputs (all optional; missing fields collapse cleanly) ────────
# One jq call extracts every field, one per line ("" when missing). Fields used
# in bash arithmetic are floored to integers ("" if non-numeric) so $(( )) never
# sees floats like used_percentage 61.4.
SBF=()
if [ -n "$INPUT" ]; then
    while IFS= read -r _f; do SBF+=("$_f"); done < <(printf '%s' "$INPUT" | jq -r '
        def num: if type == "number" then floor else "" end;
        (.model.display_name // ""),
        (.effort.level // ""),
        (.thinking.enabled == true | tostring),
        (.fast_mode == true | tostring),
        (.workspace.current_dir // .cwd // ""),
        (.context_window.context_window_size | num),
        (.context_window.used_percentage | num),
        (.cost.total_duration_ms | num),
        (.rate_limits.five_hour.used_percentage | num),
        (.rate_limits.five_hour.resets_at | num),
        (.rate_limits.seven_day.used_percentage | num),
        (.rate_limits.seven_day.resets_at | num)
    ' 2>/dev/null)
fi
SB_MODEL="${SBF[0]:-}";  SB_EFFORT="${SBF[1]:-}";  SB_THINKON="${SBF[2]:-}"
SB_FAST="${SBF[3]:-}";   SB_CWD="${SBF[4]:-}";     SB_WINSIZE="${SBF[5]:-}"
SB_CTXPCT="${SBF[6]:-}"; SB_DURMS="${SBF[7]:-}";   SB_5HPCT="${SBF[8]:-}"
SB_5HRST="${SBF[9]:-}";  SB_7DPCT="${SBF[10]:-}";  SB_7DRST="${SBF[11]:-}"
# Account email from CLAUDE_CONFIG_DIR (e.g. ~/.claude-work), fallback ~/.claude.json
SB_CFGDIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SB_EMAIL=$(jq -r '.oauthAccount.emailAddress // empty' "$SB_CFGDIR/.claude.json" 2>/dev/null)
[ -z "$SB_EMAIL" ] && SB_EMAIL=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
SB_BRANCH=""; SB_DIRTY=""; SB_AHEAD=0; SB_BEHIND=0
if [ -n "$SB_CWD" ]; then
    SB_BRANCH=$(git -C "$SB_CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$SB_BRANCH" ]; then
        # "*" when tracked files are modified/staged (untracked files don't count)
        [ -n "$(git -C "$SB_CWD" status --porcelain --untracked-files=no 2>/dev/null)" ] && SB_DIRTY="*"
        # ahead/behind upstream: rev-list --left-right --count prints "behind<TAB>ahead"
        ab=$(git -C "$SB_CWD" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
        if [ -n "$ab" ]; then
            SB_BEHIND=$(printf '%s' "$ab" | awk '{print $1+0}')
            SB_AHEAD=$(printf '%s' "$ab" | awk '{print $2+0}')
        fi
    fi
fi

SB_NOW=$(date +%s)

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

# Reaction isolation: with a known TTY, show only this terminal's own session
# reaction — never another session's via the global file. Without a TTY, fall
# back to the global reaction only while fresh (< 10 min), so a resolution
# failure degrades to a quiet buddy instead of someone else's words.
if [ -n "$TTY" ] && [ "$TTY" != "??" ] && [ "$TTY" != "-" ]; then
  SESSION_REACTION=""
  SID=$(cat "$HOME/.claude-buddy/tty-sessions/$TTY" 2>/dev/null)
  [ -n "$SID" ] && SESSION_REACTION=$(jq -r '.reaction // ""' "$HOME/.claude-buddy/sessions/${SID}.json" 2>/dev/null)
  REACTION="$SESSION_REACTION"
else
  RAT=$(jq -r '(.reactionAt // 0) / 1000 | floor' "$STATE" 2>/dev/null)
  [ $(( SB_NOW - ${RAT:-0} )) -gt 600 ] && REACTION=""
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

# ─── Left status bar (stacked: identity / workspace / context+usage) ──────────
# Palette (truecolor). Block glyphs are 1 display column each; LC_CTYPE keeps ${#} honest.
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
sb_cap() {  # capitalize first letter
    printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}
LEFT_P=(); LEFT_D=()  # one entry per left row: plain (for width) / colored (for display)
add_row() { LEFT_P+=("$1"); LEFT_D+=("$2"); }

# Width-aware rows: collect segments, then emit as many (left-to-right) as fit the
# budget so narrow terminals drop trailing segments cleanly instead of overlapping
# the speech bubble. ROWBUDGET leaves a 2-col gap before the bubble.
ROWBUDGET=$(( PAD - 2 )); [ "$ROWBUDGET" -lt 1 ] && ROWBUDGET=1
SEG_P=(); SEG_D=()
sb_seg() { [ -z "$1" ] && return; SEG_P+=("$1"); SEG_D+=("$2"); }
sb_emit() {  # assemble collected segments within ROWBUDGET, then reset
    local i P="" D="" sp sd
    for (( i=0; i<${#SEG_P[@]}; i++ )); do
        sp="${SEG_P[$i]}"; sd="${SEG_D[$i]}"
        if [ -z "$P" ]; then
            if [ ${#sp} -gt "$ROWBUDGET" ]; then P="${sp:0:$ROWBUDGET}"; D="${sp:0:$ROWBUDGET}"
            else P="$sp"; D="$sd"; fi
        elif [ $(( ${#P} + 3 + ${#sp} )) -le "$ROWBUDGET" ]; then
            P="$P | $sp"; D="${D}${CLR_SEP} | ${NC}${sd}"
        else
            break
        fi
    done
    [ -n "$P" ] && add_row "$P" "$D"
    SEG_P=(); SEG_D=()
}

WINLBL=""
if [ -n "$SB_WINSIZE" ]; then
    if [ "$SB_WINSIZE" -ge 1000000 ] 2>/dev/null; then WINLBL=" (1M context)"
    elif [ "$SB_WINSIZE" -ge 1000 ] 2>/dev/null; then WINLBL=" ($(( SB_WINSIZE/1000 ))K context)"; fi
fi

# Row: identity — model (window) | effort | email. Trailing segments drop first
# when the terminal is too narrow (email, then effort).
if [ -n "$SB_MODEL" ]; then
    sb_seg "${SB_MODEL}${WINLBL}" "${CLR_MODEL}${SB_MODEL}${NC}${DIM}${WINLBL}${NC}"
fi
if [ "$SB_THINKON" = "true" ] && [ -n "$SB_EFFORT" ]; then
    e=$(sb_cap "$SB_EFFORT"); sb_seg "$e" "${CLR_THINK}${e}${NC}"
fi
[ "$SB_FAST" = "true" ] && sb_seg "Fast" "${CLR_FAST}Fast${NC}"
[ -n "$SB_EMAIL" ] && sb_seg "$SB_EMAIL" "${DIM}${SB_EMAIL}${NC}"
sb_emit

# Row: workspace — dir:branch (dirty + ahead/behind) | timer. Timer drops first when narrow.
if [ -n "$SB_CWD" ]; then
    dn=$(basename "$SB_CWD")
    if [ -n "$SB_BRANCH" ]; then
        bp="${dn}:${SB_BRANCH}${SB_DIRTY}"
        bd="${CLR_DIR}${dn}${NC}${DIM}:${NC}${CLR_BRANCH}${SB_BRANCH}${NC}${CLR_YEL}${SB_DIRTY}${NC}"
        ab=""; abc=""
        [ "$SB_AHEAD" -gt 0 ] 2>/dev/null && { ab="+${SB_AHEAD}"; abc="${CLR_GREEN}+${SB_AHEAD}${NC}"; }
        [ "$SB_BEHIND" -gt 0 ] 2>/dev/null && { ab="${ab:+$ab/}-${SB_BEHIND}"; abc="${abc:+$abc${DIM}/${NC}}${CLR_RED}-${SB_BEHIND}${NC}"; }
        [ -n "$ab" ] && { bp="$bp $ab"; bd="$bd $abc"; }
        sb_seg "$bp" "$bd"
    else
        sb_seg "$dn" "${CLR_DIR}${dn}${NC}"
    fi
    [ -n "$SB_DURMS" ] && { t=$(sb_dur $(( SB_DURMS/1000 ))); sb_seg "$t" "${CLR_TIMER}${t}${NC}"; }
    sb_emit
fi

# Row: context + this account's 5h / 7d usage on one line; each window's reset
# countdown sits right behind its bar. 7d drops first when narrow, then 5h.
if [ -n "$SB_CTXPCT" ]; then
    sb_bar "$SB_CTXPCT" 8; cc=$(sb_thr "$SB_CTXPCT")
    sb_seg "Context ${_BP} ${SB_CTXPCT}%" \
           "${DIM}Context${NC} ${_BC} ${cc}${SB_CTXPCT}%${NC}"
fi
if [ -n "$SB_5HPCT" ]; then
    r5="$(sb_durc $(( ${SB_5HRST:-0} - SB_NOW )))"
    sb_bar "$SB_5HPCT" 8; c5=$(sb_thr "$SB_5HPCT")
    sb_seg "5h ${_BP} ${SB_5HPCT}% ${r5}" \
           "${DIM}5h${NC} ${_BC} ${c5}${SB_5HPCT}%${NC} ${DIM}${r5}${NC}"
fi
if [ -n "$SB_7DPCT" ]; then
    r7="$(sb_durc $(( ${SB_7DRST:-0} - SB_NOW )))"
    sb_bar "$SB_7DPCT" 8; c7=$(sb_thr "$SB_7DPCT")
    sb_seg "7d ${_BP} ${SB_7DPCT}% ${r7}" \
           "${DIM}7d${NC} ${_BC} ${c7}${SB_7DPCT}%${NC} ${DIM}${r7}${NC}"
fi
sb_emit

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
