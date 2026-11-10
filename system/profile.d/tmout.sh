# Text consoles (tty) log out after 10 minutes without a command, so a
# console left open after a lock-screen recovery does not stay logged in.
# SSH and the terminals of the graphical session (pts) are not touched.
# Copied to /etc/profile.d by install.sh, owned by root.
#
# Not exported: greetd starts the graphical session through /etc/profile on
# a tty too, and an exported TMOUT would reach every terminal of the session.
# Set once: a second read of this file in the same shell keeps the value.
case "$(tty 2>/dev/null)" in
  /dev/tty[0-9]*) [ "${TMOUT:-}" = 600 ] || { TMOUT=600; readonly TMOUT; } ;;
esac
