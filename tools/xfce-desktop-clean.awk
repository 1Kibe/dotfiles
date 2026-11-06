# Git clean filter for xfce4-desktop.xml.
# xfdesktop saves the wallpaper per monitor under backdrop/screen0, with the
# monitor's connector name (eDP-1, Virtual-1...) and the full image path
# (/home/<user>/...). Neither belongs in the repo: the wallpaper is set at
# login by ~/.local/bin/xfce-wallpaper. Drop the whole screen0 block on commit.
#
# Enabled by install.sh:
#   git config filter.xfce-desktop.clean "awk -f tools/xfce-desktop-clean.awk"

skipping {
  # nested <property ...> that is not self-closing opens one more level
  if ($0 ~ /<property [^>]*[^\/]>[[:space:]]*$/) depth++
  if ($0 ~ /<\/property>/) depth--
  if (depth == 0) skipping = 0
  next
}

/<property name="screen0"/ {
  # self-closing property: nothing inside to skip
  if ($0 ~ /\/>[[:space:]]*$/) next
  skipping = 1
  depth = 1
  next
}

{ print }
