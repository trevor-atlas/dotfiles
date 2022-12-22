#!/usr/bin/env -S deno run --allow-run --allow-env --allow-read --allow-net

async function exists(filepath: string) {
    try {
        await Deno.stat(filepath);
        return true;
      } catch(e) { }
      return false
}

const REPO_DIRECTORY = `${Deno.env.get("HOME")}/repos`;

function clone_repo(remote_location: string, repo: string) {
    return Deno.run({
        cmd: ["git", "clone", `${remote_location}/${repo}.git`, `${REPO_DIRECTORY}/${repo}`],
        stdout: "piped",
        stderr: "piped"
    });
}

async function handle_output(repo: string, process: Deno.Process, error?: Error) {
    const { code } = await process.status();
    const rawOutput = await process.output();
    const rawError = await process.stderrOutput();
    if (code === 0) {
        await Deno.stdout.write(rawOutput);
        console.log(`✅ Repository '${repo}' successfully cloned to ${REPO_DIRECTORY}/${repo}`)
    } else {
        const errorString = new TextDecoder().decode(rawError);
        console.log(errorString);
        console.log(`🚨 Repository '${repo}' failed to clone`, error)
    }
}

async function create_if_not_exists(repo: string) {
    if (!repo) {
        console.log(`⚠️ Must specify a valid repository name, received: '${repo}'`)
        return;
    }
    if ((await exists(`${REPO_DIRECTORY}/${repo}`)) === true) {
        console.log(`✅ Repository '${repo}' already exists`)
        return;
    }
    console.log(`⚠️ Cloning repository '${repo}'`)
    try {
        const clone = await clone_repo('git@git.hubteam.com:HubSpot', repo);
        await handle_output(repo, clone);
    } catch (e) {
        const clone = await clone_repo('git@git.hubteam.com:HubSpotProtected', repo);
        await handle_output(repo, clone, e);
    }
}

(() => {
    create_if_not_exists(Deno.args[0])
})()

