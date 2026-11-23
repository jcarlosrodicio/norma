# The demo in the README and on the site: the hook refusing a commit the gate
# never saw, then accepting it once the gate has run. Real output, no mock.
#
# Regenerate from the repository root with vhs (brew install vhs):
#   vhs site/demo.tape

Output site/demo.gif

Set Shell "bash"
Set FontFamily "Menlo"
Set FontSize 19
Set Width 1200
Set Height 680
Set Padding 28
Set LineHeight 1.25
Set TypingSpeed 35ms
Set Theme { "name": "norma", "background": "#1c1a17", "foreground": "#e9e4da", "cursor": "#e9e4da", "selection": "#3a362f", "black": "#1c1a17", "red": "#ff6b4a", "green": "#9ccf8a", "yellow": "#e8c26a", "blue": "#8fb4d8", "magenta": "#d49bc4", "cyan": "#86c7c0", "white": "#e9e4da", "brightBlack": "#8a8378", "brightRed": "#ff8a6e", "brightGreen": "#b5e0a5", "brightYellow": "#f0d48e", "brightBlue": "#aac8e6", "brightMagenta": "#e2b5d6", "brightCyan": "#a3d8d2", "brightWhite": "#f6f2ea" }

Hide
Type@1ms "export NORMA=$PWD/bin/norma D=$(mktemp -d) && cd $D && git init -q -b main && git -c user.name=demo -c user.email=demo@example.com commit -q --allow-empty -m init && git switch -q -c add-greeting && $NORMA install --profile node >/dev/null" Enter
Type@1ms `printf '%s\n' 'HARNESS_CODE_PATHS="src test"' 'harness_gates() { echo "harness: static gates"; run sh -n test/run.sh; }' 'harness_test_selected() { run sh test/run.sh; }' 'harness_test_all() { run sh test/run.sh; }' > scripts/harness/config.sh` Enter
Type@1ms `mkdir -p src test && printf '%s\n' 'for f in src/*.js; do [ -s "$f" ] || exit 1; done' 'echo "3 tests passed"' > test/run.sh && echo 'export const add = (a, b) => a + b' > src/add.js` Enter
Type@1ms "git config user.name demo && git config user.email demo@example.com && scripts/harness/verify greet >/dev/null 2>&1 && git add -A && git commit -qm 'chore: install norma' && export PS1='$ ' && clear" Enter
Wait+Line@20s /^\$\s*$/
Sleep 300ms
Show

Sleep 600ms
Type "echo 'export const greet = (n) => `Hello, ${n}`' > src/greet.js"
Sleep 300ms
Enter
Sleep 400ms
Type `git add src && git commit -m "feat: greet"`
Sleep 300ms
Enter
Sleep 3.5s
Type "scripts/harness/verify greet"
Sleep 300ms
Enter
Sleep 2.5s
Type `git commit -m "feat: greet"`
Sleep 300ms
Enter
Sleep 4s
