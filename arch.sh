#!/bin/bash
# install-arch.sh — HP Chromebook 11 Gen 8 EE
# Arch Linux · CWM · Gruvbox Material Dark (hard) · br-thinkpad
set -euo pipefail

###############################################################################
# helpers
###############################################################################
info()  { printf '\e[1;34m:: \e[0m%s\n' "$*"; }
ok()    { printf '\e[1;32m✔ \e[0m%s\n' "$*"; }
warn()  { printf '\e[1;33m⚠ \e[0m%s\n' "$*"; }
die()   { printf '\e[1;31m✘ \e[0m%s\n' "$*" >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || die "rode como root (sudo $0)"; }
need_root

REAL_USER="${SUDO_USER:-${USER}}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

###############################################################################
# 0. base-devel + fakeroot PRIMEIRO (makepkg depende disso)
###############################################################################
info "Instalando base-devel e fakeroot (necessários para AUR)..."
pacman -Sy --noconfirm --needed base-devel fakeroot debugedit
ok "base-devel instalado"

###############################################################################
# 1. atualizar repositórios
###############################################################################
info "Atualizando repositórios pacman..."
pacman -Su --noconfirm
ok "repositórios atualizados"

###############################################################################
# 2. pacotes base do ambiente gráfico (repos oficiais)
###############################################################################
info "Instalando pacotes do ambiente X11..."
BASE_PKGS=(
    # X
    xorg-server xorg-xinit xterm xorg-xsetroot xorg-xrdb
    # fontes
    ttf-iosevka-nerd
    # utilitários X
    xbindkeys
    # backlight (substitui 'light', está nos repos oficiais)
    brightnessctl
    # bateria
    acpi
    # áudio
    pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol
    # apps básicos
    thunar abiword firefox
    # links no terminal
    links
    # lockscreen
    xlockmore
    # dependências de build
    git curl
)
pacman -S --noconfirm --needed "${BASE_PKGS[@]}"
ok "pacotes base instalados"

###############################################################################
# 3. AUR helper (yay)
###############################################################################
if ! command -v yay &>/dev/null; then
    info "Instalando yay (AUR helper)..."
    AUR_TMP=$(mktemp -d)
    chown "$REAL_USER:$REAL_USER" "$AUR_TMP"
    sudo -u "$REAL_USER" git clone https://aur.archlinux.org/yay-bin.git "$AUR_TMP/yay-bin"
    pushd "$AUR_TMP/yay-bin" > /dev/null
    sudo -u "$REAL_USER" makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$AUR_TMP"
    ok "yay instalado"
else
    ok "yay já instalado"
fi

###############################################################################
# 4. pacotes AUR: cwm + xautolock + sct
###############################################################################
info "Instalando pacotes AUR (cwm, xautolock, sct)..."
sudo -u "$REAL_USER" yay -S --noconfirm cwm xautolock sct \
    || warn "falha em algum pacote AUR — verifique manualmente"
ok "pacotes AUR instalados"

###############################################################################
# 5. Wi-Fi — NetworkManager + nmtui
###############################################################################
info "Instalando NetworkManager (nmtui)..."
pacman -S --noconfirm --needed networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager 2>/dev/null || true
ok "NetworkManager instalado e ativado"

###############################################################################
# 7. Layout de teclado — br variant thinkpad
###############################################################################
info "Configurando teclado br variant thinkpad..."
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier   "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "br"
    Option "XkbVariant" "thinkpad"
EndSection
EOF
ok "teclado br/thinkpad configurado"

###############################################################################
# 8. dotfiles — Gruvbox Material Dark (hard)
###############################################################################
info "Escrevendo dotfiles..."

# --- .xsession ---------------------------------------------------------------
# Nota: 'light' substituído por 'brightnessctl' nos keybindings
cat > "$REAL_HOME/.xsession" <<'EOF'
export LANG=en_US.UTF-8
export ENV=$HOME/.bashrc

# teclado
setxkbmap br thinkpad

xrdb -merge $HOME/.Xresources
xsetroot -solid "#1d2021"

# inatividade → trava com xautolock + xlock
xautolock -time 5 -locker 'xlock -mode blank' &
xset b off
sct 3500 &

# barra de status
xterm -name batbar -class batbar -e '~/batbar' &
xbindkeys &

# iniciar pipewire via systemd --user
systemctl --user start pipewire pipewire-pulse wireplumber 2>/dev/null || \
    pipewire &

xterm -geometry 100x1+264+737 &
xterm &
exec cwm
EOF

# --- batbar ------------------------------------------------------------------
cat > "$REAL_HOME/batbar" <<'EOF'
#!/bin/bash
while true; do
    BAT=$(acpi -b 2>/dev/null | sed 's/.*, \([0-9]*\)%.*/\1/' | head -1)
    DAT=$(date +%I:%M%p)
    echo -en " $DAT - ${BAT:-??}% Battery\r"
    sleep 1
done
EOF
chmod +x "$REAL_HOME/batbar"

# --- .Xresources (Gruvbox Material Dark hard) --------------------------------
cat > "$REAL_HOME/.Xresources" <<'EOF'
XTerm*faceName: Iosevka Nerd Font:size=23

XLock.dpmsoff:     1
XLock.description: off
XLock.echokeys:    off
XLock.info:
XLock.background:  #000000
XLock.foreground:  #ffffff
XLock.mode:        blank
XLock.username:    username:
XLock.password:    password:

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Absolute Black Theme
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

*background: #000000
*foreground: #e6e6e6

! cursor
XTerm*cursorColor: #ffffff

! seleção
XTerm*highlightColor: #1a1a1a
XTerm*highlightTextColor: #ffffff

! preto / cinza
*color0:  #000000
*color8:  #4d4d4d

! vermelho
*color1:  #ff4d4d
*color9:  #ff6666

! verde
*color2:  #5cff87
*color10: #7dff9b

! amarelo
*color3:  #ffd75f
*color11: #ffe680

! azul
*color4:  #5fafff
*color12: #87cfff

! magenta
*color5:  #d787ff
*color13: #e6a8ff

! cyan
*color6:  #5fffff
*color14: #87ffff

! branco
*color7:  #d9d9d9
*color15: #ffffff

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! XTerm tweaks
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

XTerm*scrollBar: false
XTerm*rightScrollBar: false
XTerm*saveLines: 5000
XTerm*internalBorder: 8
XTerm*bellIsUrgent: false
XTerm*visualBell: false
XTerm*urgentOnBell: false
XTerm*dynamicColors: true
XTerm*eightBitInput: false
XTerm*metaSendsEscape: true
XTerm*bellVolume: 0
XTerm*utf8: 2
XTerm*locale: true

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! batbar
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

batbar*faceName: Iosevka Nerd Font:style=Bold:size=12
batbar*geometry: 25x1+0+1050
batbar*internalBorder: 6
batbar*saveLines: 0
batbar*scrollBar: false
batbar*title: batbar
batbar*foreground: #ffffff
batbar*background: #000000
EOF

# --- .xbindkeysrc (brightnessctl no lugar de light) --------------------------
cat > "$REAL_HOME/.xbindkeysrc" <<'EOF'
"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
  m:0x0 + c:123
  XF86AudioRaiseVolume

"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
  m:0x0 + c:122
  XF86AudioLowerVolume

"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
  m:0x0 + c:121
  XF86AudioMute

"brightnessctl set 5%+"
  m:0x0 + c:233
  XF86MonBrightnessUp

"brightnessctl set 5%-"
  m:0x0 + c:232
  XF86MonBrightnessDown

"firefox"
  m:0x0 + c:128
  XF86LaunchA

"xterm -e nmtui"
  m:0x0 + c:150
  XF86WLAN

"xterm -e bluetui"
  m:0x0 + c:237
  XF86Bluetooth
EOF

# --- .cwmrc ------------------------------------------------------------------
cat > "$REAL_HOME/.cwmrc" <<'EOF'
sticky yes
snapdist 4
gap 0 31 0 0

unbind-key all

# prefixos: 4=Super  S=Shift  C=Ctrl  M=Alt (reservado para mouse)

bind-key 4-Return        terminal
bind-key C4-l            lock
bind-key 4-BackSpace     window-hide
bind-key 4-Down          window-lower
bind-key 4-Up            window-raise
bind-key 4-Tab           window-cycle
bind-key 4S-Tab          window-rcycle
bind-key 4-w             window-delete
bind-key 4-n             window-menu-label

bind-key 4-a             group-toggle-all
bind-key 4-g             window-group
bind-key 4-Right         group-cycle
bind-key 4-Left          group-rcycle
bind-key 4-s             window-stick
bind-key 4-f             window-fullscreen
bind-key 4-m             window-maximize
bind-key 4-equal         window-vmaximize
bind-key 4S-equal        window-hmaximize

bind-key 4-Left          window-move-left-big
bind-key 4-Down          window-move-down-big
bind-key 4-Up            window-move-up-big
bind-key 4-Right         window-move-right-big

bind-key 4S-Left         window-resize-left
bind-key 4S-Down         window-resize-down
bind-key 4S-Up           window-resize-up
bind-key 4S-Right        window-resize-right

bind-key CS-Up           window-snap-up
bind-key CS-Down         window-snap-down
bind-key CS-Left         window-snap-left
bind-key CS-Right        window-snap-right

bind-key 4-v             window-vtile
bind-key 4-c             window-htile

bind-key 4-comma         menu-window
bind-key 4-d             menu-cmd
bind-key 4-question      menu-exec
bind-key 4-period        menu-ssh
bind-key 4-tab           menu-window

bind-key 4S-r            restart
bind-key 4S-e            quit

unbind-mouse M-1
unbind-mouse CM-1
unbind-mouse M-2
unbind-mouse M-3
unbind-mouse CMS-3

bind-mouse 4-1           window-move
bind-mouse 4-3           window-resize
bind-mouse 4-2           window-lower
bind-mouse 4S-2          window-hide

# menu de comandos (Super+D)
command xterm       xterm
command firefox     firefox
command thunar      thunar
command pavucontrol pavucontrol
command nmtui       "xterm -e nmtui"
command bluetui     "xterm -e bluetui"
command xcalc       xcalc
command xclock      xclock
command abiword     abiword
command links       "xterm -e links www.duckduckgo.com"
command android-studio android-studio

ignore batbar

borderwidth 2
color activeborder   "#D3D3D3"
color inactiveborder "#32302f"
color urgencyborder  "#ea6962"
EOF

chown "$REAL_USER:$REAL_USER" \
    "$REAL_HOME/.xsession" \
    "$REAL_HOME/.Xresources" \
    "$REAL_HOME/.xbindkeysrc" \
    "$REAL_HOME/.cwmrc" \
    "$REAL_HOME/batbar"

ok "dotfiles escritos"

###############################################################################
# 9. permissões de backlight (brightnessctl) para o usuário
###############################################################################
info "Configurando permissões do brightnessctl (backlight)..."
usermod -aG video "$REAL_USER" 2>/dev/null || true
cat > /etc/udev/rules.d/90-backlight.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="backlight", \
  RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", \
  RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
ok "backlight configurado (faça logout/login para aplicar)"

###############################################################################
# 10. grupo bluetooth para o usuário
###############################################################################
usermod -aG bluetooth "$REAL_USER" 2>/dev/null || true
ok "usuário adicionado ao grupo bluetooth"

###############################################################################
# 11. habilitar pipewire via systemd --user no login
###############################################################################
info "Habilitando pipewire no systemd --user..."
sudo -u "$REAL_USER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null \
    || warn "habilite manualmente depois do primeiro login: systemctl --user enable pipewire pipewire-pulse wireplumber"
ok "pipewire habilitado"

###############################################################################
# 12. .xinitrc
###############################################################################
cat > "$REAL_HOME/.xinitrc" <<'EOF'
exec /bin/sh "$HOME/.xsession"
EOF
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.xinitrc"
ok ".xinitrc criado"

###############################################################################
# done
###############################################################################
echo
printf '\e[1;32m╔══════════════════════════════════════════╗\n'
printf '║  instalação concluída!                   ║\n'
printf '║                                          ║\n'
printf '║  para iniciar:  startx                   ║\n'
printf '║  wi-fi:         Super+D → nmtui          ║\n'
printf '║  bluetooth:     Super+D → bluetui        ║\n'
printf '╚══════════════════════════════════════════╝\n\e[0m'
