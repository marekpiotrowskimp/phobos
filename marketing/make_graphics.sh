#!/usr/bin/env bash
# make_graphics.sh — builds LinkedIn graphics from the App Store screenshots (English, iPhone 6.3").
#   images/linkedin_post_1080x1350.png            feed post (portrait 4:5, best reach in feed)
#   images/linkedin_article_cover_1920x1080.png   article cover (16:9)
#   article/0N_*.png                              images placed inside the article
# Requires ImageMagick 7 (`brew install imagemagick`).
set -euo pipefail
cd "$(dirname "$0")"
SHOTS="../ports/ios/release/screenshots/EN/iphone-6.3"
ICON="../ports/ios/project/assets/ios/app_icon_1024.png"
TITLE_FONT="../ports/ios/project/assets/fonts/Tektur-Variable.ttf"
TEXT_FONT="../ports/ios/project/assets/fonts/Oxanium-Variable.ttf"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BG1="#0B0F16"; BG2="#2A0D10"; FRAME="#1B222C"; CYAN="#4FD6FF"; MUTED="#8A96A3"

# Screenshots used (all English UI):
GAME_A="$SHOTS/IMG_0526.png"   # wave 1, aiming into a swarm
GAME_B="$SHOTS/IMG_0523.png"   # wave 2, low health (red arena)
GAME_C="$SHOTS/IMG_0527.png"   # wave 1, firing across the arena
SCORES="$SHOTS/IMG_0521.png"   # TOP 10 leaderboard

# phone <screenshot> <width> <out>: landscape screenshot in a dark rounded device frame with a glow
phone() {
  local w=$2; local h=$(( w * 1179 / 2556 )); local r=$(( h * 16 / 100 ))
  local b=$(( h * 5 / 100 )); local fw=$(( w + 2*b )); local fh=$(( h + 2*b )); local fr=$(( r + b ))
  magick "$1" -alpha set -resize ${w}x${h}! \( -size ${w}x${h} xc:none -fill white -draw "roundrectangle 0,0,$((w-1)),$((h-1)),$r,$r" \) \
    -compose DstIn -composite "$TMP/screen.png"
  magick -size ${fw}x${fh} xc:none -fill "$FRAME" -draw "roundrectangle 0,0,$((fw-1)),$((fh-1)),$fr,$fr" \
    "$TMP/screen.png" -geometry +$b+$b -compose Over -composite \
    \( +clone -background "$CYAN" -shadow 22x$(( w / 40 ))+0+0 \) +swap -background none -layers merge +repage "$3"
}

icon() { # icon <size> <out>
  local s=$1; local r=$(( s * 22 / 100 ))
  magick "$ICON" -alpha set -resize ${s}x${s} \( -size ${s}x${s} xc:none -fill white -draw "roundrectangle 0,0,$((s-1)),$((s-1)),$r,$r" \) \
    -compose DstIn -composite "$2"
}

background() { # background <WxH> <out>
  magick -size "$1" radial-gradient:"$BG2"-"$BG1" "$2"
}

mkdir -p images article

# ---------- Feed post 1080x1350 ----------
phone "$GAME_A" 900 "$TMP/p1.png"
phone "$GAME_B" 660 "$TMP/p2.png"
icon 120 "$TMP/icon_s.png"
background 1080x1350 "$TMP/bg_post.png"
magick "$TMP/bg_post.png" \
  "$TMP/icon_s.png" -gravity north -geometry +0+60 -composite \
  -font "$TITLE_FONT" -fill "$CYAN" -pointsize 104 -gravity north -annotate +0+190 "PHOBOS" \
  -font "$TEXT_FONT" -fill white -pointsize 44 -gravity north -annotate +0+315 "SURVIVOR" \
  "$TMP/p1.png" -gravity north -geometry +0+400 -composite \
  "$TMP/p2.png" -gravity north -geometry +0+850 -composite \
  -font "$TEXT_FONT" -fill "$MUTED" -pointsize 34 -gravity south -annotate +0+50 "Twin-stick survival shooter  •  iPhone & iPad" \
  images/linkedin_post_1080x1350.png

# ---------- Article cover 1920x1080 ----------
phone "$GAME_A" 860 "$TMP/c1.png"
icon 150 "$TMP/icon_c.png"
background 1920x1080 "$TMP/bg_cover.png"
magick "$TMP/bg_cover.png" \
  "$TMP/icon_c.png" -gravity northwest -geometry +120+300 -composite \
  -font "$TITLE_FONT" -fill "$CYAN" -pointsize 150 -gravity northwest -annotate +110+470 "PHOBOS" \
  -font "$TEXT_FONT" -fill white -pointsize 62 -gravity northwest -annotate +118+650 "SURVIVOR" \
  -font "$TEXT_FONT" -fill "$MUTED" -pointsize 36 -gravity northwest -annotate +120+750 "Twin-stick survival shooter for iPhone & iPad" \
  "$TMP/c1.png" -gravity east -geometry +80+0 -composite \
  images/linkedin_article_cover_1920x1080.png

# ---------- Article package ----------
cp images/linkedin_article_cover_1920x1080.png article/00_cover.png
n=1
for pair in "$GAME_A:gameplay" "$GAME_C:aiming" "$SCORES:scores"; do
  phone "${pair%%:*}" 1300 "$TMP/a.png"
  background 1600x1000 "$TMP/bg_a.png"
  magick "$TMP/bg_a.png" "$TMP/a.png" -gravity center -composite "article/0${n}_${pair##*:}.png"
  n=$((n + 1))
done

echo "Done: $(pwd)/images, $(pwd)/article"
