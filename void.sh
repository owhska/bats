#!/bin/bash
# install.sh — HP Chromebook 11 Gen 8 EE
# Void Linux (glibc) · CWM · Gruvbox Material Dark (hard) · br-thinkpad
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
# 0. atualizar repositórios
###############################################################################
info "Atualizando repositórios xbps..."
xbps-install -Syu --yes 2>/dev/null || true
ok "repositórios atualizados"

###############################################################################
# 1. pacotes base do ambiente gráfico
###############################################################################
info "Instalando pacotes do ambiente X11..."
BASE_PKGS=(
    # X
    xorg-minimal xinit xterm xsetroot xrdb
    # WM
    cwm
    # fontes
    font-iosevka font-roboto-nerd
    # utilitários X
    xbindkeys xidle xlock
    # temperatura de cor
    sct
    # bateria / backlight
    acpi brillo
    # áudio
    pipewire wireplumber alsa-utils pavucontrol
    # apps básicos do menu cwm
    thunar abiword firefox
    # links no terminal
    links
)
xbps-install -y "${BASE_PKGS[@]}" || warn "alguns pacotes podem não ter sido encontrados — continue"
ok "pacotes base instalados"

###############################################################################
# 2. Wi-Fi — NetworkManager + nmtui
###############################################################################
info "Instalando NetworkManager (nmtui)..."
xbps-install -y NetworkManager
# habilitar serviço runit
ln -sf /etc/sv/NetworkManager /var/service/ 2>/dev/null || true
ok "NetworkManager instalado e ativado"

###############################################################################
# 3. Bluetooth — daemon + bluetui
###############################################################################
info "Instalando Bluetooth..."
xbps-install -y bluez

# bluetui: binário pré-compilado do GitHub (escrito em Rust)
BLUETUI_VERSION="0.3.2"
BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/v${BLUETUI_VERSION}/bluetui-x86_64-unknown-linux-gnu.tar.gz"
BLUETUI_TMP=$(mktemp -d)

info "Baixando bluetui v${BLUETUI_VERSION}..."
if curl -fsSL "$BLUETUI_URL" -o "$BLUETUI_TMP/bluetui.tar.gz"; then
    tar -xzf "$BLUETUI_TMP/bluetui.tar.gz" -C "$BLUETUI_TMP"
    install -m755 "$BLUETUI_TMP/bluetui" /usr/local/bin/bluetui
    ok "bluetui instalado em /usr/local/bin/bluetui"
else
    warn "falha ao baixar bluetui — instale manualmente depois"
    warn "  curl -fsSL $BLUETUI_URL | tar -xz && install bluetui /usr/local/bin/"
fi
rm -rf "$BLUETUI_TMP"

ln -sf /etc/sv/bluetoothd /var/service/ 2>/dev/null || true
ok "bluetoothd ativado"

###############################################################################
# 4. Layout de teclado — br variant thinkpad
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
# também setxkbmap no .xsession (feito na seção 6)
ok "teclado br/thinkpad configurado"

###############################################################################
# 5. dotfiles — gerar com Gruvbox Material Dark (hard)
###############################################################################
info "Escrevendo dotfiles..."

# --- .xsession ---------------------------------------------------------------
cat > "$REAL_HOME/.xsession" <<'EOF'
export LANG=en_US.UTF-8
export ENV=$HOME/.bashrc

# teclado
setxkbmap br thinkpad

xrdb -merge $HOME/.Xresources
xsetroot -solid "#1d2021"

xidle &
xset b off
sct 3500 &

# barra de status
exec xterm -name batbar -class batbar -e '~/batbar' &
xbindkeys &
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
XTerm*faceName: Iosevka:size=12

XIdle*timeout: 300

XLock.dpmsoff:     1
XLock.description: off
XLock.echokeys:    off
XLock.info:
XLock.background:  black
XLock.foreground:  white
XLock.mode:        blank
XLock.username:    username:
XLock.password:    password:

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Gruvbox Material Dark — hard
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

*background: #1d2021
*foreground: #d4be98

! Black + DarkGrey
*color0:  #1d2021
*color8:  #32302f

! DarkRed + Red
*color1:  #ea6962
*color9:  #ea6962

! DarkGreen + Green
*color2:  #a9b665
*color10: #a9b665

! DarkYellow + Yellow
*color3:  #d8a657
*color11: #d8a657

! DarkBlue + Blue
*color4:  #7daea3
*color12: #7daea3

! DarkMagenta + Magenta
*color5:  #d3869b
*color13: #d3869b

! DarkCyan + Cyan
*color6:  #89b482
*color14: #89b482

! LightGrey + White
*color7:  #d4be98
*color15: #ddc7a1

! batbar — barra de status
batbar*faceName:     RobotoMono NF:style=Bold:size=12
batbar*geometry:     25x1+0+737
batbar*internalBorder: 6
batbar*saveLines:    0
batbar*scrollBar:    false
batbar*title:        batbar
batbar*foreground:   #d4be98
batbar*background:   #32302f
EOF

# --- .xbindkeysrc ------------------------------------------------------------
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

"brillo -A 5"
  m:0x0 + c:233
  XF86MonBrightnessUp

"brillo -U 5"
  m:0x0 + c:232
  XF86MonBrightnessDown

"firefox"
  m:0x0 + c:128
  XF86LaunchA

"nmtui"
  m:0x0 + c:150
  XF86WLAN

"bluetui"
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

bind-key 4-slash         menu-window
bind-key 4-d             menu-cmd
bind-key 4-question      menu-exec
bind-key 4-period        menu-ssh

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

ignore batbar

# Aparência — bordas combinando com Gruvbox Material Dark
borderwidth 4
color activeborder   "#d4be98"
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
# 6. permissões de brillo para o usuário
###############################################################################
info "Configurando permissões do brillo..."
usermod -aG video "$REAL_USER" 2>/dev/null || true
# udev rule
cat > /etc/udev/rules.d/90-brillo.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
EOF
ok "brillo configurado (faça logout/login para aplicar)"

###############################################################################
# 7. grupo bluetooth para o usuário
###############################################################################
usermod -aG bluetooth "$REAL_USER" 2>/dev/null || true
ok "usuário adicionado ao grupo bluetooth"

###############################################################################
# 8. .xinitrc para xinit
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
