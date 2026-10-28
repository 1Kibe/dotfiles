# Git clean filter for xfce4-panel.xml.
# XFCE writes the systray "known-legacy-items" cache into this file at runtime,
# and that cache holds Wi-Fi network names (SSIDs). Drop the whole block on commit;
# XFCE rebuilds it on its own.
#
# Enabled by install.sh:
#   git config filter.xfce-panel.clean "awk -f tools/xfce-panel-clean.awk"

/name="known-legacy-items"/ {
  # self-closing property: nothing inside to skip
  if ($0 ~ /\/>[[:space:]]*$/) next
  skipping = 1
  next
}

skipping {
  if ($0 ~ /<\/property>/) skipping = 0
  next
}

{ print }
