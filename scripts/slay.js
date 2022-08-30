#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title slay
// @raycast.mode compact

// Optional parameters:
// @raycast.icon 🤖
// @raycast.argument1 { "type": "text", "placeholder": "Placeholder" }

console.log("Hello World! Argument1 value: " + process.argv.slice(2)[0])

const util = require('util');
const exec = util.promisify(require('child_process').exec);
const plist = require('plist');
const { readFile } = require('fs/promises')

const getIcon = name => `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/${name}.icns`;
async function content(path) {  
	return await readFile(path, 'utf8')
}
  

const icons = {
	get: getIcon,
	info: getIcon('ToolbarInfo'),
	warning: getIcon('AlertCautionIcon'),
	error: getIcon('AlertStopIcon'),
	alert: getIcon('Actions'),
	like: getIcon('ToolbarFavoritesIcon'),
	delete: getIcon('ToolbarDeleteIcon'),
};

const iconPaths = new Map();

async function getAppIconPath(appPath) {
	if (iconPaths.get(appPath)) {
		return iconPaths.get(appPath);
	}
	const contents = await content(`${appPath}/Contents/Info.plist`);
	const manifest = plist.parse(contents);
	let iconFile = (manifest.CFBundleIconFile || manifest.CFBundleIconName);
	if (!iconFile) return icons.info;

	// have to do this because some manifests don't include the file extension 
	if (iconFile.indexOf('.') !== -1) {
		iconFile = iconFile.split('.')[0];
	}

	const iconPath = `${appPath}/Contents/Resources/${iconFile}.icns`;
	iconPaths.set(appPath, iconPath);
	return iconPath;
}

async function getApplicationInfo(path) {
	const split_path = path.split('/').filter(segment => segment);

	// if path contains `.app` > 1 time, it's a helper process
	const apps = split_path.filter(entry => entry.indexOf('.app') > -1)

	// users apps
	if (split_path[0] === 'Applications') {
		const appPath = path.slice(0, path.indexOf('.app') + 4);
		const iconPath = await getAppIconPath(appPath);

		if (apps.length > 1) {
			return {
				name: apps.pop(),
				appPath: apps.length > 1 ? path : appPath,
				iconPath,
				type: 'service'
			}
		}
		return {
			name: apps.pop(),
			appPath: apps.length > 1 ? path : appPath,
			iconPath,
			type: 'application'
		}
	}
	// system apps
	if (split_path[0] === 'System') {
		const appPath = path.slice(0, path.indexOf('.app') + 4);
		const iconPath = await getAppIconPath(appPath);
		if (split_path[1] === 'Library') {
			return {
				name: apps.pop(),
				appPath: apps.length > 1 ? path : appPath,
				iconPath,
				type: 'service'
			}

		}
		return {
			name: apps.pop(),
			appPath: apps.length > 1 ? path : appPath,
			iconPath,
			type: 'application'
		}
	}

	return {
		name: path.trim().split(' ')[0],
		appPath: path,
		iconPath: icons.info,
		type: 'executable'
	}
}

(async () => {
  const processName = process.argv.slice(2)[0];
  const { stdout } = await exec(`ps -A -o pid -o %cpu -o args -U $(whoami) | grep -i ${processName}`);
    const results = [];
    const lines = stdout.split('\n');
    for (const line of lines) {
      const matches = Array.from(line.matchAll(/(\d+)\s+(\d+[\.|\,]\d+)\s+(.*)/igm));
      if (!matches || !Array.isArray(matches) || !matches[0] || matches[0].length < 4) { continue; }
      const [_, id, cpu_percent, path] = matches[0];
	  const info = await getApplicationInfo(path);
	  if (!info) continue;

      results.push({
        uid: id,
        title: info.name || processName,
        subtitle: `${cpu_percent}% CPU @ ${info.appPath}`,
        text: {
          copy: line
        },
        arg: id,
        icon: {
          path: info.iconPath
        },
		type: info.type
      });
    }

	const sorted = results.sort((a, b) => {
		if (a.type === b.type) return 0;
		if (a.type === 'application') return -1;
		if (b.type === 'application') return 1;
		if (a.type === 'service') return 1;
		if (b.type === 'service') return 1;
		if (a.type === 'executable') return 1;
		if (b.type === 'executable') return 1;

});
  console.log(JSON.stringify({ items: sorted  }, null, '\t'));
})()

// 2407   0.0 /Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper --ms-enable-electron-run-as-node --inspect-port=0 /Applications/Visual Studio Code.app/Contents/Resources/app/out/bootstrap-fork --type=extensionHost --skipWorkspaceStorageLock
// 11754   0.0 /Applications/Spotify.app/Contents/MacOS/Spotify
// 37046   0.0 tmux -u new-session -t Bool -d
//
	// application icons live in folders like:
// /Applications/Spotify.app/Contents/MacOS/Resources/Icon.icns
// or /Applications/Slack.app/Contents/Resources/electron.icns
