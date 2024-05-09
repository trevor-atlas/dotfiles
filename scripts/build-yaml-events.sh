dir="commerce-billing-ui"
fname="parse-yaml-events.mjs"
fpath="$dir/$fname"
[ -f "$fpath" ] && rm -f "$fpath"
CODE_DIR="$HOME/src"

bun build ~/.config/atlas/scripts/parse-yaml-events.ts --outdir "$CODE_DIR/$dir" --target node &&\
  mv "$dir/parse-yaml-events.js" "$fpath" &&\
  echo -e "/** THIS IS A GENERATED FILE, DO NOT EDIT DIRECTLY */\n/** This regenerates the types from events.yaml for you. Happy to switch this to a proper bend node script if there's a HS approved way to parse yaml */\n/* eslint-disable */\n$(cat commerce-billing-ui/parse-yaml-events.mjs)" > commerce-billing-ui/parse-yaml-events.mjs
