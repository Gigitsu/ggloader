###################################
##           GG Loader           ##
###################################

# Useful links
# - ZSH manual (https://zsh.sourceforge.io/Doc/Release/index.html#Top)
# - Variable modifiers (https://zsh.sourceforge.io/Doc/Release/Expansion.html#Modifiers)
# - Git shallow clone and update (https://stackoverflow.com/questions/41075972/how-to-update-a-git-shallow-clone)

# Do not load anything if git is not available.
if (( ! $+commands[git] )); then
    echo 'GGLoader: Please install git to use GGLoader.' >&2
    return 1
fi

typeset -A GGL_REPOS

# Helper function: Same as `$1=$2`, but will only happen if the name
# specified by `$1` is not already set.
_ggl_set_default () {
  local arg_name="$1"
  local arg_value="$2"
  eval "test -z \"\$$arg_name\" && typeset -g $arg_name='$arg_value'"
}

_ggl_set_default GGL_LOG /dev/null

_ggl_set_default GGL_HOME "$HOME/.config/ggl"

_ggl_git_current_branch() {
	git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'
}

# Usage:
#   _ggl_ensure_repo output_assoc_arr <args...>
# TODO:
# - try to download only the minimum instead of the whole repository
_ggl_ensure_repo() {
  local repo_name full_local_path plugin_name args
  local start took

  local var=$1
  shift

  plugin_name=${1:l}
  repo_name=${plugin_name:h2}
  full_local_path="$GGL_HOME/$plugin_name"

  if [[ ! -d "$full_local_path" ]]; then
    start=$(date +'%s')
    printf "Cloning repo [%s]..." ${repo_name}

    git clone --single-branch --depth 1 "https://github.com/$repo_name" "$GGL_HOME/$repo_name" &>>! $GGL_LOG

    took=$(( $(date +'%s') - $start ))
    printf "done. Took %ds.\n" $took
  fi

  GGL_REPOS[$repo_name]="$GGL_HOME/$repo_name"

  builtin typeset -A args
  args[name]=$plugin_name
  args[path]=$full_local_path

  eval "${var}=(${(kv)args})"
}

# Download and sources a zsh plugin
# Usage:
#   ggl bundle <github_user>/<repository>[/<path>] [<script_file_name>]
ggl-bundle() {
  builtin typeset -A bundle; _ggl_ensure_repo  'bundle' ${=@}

  bundle_file=${2:-${bundle[name]:t}.plugin.zsh}

  set --
  source "${bundle[path]}/$bundle_file"
}

# Download and sources a zsh theme
# Usage:
#   ggl theme <github_user>/<repository>[/<path>] [<script_file_name>]
ggl-theme() {
  builtin typeset -A theme; _ggl_ensure_repo  'theme' ${=@}

  theme_file=${2:-${theme[path]:t}.zsh-theme}

  set --
  source "${theme[path]}/$theme_file"
}

# Download a configuration repository and makes a symlink to home directory, if not exists.
# A `.` prefix is automatically added to the symlink created if the original file doesn't have any.
#
# Usage:
#   ggl config <github_user>/<repository>[/<path>] [<config_file_name>]
ggl-config() {
  local ln_source_file ln_target_file
  builtin typeset -A config; _ggl_ensure_repo  'config' ${=@}

  conf_file=${2:-${config[path]:t}.conf}

  ln_source_file=${config[path]}/$conf_file

  [[ $conf_file == .* ]] && ln_target_file=$HOME/$conf_file || ln_target_file=$HOME/.$conf_file

  if [[ ! -e "$ln_target_file" ]]; then
    ln -s $ln_source_file $ln_target_file
  fi
}

# Updates every plugin
# Usage:
#   ggl update
# TODO:
# - try to update itself
# - accept argument in order to update single repositories
ggl-update() {
  local now update_log from_commit_id to_commit_id current_branch

  update_log="$GGL_HOME/update.log"
  touch $update_log

  now=$(date)

  printf "############ Updated on %s ############\n" ${now} >> $update_log
  for repo_name repo_path in "${(@kv)GGL_REPOS}"; do
    _local_git () { git -C $repo_path "$@" }

    _local_git rev-parse --is-inside-work-tree &>>! $GGL_LOG

    if [[ $? == 0 ]]; then 
      printf "Checkig repo [%s]... " ${repo_name}

      current_branch=$(_ggl_git_current_branch)

      from_commit_id=$(_local_git log --format="%H" -n 1)

      _local_git fetch --depth 1 &>>! $GGL_LOG
      _local_git reset --hard origin/$current_branch &>>! $GGL_LOG
      _local_git clean -dfx &>>! $GGL_LOG

      to_commit_id=$(_local_git log --format="%H" -n 1)

      if [[ ${from_commit_id} != ${to_commit_id} ]]; then
        printf "Repo [%s] updated: %s -> %s\n" ${repo_name} ${from_commit_id} ${to_commit_id} >> $update_log
        printf "updated to [%s].\n" ${to_commit_id}
      else
        printf "Repo [%s] already up to date\n" ${repo_name} >> $update_log
        printf "already up to date.\n"
      fi
    fi
  done

  printf "##################################################################\n\n" >> $update_log
}

# Install a local bundle
# Usage:
#   ggl install-local <absolute_source_path> <github_user>/<repository>[/<path>]
ggl-install-local() {
  local ln_source_file ln_target_file plugin_name 

  ln_source_file=$1
  plugin_name=${2:l}
  ln_target_file="$GGL_HOME/$plugin_name"

  if [[ ! -d "$ln_source_file" ]]; then
    ln_source_file=$(dirname $ln_source_file)
  fi

  if [[ ! -d "$ln_target_file" ]]; then
    mkdir -p "$(dirname $ln_target_file)"
    ln -s $ln_source_file $ln_target_file

    printf "Installed bundle [%s] from [%s]\n" $plugin_name $ln_source_file
  else
    printf "Bundle [%s] already installed from [%s]\n" $plugin_name $(readlink -f $ln_target_file)
  fi
}

ggl-help () {

  cat <<EOF

GGLoader is a very simple plugin management system for zsh. It makes it easy to
grab awesome shell scripts and utilities, put up on Github.

Usage: ggl <command> [args]

Commands:
  bundle       Install and load a plugin.
  theme        Install and load a theme
EOF
}

# A syntax sugar to avoid the `-` when calling ggloader commands. With this
# function, you can write `ggl-bundle` as `ggl bundle` and so on.
ggl () {
  local cmd="$1"
  if [[ -z "$cmd" ]]; then
    ggl-help >&2
    return 1
  fi
  shift

  if (( $+functions[ggl-$cmd] )); then
      "ggl-$cmd" "$@"
      return $?
  else
      echo "GGLoader: Unknown command: $cmd" >&2
      return 1
  fi
}