import os
import shutil
import platform
import json
from pathlib import Path

mkpath = os.path.join

home = os.path.join(str(Path.home()), '')
xdg_home = os.environ.get('XDG_CONFIG_HOME')
if not xdg_home or xdg_home == "":
	xdg_home = os.path.join(home, '.config')
atlas_home = os.path.join(os.environ.get('ATLAS_ROOT'), '')
settings_src = mkpath(atlas_home, "settings")


def determine_os():
	return platform.system()


def is_windows():
	return determine_os() == 'Windows'


def is_darwin():
	return determine_os() == 'Darwin'


def is_linux():
	return determine_os() == 'Linux'


def is_unix():
	return is_linux() or is_darwin()


def is_symlink(src: str):
	return Path(src).is_symlink()


def is_file(src: str):
	return Path(src).exists()


def is_dir(src: str):
	return os.path.isdir(src)


def link_file(src: str, dest: str):
	try:
		os.symlink(src, dest)
	except OSError:
		print("Creation of the symlink from %s to %s failed", src, dest)
	else:
		print("Successfully created a symlink from %s to %s ", src, dest)


def copy_file(src: str, dest: str):
	try:
		shutil.copyfile(src, dest)
	except OSError:
		print("Copying from %s to %s failed", src, dest)
	else:
		print("Successfully copied from %s to %s ", src, dest)


def mkdir(path: str):
	try:
		os.mkdir(path)
	except OSError:
		print("Creation of the directory %s failed" % path)
	else:
		print("Successfully created the directory %s " % path)


def mkdirs(dirs):
	for d in dirs:
		if not is_dir(d):
			mkdir(d)


def mklinks(links):
	for l in links:
		print("link is: " + json.dumps(l, indent=4))
		fname = l['src']
		fsrc = mkpath(settings_src, fname)
		fdest = mkpath(l['dest'], fname)
		if is_file(fsrc) and not is_symlink(mkpath(l['dest'], fname)) and not is_file(fdest):
			link_file(fsrc, fdest)
			if 'cmd' in l:
				os.system(l['cmd'])


def install_dotfiles():
	dirs_to_create = [
		mkpath(xdg_home, "nvim"),
		mkpath(xdg_home, "alacritty"),
		mkpath(home, ".tmux"),
		mkpath(home, 'projects')
	]
	links_to_create = [
		{'src': ".gitconfig", 'dest': home},
		{'src': ".gitignore_global", 'dest': home},
		{'src': ".vimrc", 'dest': home},
		{'src': ".tmux.conf", 'dest': home,
		 'cmd': "git clone https://github.com/tmux-plugins/tpm " + home + "/.tmux/plugins/tpm"},
		{'src': "alacritty.yml", 'dest': mkpath(xdg_home, "alacritty")}
	]

	mkdirs(dirs_to_create)
	mklinks(links_to_create)
