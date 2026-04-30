# SPDX-License-Identifier: GPL-3.0-or-later
%post --erroronfail --log=/tmp/anacoda_custom_logs/disable-fedora-flatpak.log
systemctl disable flatpak-add-fedora-repos.service || :
%end
