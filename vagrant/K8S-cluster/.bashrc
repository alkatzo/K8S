#!/bin/bash 

#######################################################
# Export all functions from this file
#######################################################
#set -a

#######################################################

# Source global definitions
if [ -f /etc/bashrc ]; then
	 . /etc/bashrc
fi

# Enable bash programmable completion features in interactive shells
if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
fi

if [ -d ~/.bashrc.d ]; then
  for rc in $(/bin/ls ~/.bashrc.d/); do
    source $rc
  done
fi

#######################################################
# EXPORTS
#######################################################
iatest=$(expr index "$-" i)

# Disable the bell
if [[ $iatest > 0 ]]; then bind "set bell-style visible"; fi

export TERM=xterm-256color

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=5000

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Check the window size after each command and, if necessary, update the values of LINES and COLUMNS
shopt -s checkwinsize

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
shopt -s histappend

# Allow ctrl-S for history navigation (with ctrl-R)
#stty -ixon

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
if [[ $iatest > 0 ]]; then bind "set completion-ignore-case on"; fi

# Show auto-completion list automatically, without double tab
if [[ $iatest > 0 ]]; then bind "set show-all-if-ambiguous On"; fi

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=01;38;5;27:ln=0;38;5;14:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=0;38;5;10:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
export GREP_OPTIONS='--color=auto' #deprecated
alias grep="/usr/bin/grep $GREP_OPTIONS"
unset GREP_OPTIONS

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

alias ll='ls -al --color'

#######################################################
# Set the ultimate amazing command prompt
#######################################################

function __setprompt
{
	local LAST_COMMAND=$? # Must come first!

	# Define colors
	local LIGHTGRAY="\e[38;5;7m"
	local DARKGRAY="\e[38;5;8m"
	local WHITE="\e[38;5;15m"
	local BLACK="\e[38;5;16m"
	local RED="\e[38;5;1m"
	local LIGHTRED="\e[38;5;9m"
	local GREEN="\e[38;5;2m"
	local LIGHTGREEN="\e[38;5;2m"
	local BROWN="\e[38;5;3m"
	local YELLOW="\e[38;5;11m"
	local BLUE="\e[38;5;27m"
	local LIGHTBLUE="\e[38;5;45m"
	local MAGENTA="\e[38;5;13m"
	local LIGHTMAGENTA="\e[38;5;219m"
	local CYAN="\e[38;5;6m"
	local LIGHTCYAN="\e[38;5;14m"
	local NOCOLOR="\e[00m"

	PS1=""

	# User and server
	local SSH_IP=`echo $SSH_CLIENT | awk '{ print $1 }'`
	local SSH2_IP=`echo $SSH2_CLIENT | awk '{ print $1 }'`
    local SERVER=`hostname -f`
	if [ $SSH2_IP ] || [ $SSH_IP ] ; then
		PS1+="\[${GREEN}\]\u\[${LIGHTGRAY}\]@\[${BROWN}\]$SERVER"
	else
		PS1+="\[${GREEN}\]\u\[${LIGHTGRAY}\]@\[${BROWN}\]$SERVER"
	fi

	# Current directory
	PS1+="\[${LIGHTGRAY}\]:\w"

	if [[ $EUID -ne 0 ]]; then
		PS1+="\[${GREEN}\]>\[${NOCOLOR}\] " # Normal user
	else
		PS1+="\[${RED}\]>\[${NOCOLOR}\] " # Root user
	fi

	# PS2 is used to continue a command using the \ character
	PS2="\[${DARKGRAY}\]>\[${NOCOLOR}\] "

	# PS3 is used to enter a number choice in a script
	PS3='Please enter a number from above list: '

	# PS4 is used for tracing a script in debug mode
	PS4='$LINENO: '
}
export -f __setprompt
export PROMPT_COMMAND='__setprompt'


########################################################
########################################################
#                       functions                      #
########################################################
########################################################


#!/bin/bash

function title ()
{
    echo -ne "\033]30;$1\007"
}

function ssh ()
{
    local LIGHTCYAN="\e[38;5;14m"
    local NOCOLOR="\e[00m"
    
    dest=${!#}
    if [[ $dest == *"@"* ]]; then
        USERNAME=`echo $dest | cut --only-delimited -d '@' -f1`
        SERVERNAME=`echo $dest | cut --only-delimited -d '@' -f2`
    else
        USERNAME=$USER
	SERVERNAME=$dest
    fi

    cp ~/.bashrc /tmp/.bashrc_remote_$SERVERNAME
    sed -i "/local SERVER=/c\local SERVER=$SERVERNAME" /tmp/.bashrc_remote_$SERVERNAME
    echo -e "${LIGHTCYAN}Copying files to $SERVERNAME ...${NOCOLOR}"
    scp -q /tmp/.bashrc_remote_$SERVERNAME ~/.bash_aliases ~/.tmux.conf $USERNAME@$SERVERNAME:~/


    echo -e "${LIGHTCYAN}Checking if TMUX is installed on $SERVERNAME ...${NOCOLOR}"
    # check if the remote has tmux 
    if command ssh $@ "command -v tmux>/dev/null" 2>/dev/null; then 
        # just ssh into it
        echo -e "${LIGHTCYAN}Connecting to $SERVERNAME ...${NOCOLOR}"
        command ssh -t $@ "/bin/bash --rcfile ~/.bashrc_remote_$SERVERNAME; rm ~/.bashrc_remote_$SERVERNAME; rm ~/.bash_aliases"
    else 
    
        # no tmux on the remote => if current has tmux => change current tmux window title to the remote name
        if command -v tmux>/dev/null; then
            tmux set-window-option window-status-format "#[fg=green] #{window_index} #[fg=colour196] $SERVERNAME"
            tmux set-window-option window-status-current-format "#[fg=green] #{window_index} #[fg=colour196] $SERVERNAME"
        fi
        echo -e "${LIGHTCYAN}Connecting to $SERVERNAME ...${NOCOLOR}"
        command ssh -t $@ "/bin/bash --rcfile ~/.bashrc_remote_$SERVERNAME; rm ~/.bashrc_remote_$SERVERNAME"
        if command -v tmux>/dev/null; then
            tmux set-window-option window-status-format "#[fg=green] #{window_index} #[fg=colour45] #{pane_current_path}"
            tmux set-window-option window-status-current-format "#[fg=green] #{window_index} #[fg=colour45] #{pane_current_path}"
        fi
    fi
}


function rpm-extract ()
{
    rpm2cpio $1 | cpio -idmv
}

git_n_files=0
git_commit=""
git_push=""

set-jira-ticket()
{
    local input_string="$1"
    # Extract the first two tokens separated by '-'
    local jira_ticket=$(echo "$input_string" | cut -d'-' -f1-2)
    # Export the variable
    export JIRA_TICKET="$jira_ticket"
}

function git-co ()
{
    git checkout $1
    set-jira-ticket $1
}

function git-add-all ()
{
    files=$(git st | awk '/modified:|deleted:|new file:/ {print $2}')
    if [ -z "$files" ]; then
        echo "Nothing to add"
        return 0
    fi
    files="$files"

    git add --all $files
    git st
    return 1
}

function git-commit-all ()
{
    if [ "$#" -lt 1 ]; then
        echo "usage : git-commit-all \"commit message\""
        return 0
    fi

    git-add-all
    local n_files=$?

    if [ $n_files -eq 0 ]; then
	echo "Nothing to commit"
        return 0
    fi

    local message="\"$JIRA_TICKET $*\""
    printf "\e[96mgit commit -m $message\e[0m\n"
    echo "Commit using the above command? [Y/n]"
    read -s -n 1 answer 

    if [ -z "$answer" ] || [ $answer != 'n' ]; then
        git commit -m "$message"
	git st
	return $n_files
    else
        return 0
    fi
}

function git-push-all ()
{
    if [ "$#" -lt 1 ]; then
        echo "usage : git-push-all \"commit message\""
        return
    fi

    git-commit-all "$@"
    n_files=$?

    if [ $n_files -eq 0 ]; then
	echo "Nothing to push"
        return
    fi

    printf "\e[96mgit push\e[0m\n"
    echo "Push using the above command? [Y/n]"
    read -s -n 1 answer
    if [ -z "$answer" ] || [ $answer != 'n' ]; then
        git push
    fi
}

function git-unstage-all ()
{
    git reset HEAD
    git st
}

function git-undo-commit ()
{
    git reset --soft HEAD~1
    git st
}

function path-munge ()
{
    export PATH=$1:$PATH
}

function show-colors ()
{
    for i in 00{2..8} {0{3,4,9},10}{0..7};
    do
        echo -e "$i \e[0;${i}mcolor\e[00m  \e[1;${i}mcolor\e[00m";
    done
}

function show-rich-colors ()
{
    for i in {0..255}; do
        printf "\x1b[0;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[1;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[2;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[3;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[4;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[5;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[6;38;5;${i}mcolour${i}\x1b[0m\n"
        printf "\x1b[7;38;5;${i}mcolour${i}\x1b[0m\n"
    done
}


# Searches for text in all files in the current folder
function ftext ()
{
	# -i case-insensitive
	# -I ignore binary files
	# -H causes filename to be printed
	# -r recursive search
	# -n causes line number to be printed
	# optional: -F treat search term as a literal, not a regular expression
	# optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
	grep -iIHrn --color=always "$1" . | less -r
}

# Goes up a specified number of directories  (i.e. up 4)
function up ()
{
	local d=""
	limit=$1
	for ((i=1 ; i <= limit ; i++))
		do
			d=$d/..
		done
	d=$(echo $d | sed 's/^\///')
	if [ -z "$d" ]; then
		d=..
	fi
	cd $d
}
export -f up

#########################################
# Enable default toolsets
########################################

DEV_TOOLSET=/opt/rh/devtoolset-7/enable
if [ -f "$DEV_TOOLSET"   ]; then
    source $DEV_TOOLSET
fi
LLVM_TOOLSET=/opt/rh/llvm-toolset-7/enable
if [ -f "$LLVM_TOOLSET"    ]; then
    source $LLVM_TOOLSET
fi

# Boost variables
export BOOST_ROOT=/home/sroot/Applications/boost_1_77_0

######################################################
# SOURCE ALIASES
#####################################################
if [ -f ~/.bash_aliases    ]; then
    source ~/.bash_aliases
fi

#######################################################
# Run tmux if installed
#######################################################

if command -v tmux>/dev/null;
then
  # find detached session
  SESSION=$(tmux ls 2>/dev/null | grep -v attached | awk -F ':' '{print $1;}' | sort -n | tail -1)
  if [ ! -z "$SESSION" ]; then
    tmux_cmd="TERM=xterm-256color tmux attach -t \"$SESSION\""

  else
  # no detached sessions => make a new session
    MAX_SESSION=$(tmux ls 2>/dev/null | awk '{print $1;}' | sed -n 's/session// ; s/://p' | sort -n | tail -1)
    if [ ! -z "$MAX_SESSION" ]; then
      SESSION=$((MAX_SESSION+1))
    else
      SESSION=1
    fi
    tmux_cmd="TERM=xterm-256color tmux -q new -s session$SESSION"
  fi
  [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && eval $tmux_cmd
fi

