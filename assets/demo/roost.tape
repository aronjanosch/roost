# roost demo, laptop side: into the box, then straight into the running
# agents in herdr. The phone part (close the laptop, open herdr on the phone,
# same sessions) is filmed separately.
#
# Needs an ssh alias `roost` that works without a prompt, and a herdr in the
# box that is past its first-run welcome (start it once by hand). Everything
# on screen is public in the GIF: record with a demo workspace, not your real
# projects. Record with:
#   mise exec vhs@latest ttyd@latest -- vhs assets/demo/roost.tape

Output assets/demo/roost.gif

Require ssh

Set Shell "bash"
Set FontSize 20
Set Width 1280
Set Height 720
Set Padding 28
Set Theme "Catppuccin Mocha"
Set WindowBar Colorful
Set TypingSpeed 55ms

Hide
Type "export PS1='laptop $ ' && clear"
Enter
Show

Sleep 600ms
Type "ssh roost"
Sleep 400ms
Enter
Sleep 2s

Type "herdr"
Sleep 300ms
Enter
Sleep 7s
