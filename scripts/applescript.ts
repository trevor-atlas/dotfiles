import {$} from 'bun';

// https://github.com/johnlindquist/kit/blob/0de31f203dca2f90ce6f518e9292616a810a1a24/src/api/kit.ts#L495
const app = 'swordfish';
function getTmpPath(...parts: string[]) {
  const home = $`echo ~`.text();
  $`mkdir -p ${home}/${app}`;
  const tmpdir = $`mktemp -d -p ${home}/${app}${parts.join('/')}`.text();

  return scriptTmpDir
}



async function applescript(
  script: string,
  options = { silent: true }
) {
  let applescriptPath = kenvTmpPath("latest.scpt")
  await writeFile(applescriptPath, script)
  Bun.write(file, JSON.stringify(pkg, null, 2));

  let p = new Promise<string>((res, rej) => {
    let stdout = ``
    let stderr = ``
    let child = spawn(
      `/usr/bin/osascript`,
      [applescriptPath],
      options
    )

    child.stdout.on("data", data => {
      stdout += data.toString().trim()
    })
    child.stderr.on("data", data => {
      stderr += data.toString().trim()
    })

    child.on("exit", () => {
      res(stdout)
    })

    child.on("error", () => {
      rej(stderr)
    })
  })

  return p
}
