# roost demo: deploy on a docker host, then connect from the laptop.
# Run through record.sh, which sets up a throwaway demo box and the
# DEMO_* variables used out of frame below:
#   DEMO_HOST=nas DEMO_DIR=/mnt/user/appdata/roost-demo assets/demo/record.sh

Output assets/demo/roost.gif

Require ssh

Set Shell "bash"
Set FontSize 20
Set Width 1280
Set Height 720
Set Padding 28
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set TypingSpeed 45ms

Hide
Type `ssh() { command ssh -F "$DEMO_SSHCFG" "$@"; }; export PS1='laptop $ '`
Enter
Type `ssh -t nas "cd $DEMO_DIR/roost && export $DEMO_ENV PS1='nas \$ ' && exec bash --norc -i"`
Enter
Sleep 3s
Type "clear"
Enter
Sleep 500ms
Show

# On the docker host
Type "curl -fsSLO https://raw.githubusercontent.com/aronjanosch/roost/main/compose.yml"
Enter
Sleep 1.5s
Type `echo "PUBLIC_KEYS=\"$(cat laptop.pub)\"" > .env`
Enter
Sleep 800ms
Type "docker compose up -d"
Enter
Sleep 4s
Type "docker compose logs -f --no-log-prefix"
Enter
Sleep 9s
Ctrl+C
Sleep 600ms
Type "exit"
Enter
Sleep 1s

# From the laptop
Type "ssh roost"
Enter
Sleep 2.5s
Type "herdr"
Enter
Sleep 3s
# herdr's first-run welcome
Enter
Sleep 4s
Type "claude --version; codex --version; opencode --version"
Enter
Sleep 5s
