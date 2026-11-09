# Git clean filter for thunar.xml.
# Thunar saves the size of its last window and whether it was maximized, so
# the file changed every time a window was resized. Drop those three lines on
# commit; the real preferences (view, zoom, hidden files, sidebar) stay.
#
# Enabled by install.sh:
#   git config filter.xfce-thunar.clean "awk -f tools/xfce-thunar-clean.awk"

/<property name="last-window-(width|height|maximized)"/ { next }

{ print }
