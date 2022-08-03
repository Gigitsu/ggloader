# GGLoader

A very minimalistic script to load zsh plugins and themes.

## Installation
```sh
curl -L https://raw.githubusercontent.com/Gigitsu/ggloader/main/ggloader.zsh > ggloader.zsh
```

## Usage

```sh
source /path-to-ggloader/ggloader.zsh

ggl bundle 'zsh-users/zsh-completions'
ggl bundle 'zsh-users/zsh-syntax-highlighting'

ggl theme 'romkatv/powerlevel10k'
```

## Commands
Install (clone and source) a bundle from a github repository.

```sh
ggl bundle <github_user>/<repository>[/<path>] [<script_file_name>] 
```

Install (clone and source) a theme from a github repository.
```sh
ggl theme <github_user>/<repository>[/<path>] [<script_file_name>]
```

Updates every active bundles and themes

```sh
ggl update
```

Install a local bundle, mainly for debug purpose. This will create a symlink pointing to the local bundle into `~/.config/ggl/<github_user>/<repository>[/<path>]`
```sh
ggl install-local <absolute_source_path> <github_user>/<repository>[/<path>]
```

## Limitations

- Only github is supported and local folders are supported
- The update method cannot update a single bundle/theme
- No cache mechanism