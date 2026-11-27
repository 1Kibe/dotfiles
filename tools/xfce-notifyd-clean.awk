# Git clean filter for xfce4-notifyd.xml.
# xfce4-notifyd adds the name of every program that sends it a notification
# to applications/known_applications, so the file changed whenever something
# new notified. Drop that list on commit; the real preferences (theme,
# position, log, muted programs) stay. xfce4-notifyd rebuilds it on its own.
#
# Enabled by install.sh:
#   git config filter.xfce-notifyd.clean "awk -f tools/xfce-notifyd-clean.awk"

/<property name="known_applications"/ {
  # self-closing, or opened and closed on this line: nothing inside to skip
  if ($0 ~ /\/>[[:space:]]*$/ || $0 ~ /<\/property>/) next
  skipping = 1
  next
}

skipping {
  if ($0 ~ /<\/property>/) skipping = 0
  next
}

{ print }
