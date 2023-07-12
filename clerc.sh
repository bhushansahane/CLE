#!/bin/sh
##
## ** CLE : Command Live Environment **
##
#* author:  Michael Arbet (marbet@redhat.com)
#* home:    https://github.com/micharbet/CLE
#* version: 2021-10-11 (Zodiac)
#* license: GNU GPL v2
#* Copyright (C) 2016-2021 by Michael Arbet

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# CLE provides:
# -improved look&feel: responsive colorful prompt, highlighted exit code
# -persistent alias store - command 'aa'
# -rich history - commands 'h' and 'hh'
# -seamless remote CLE session, with no installation - use 'lssh' instead 'ssh'
# -local live session - lsu/lsudo (su/sudo wrappers)
# -setup from command line, eg. 'cle color RGB'
# -find more using 'cle help' and 'cle doc'
#
# Quick setup:
# 1. Download and execute this file within your shell session
# 2. Integrate it into your profile:
#	$ . clerc
#	$ cle deploy
# 3. Enjoy!

[ -f $HOME/CLEDEBUG ] && { CLE_DEBUG=1; }				# dbg

# Check if the shell is interactive and CLE not yet started
#: required for scp compatibility and also prevents loop upon `cle reload`
[ -t 0 -a -z "$CLE_EXE" ] || dbg_print "Warning! nested CLE start"	# dbg
[ -t 0 -a -z "$CLE_EXE" ] || return

# Now it really starts, warning: magic inside!

#:------------------------------------------------------------:#
# Debugging helpers							# dbg
dbg_print () { [ $CLE_DEBUG ] && echo "DBG: $*" >/dev/tty; }		# dbg
dbg_var () (								# dbg
	eval "V=\$$1"							# dbg
	[ $CLE_DEBUG ] && printf "DBG: %-16s = %s\n" $1 "$V" >/dev/tty	# dbg
)									# dbg
dbg_print; dbg_print pid:$$						# dbg

#:------------------------------------------------------------:#
# Startup sequence
#: First check how is this script executed
#:  - in case of a shell resource, this will be interactive session,
#:    prepare basic environment variables and do the shell specific tasks
#:  - in case of start as a command, open a shell (zsh or bash) and push this file
#:    as a resource
#: Then find out suitable shell and use it to run interactive shell session with
#: this file as init resource. The $CLE_RC variable must contain full path!
export CLE_RC
dbg_var CLE_RC
dbg_var CLE_ARG
dbg_var CLE_USER
dbg_var SHELL
dbg_var BASH
dbg_var ZSH_NAME
_C=$SHELL:$BASH:$ZSH_NAME:$0
dbg_print "startup case: '$_C'"
_T=/var/tmp/$USER
case  $_C in
*zsh::*zsh:*/rc*) # started FROM .zshrc
	dbg_print sourcing to ZSH - from .zshrc
	CLE_RC=$0
	;;
*clerc*|*:*/rc*) # executed as a command from .cle directory
	#: IMPORTANT: code in this section must be strictly POSIX compatible with /bin/sh
	#: Now we're looking for suitable shell: user's login shell first, fallback to bash
	dbg_print executing as LIVE SESSION, looking for shell
	CLE_RC=$(cd `dirname $0`;pwd;)/$(basename $0) # full path to this file
	SH=$SHELL
	#: process command line options
	while [ $1 ]; do
		case $1 in
		-b*)	SH=`which bash`		# force bash
			export CLE_ARG='-b'
			;;
		-z*)	SH=`which zsh 2>/dev/null || which bash` # try zsh
			export CLE_ARG='-z'
			;;
		-m)	CLE_MOTD=`uptime`
			export CLE_MOTD
			;;
		*)	echo "$0: unknown option '$1'"; exit 1;;
		esac
		shift
	done
	export CLE_PROF=1	#: profile files will be executed
	case $SH in
	*zsh)	#: prepare startup environment in zsh way
		dbg_print found ZSH
		export ZDOTDIR=$_T
		mkdir -p $ZDOTDIR
		ln -sf $CLE_RC $ZDOTDIR/.zshrc
		exec zsh
		;;
	*)	#: fallback to bash
		dbg_print found BASH
		exec bash --rcfile $0
		;;
	esac
	;;
*bash:*bash) # bash session resource
	dbg_print sourcing to BASH
	#: CLE_RC not necessarily known!
	CLE_RC=$BASH_SOURCE
	;;
*zsh:*zsh) # zsh session resource (started AS TEMPORARY .zshrc)
	dbg_print sourcing to ZSH - from live session
	#: CLE_RC already set, exported
	unset ZDOTDIR
	;;
*)	echo "CLE startup failed: 'case $_C'";;
esac

#: Reaching this point means that the script is running as a resource
#: to the interactive session. Further code must be bash & zsh compatible!
dbg_print ---------------
dbg_print Resource starts
dbg_print ---------------

# execute script and log its filename into CLE_EXE
# also ensure the script will be executed only once
_clexe () {
	[ -f "$1" ] || return 1
	[[ $CLE_EXE =~ :$1[:$] ]] && return
	CLE_EXE=$CLE_EXE:$1
	dbg_print _clexe $1
	source $1
}
CLE_EXE=$CLE_RC

# Run profile files
#: This must be done now, not later because files may contain confilcting settings.
#: E.g. there might be vte.sh defining own PROMPT_COMMAND and this completely
#: breaks rich history.
dbg_var CLE_PROF
# current shell
CLE_SH=`basename $BASH$ZSH_NAME`
if [ -n "$CLE_PROF" ]; then
	_clexe /etc/profile
	_clexe $HOME/.${CLE_SH}rc
	unset CLE_PROF
fi

# Use alias built-ins for startup
#: alias & unalias must be available in their natural form during CLE startup
#: and will be redefined at the end of resource
unset -f alias unalias 2>/dev/null
#: remove particular aliases that might be defined e.g. in .bashrc
#: those were causing confilcts, more of them might be added later
unalias aa h hh .. ... 2>/dev/null

#:------------------------------------------------------------:#
# Variables init

# First run check
if [[ $CLE_RC =~ clerc ]]; then
	dbg_print First run
	CLE_RD=$HOME/.cle-`whoami`
	mkdir -m 755 -p $CLE_RD
	CLE_1=$CLE_RD/rc1
	cp $CLE_RC $CLE_1
	chmod 755 $CLE_1
	CLE_RC=$CLE_1
fi

# CLE_RC can be relative path, make it full
CLE_RD=$(cd `dirname $CLE_RC`;pwd;)
CLE_RC=$CLE_RD/`basename $CLE_RC`
dbg_var CLE_RC
dbg_var CLE_RD

# FQDN hack
#: Find the longest - the most complete hostname string.
#: Sometimes information from $HOSTNAME and command `hostname` differs.
CLE_FHN=$HOSTNAME
_N=`hostname`
[ ${#CLE_FHN} -lt ${#_N} ] && CLE_FHN=$_N
#: hostname -f disabled because it requires working net & DNS!
#:_N=`hostname -f 2>/dev/null`
#:[ ${#CLE_FHN} -lt ${#_N} ] && CLE_FHN=$_N
#: It is also difficult to get local IP addres. There is no simple
#: and multiplattform way to get it. See commands: ip, ifconfig,
#: hostname -i/-I, netstat...
#: Thus, on workstation its just empty string :-( Better than 5 IP's from `hostname -i`
CLE_IP=${CLE_IP:-`cut -d' ' -f3 <<<$SSH_CONNECTION`}

# where in the deep space CLE grows
CLE_SRC=https://raw.githubusercontent.com/micharbet/CLE/Zodiac
CLE_VER=`sed -n 's/^#\* version: //p' $CLE_RC`
CLE_VER="$CLE_VER debug"			# dbg

# find writable folder
#: there can be real situation where a remote account is restricted and have no
#: home folder. In such case CLE can save config and other files into /var/tmp.
#: Note, Live sessions have their respurce files always in /var/tmp/$USER but
#: this must not be writable in subsequent lsu/lsudo sessions.
#:  $CLE_D   is path to writable folder for config, aliases and other runtime files
#:  $CLE_RD  is path to folder containing startup resources
_H=$HOME
[ -w $_H ] || _H=$_T
[ -r $HOME ] || HOME=$_H	#: fix home dir if broken - must be at least readable
dbg_var HOME
dbg_var _H
dbg_var _T
dbg_var PWD
[ $PWD = $_T ] && cd		#: go to real home if initiated in temporary home folder
CLE_D=$_H/`sed 's:/.*/\(\..*\)/.*:\1:' <<<$CLE_RC` #: regex cuts anything up to first DOTfolder
dbg_var CLE_D
mkdir -m 755 -p $CLE_D

# config, tweak, etc...
CLE_CF=$CLE_D/cf-$CLE_FHN	#: NFS homes may keep configs for several hosts
CLE_AL=$CLE_D/al
CLE_HIST=$_H/.clehistory
_N=`sed 's:.*/rc1*::' <<<$CLE_RC` #: resource suffix contains workstation name
dbg_print "_N should contain resource suffix. here it is: '$_N'"
CLE_WS=${_N/-/}
CLE_TW=$CLE_RD/tw$_N
CLE_ENV=$CLE_RD/env$_N
CLE_TTY=`tty|tr -d '/dev'`
PROMPT_DIRTRIM=3

# who I am
#: determine username that will be inherited over the all
#: subsquent sessions initiated with lssh and su* wrappers
#: the regexp extracts username from following patterns:
#: - /any/folder/.cle-username/rcfile
#: - /any/folder/.config/cle-username/rcfile
#: important is the dot (hidden folder), word 'cle' with dash
_N=`sed -n 's;.*cle-\(.*\)/.*;\1;p' <<<$CLE_RC`
export CLE_USER=${CLE_USER:-${_N:-$(whoami)}}
dbg_var CLE_USER

#:------------------------------------------------------------:#
# Internal functions

_clebnr () {
cat <<EOT

$_CC   ___| |     ____| $_CN Command Live Environment activated
$_CB  |     |     __|   $_CN ...bit of life to the command line
$_Cb  |     |     |     $_CN Learn more:$_CL cle help$_CN and$_CL cle doc$_CN
$_Cb$_CD \____|_____|_____| $_CN Uncover the magic:$_CL less $CLE_RC$_CN

EOT
}

# boldprint
_clebold () { printf "$_CL$*$_CN\n";}

# simple question
_cleask () (
	PR="$_CL$* (y/N) $_CN"
	[ $ZSH_NAME ] && read -ks "?$PR" || read -n 1 -s -p "$PR"
	echo ${REPLY:=n}
	[ "$REPLY" = "y" ]
)

# Create color table
#: initialize $_C* variables with terminal compatible escape sequences
#: following are basic ones:
_cletable () {
	dbg_print "_cletable updating color table"
	_C_=$TERM	#: save terminal type of this table
	_CN=`tput sgr0`
	_CL=`tput bold`
	_CU=`tput smul`;_Cu=`tput rmul`
	_CV=`tput rev`
	#: Note: dim and italic not available everywhere (e.g. RHEL)
	_CI=`tput sitm`;_Ci=`tput ritm`
	_CD=`tput dim`
	_Ck=$_CN$(tput setaf 0)
	_Cr=$_CN$(tput setaf 1)
	_Cg=$_CN$(tput setaf 2)
	_Cy=$_CN$(tput setaf 3)
	_Cb=$_CN$(tput setaf 4)
	_Cm=$_CN$(tput setaf 5)
	_Cc=$_CN$(tput setaf 6)
	_Cw=$_CN$(tput setaf 7)
	case `tput colors` in
	8)
		_CK=$_Ck$_CL
		_CR=$_Cr$_CL
		_CG=$_Cg$_CL
		_CY=$_Cy$_CL
		_CB=$_Cb$_CL
		_CM=$_Cm$_CL
		_CC=$_Cc$_CL
		_CW=$_Cw$_CL
		;;
	*)
		_CK=$_CN$(tput setaf 8)$_CL
		_CR=$_CN$(tput setaf 9)$_CL
		_CG=$_CN$(tput setaf 10)$_CL
		_CY=$_CN$(tput setaf 11)$_CL
		_CB=$_CN$(tput setaf 12)$_CL
		_CM=$_CN$(tput setaf 13)$_CL
		_CC=$_CN$(tput setaf 14)$_CL
		_CW=$_CN$(tput setaf 15)$_CL
		;;
	esac
	#: and... special color code for error highlight in prompt
	_Ce=$_CR$_CL$_CV # err highlight
}

# set prompt colors
_cleclr () {
        local C I CI E
        case "$1" in
        red)    C=RrR;;
        green)  C=GgG;;
        yellow) C=YyY;;
        blue)   C=BbB;;
        cyan)   C=CcC;;
        magenta) C=MmM;;
        grey|gray) C=wNW;;
        tricolora) C=RBW;;
        marley) C=RYG;; # Bob Marley style :-) have a smoke and imagine...
        *)      C=$1;; #: any color combination
        esac
        # decode colors and prompt strings
        #: three letters ... dim status part _C0
        #: four letters .... user defined status color
        #: five letters .... also user defined commad highlighting (defauld bold)
        [ ${#C} = 3 ] && C=D${C}L || C=${C}L
        for I in {0..4};do
                eval "CI=\$_C${C:$I:1}"
                # check for exsisting color, ignore 'dim' and 'italic as they might not be defined
                if [[ -z "$CI" && ! ${C:$I:1} =~ [ID] ]]; then
                        echo "Wrong color code '${C:$I:1}' in $1" && CI=$_CN
                        E=1     #: error flag
                fi
                eval "_C$I=\$CI"
        done
        [ ${C:0:1} = D ] && _C0=$_C1$_CD #: dim color for status part 0
        if [ $E ]; then
                echo "Choose predefined scheme:$_CL"
                declare -f _cleclr|sed -n 's/^[ \t]*(*\(\<[a-z |]*\)).*/ \1/p'|tr -d '\n|'
                printf "\n${_CN}Alternatively create your own 3-5 letter combo using rgbcmykw/RGBCMYKW\n"
                printf "E.g.:$_CL cle color rgB\n"
                _cleclr gray    #: default in case of error
                return 1
        else
                CLE_CLR=${C:0:5}
        fi
}


# CLE prompt escapes
#:  - enhanced prompt escape codes introduced with ^ sign
#:  - bash uses backslash while zsh percent sign for their prompt escapes
_clesc () (
	#: CLE extensions
	EXTESC="
	 -e 's/\^i/\$CLE_IP/g'
	 -e 's/\^h/\$CLE_SHN/g'
	 -e 's/\^H/\$CLE_FHN/g'
	 -e 's/\^U/\$CLE_USER/g'
	 -e 's/\^g/\$(_clegitwb)/g'
	 -e 's/\^?/\$_EC/g'
	 -e 's/\^[E]/\\$_PE\$_CE\\$_Pe\[\$_EC\]\\$_PE\$_CN\$_C0\\$_Pe/g'
	 -e 's/\^[C]\(.\)/\\$_PE\\\$_C\1\\$_Pe/g'
	 -e 's/\^v\([[:alnum:]_]*\)/\1=\$\1/g'
	 -e 's/\^\^/\^/g'
	"
	#:  bash/zsh prompt compatibility
	#: there are missing translations:
	#:  \a Bell character
	#:  \e ESC
	#:  \r Carriage return
	#:  \nnn ASCII octal character
	#:  \v Bash version, who the f... needs this?
	#:  \V ... same ^^^
	#: so much backslashes due to multiple string expansions and `eval` at the end
	[ $ZSH_NAME ] && SHESC="-e 's/\\\\n/\$_PN/g'
	 -e 's/\\^[$%#]/%#/g'
	 -e 's/\\\\d/%D{%a %b %d}/g'
	 -e 's/\\\\D/%D/g'
	 -e 's/\\\\h/%m/g'
	 -e 's/\\\\H/%M/g'
	 -e 's/\\\\j/%j/g'
	 -e 's/\\\\l/%l/g'
	 -e 's/\\\\s/zsh/g'
	 -e 's/\\\\t/%*/g'
	 -e 's/\\\\T/%D{%r}/g'
	 -e 's/\\\\@/%@/g'
	 -e 's/\\\\A/%T/g'
	 -e 's/\\\\u/%n/g'
	 -e 's/\\\\w/%$PROMPT_DIRTRIM~/g'
	 -e 's/\\\\W/%1~/g'
	 -e 's/\\\\!/%!/g'
	 -e 's/\\\\#/%i/g'
	 -e 's/\\\\\[/%{/g'
	 -e 's/\\\\\]/%}/g'
	 -e 's/\\\\\\\\/\\\\/g'
	" || SHESC="-e 's/\^[$%#]/\\\\\$/g'"
	#: compose substitute command, remove unwanted characters
	SUBS=`tr -d '\n\t' <<<$SHESC$EXTESC`
	eval sed "$SUBS" <<<"$*"
)

_cle_r () {
	[ "$1" != h ] && return
	printf "\n$_Cr     ,==~~-~w^, \n    /#=-.,#####\\ \n .,!. ##########!\n((###,. \`\"#######;."
	printf "\n &######\`..#####;^###)\n$_CW   (@@$_Cr^#############\"\n$_CW"
	printf "    \\@@@\\__,-~-__,\n     \`&@@@@@69@@/\n        ^&@@@@&*\n$_CN\n"
}

# override default prompt strings with configured values
_clepcp () {
	local I
	#: use CLE_PBx values and override with CLE_PZx for zsh
	#: check function _clesc that transforms bash escapes into zsh
	for I in 0 1 2 3 T; do
		eval "CLE_P$I=\${CLE_PB$I:-\$CLE_P$I}"
		[ $ZSH_NAME ] && eval "CLE_P$I=\${CLE_PZ$I:-\$CLE_P$I}"
		[ $1 ] && unset CLE_P{B,Z}$I
	done
}

# craft the prompt from defined strings
_cleps () {
	[ "$CLE_PT" ] && PS1="$_PE\${_CT}$(_clesc $CLE_PT)\${_Ct}$_Pe" || PS1=''
	PS1=$PS1`_clesc "^C0$CLE_P0^C1$CLE_P1^C2$CLE_P2^C3$CLE_P3^CN^C4"`
	PS2=`_clesc "^C3>>> ^CN^C4"`
}

# default prompt strings and colors
_cledefp () {
	CLE_P0='^E \t '
	CLE_P1='\u '
	CLE_P2='^h '
	CLE_P3='\w ^$ '
	CLE_PT='\u@^H'
	#: decide by username and if the host is remote
	case "$USER-${CLE_WS#$CLE_FHN}" in
	root-)	_DC=red;;	#: root@workstation
	*-)	_DC=marley;;	#: user's basic color scheme
	root-*)	_DC=RbB;;	#: root@remote
	*-*)	_DC=blue;;	#: user@remote
	esac
}

# save configuration
_clesave () (
	echo "# $CLE_VER"
	_clevdump "CLE_CLR|CLE_PB.|CLE_PZ."
) >$CLE_CF


# prompt callback functions
#: 
#: Important note about code efficiency:
#: As precmd function is executed *every* time you push <enter> key, its code
#: needs to be as simple as possible. All commands here should be internals.
#: Internal commands don't invoke (fork) new processes and as such they
#: are much easier to system resources.
#: E.g. construction `C=${C#*;}` could be written as C=$(sed 's/[^;]*;\(.*\)/\1/' <<<$C)
#: Not only the actually used expression is shorter but also much faster since `sed`
#: would be executed as new process from binary file
#: The same rule applies to CLE internal functions used and called within prompt
#: callback. Namely: `precmd` `preexec` `clepreex` `clerh`
#:
_PST='${PIPESTATUS[@]}'		#: status of all command in pipeline has different name in zsh
[ $ZSH_NAME ] && _PST='${pipestatus[@]}'
[ "$BASH_VERSINFO" = 3 ] && _PST='$?' #: RHEL5/bash3 workaround, check behaviour on OSX, though, ev. remove this line
precmd () {
	eval "_EC=$_PST"
	[[ $_EC =~ [1-9] ]] || _EC=0 #: just one zero if all ok
	local IFS S DT C
	unset IFS
	if [ $BASH ]; then
		C=$_HN	#: already prepared by _clepreex()
		history -a	#: immediately record commands so they are available in new shell sessions
	else
		C=`fc -lt ";$CLE_HTF;" -1`	#: get recent command, strip sequence number
		C=${C#*;}
	fi
	DT=${C/;*}	#: extract date
	C=${C/$DT;}	#: extract pure command
	C="${C#"${C%%[![:space:]]*}"}" #: remove leading spaces (needed in zsh)
	#: ^^^ found here: https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
	if [[ $C =~ ^\# ]]; then
		_clerh '#' "$PWD" "$C"	# record a note to history
	elif [ $_HT ]; then	# check timer - indicator of executed command
		S=$((SECONDS-${_HT:-$SECONDS}))
		_clerh "$DT" $S "$_EC" "$PWD" "$C"
		[ "$_EC" = 0 ] && _CE="" || _CE="$_Ce" #: highlight error code
		_HT=
	else
		_CE=''
		_EC=0 #: reset error code so it doesn not disturb on other prompts
	fi
	[ $BASH ] && trap _clepreex DEBUG
}

# run this function before the issued command
#: This fuction is used within prompt calback.
preexec () {
	dbg_print 'preexec()'
	_HT=$SECONDS	#: star history timer $_HT
}

CLE_HTF='%F %T'
HISTTIMEFORMAT=${HISTTIMEFORMAT:-$CLE_HTF }	#: keep already tweaked value if exists

# Bash hack
#: Zsh supports preexec function naturaly. This is bash's workaround.
#: This fuction is used within prompt calback. Read code efficiency note above!
#: _HP and _HN - previous and next command taken from shell history are compared
#: sequence number have to be cut out as they are not necessarily the same over sessions
if [ $BASH ]; then
	history -r $HISTFILE
	_HP=`HISTTIMEFORMAT=";$CLE_HTF;" history 1`	#: prepare history for comaprison
	_HP=${_HP#*;}	#: strip sequence number
	dbg_var _HP
_clepreex () {
	_HN=`HISTTIMEFORMAT=";$CLE_HTF;" history 1`
	_HN=${_HN#*;}	#: strip sequence number
	echo -n $_CN	#: reset tty colors
	dbg_var _HP
	dbg_var _HN
	dbg_var BASH_COMMAND
	[ "$_HP" = "$_HN" ] && return
	_HP=$_HN
	trap "" DEBUG
	preexec "$BASH_COMMAND"
}
fi

# rich history record
#: This fuction is used within prompt calback. Read code efficiency note above!
_clerh () {
	local DT RC REX ID V VD W
	#: three to five arguments, timestamp and elapsed seconds may be missing
	case $# in
	3)	DT=`date "+$CLE_HTF"`;SC='';;
	4)	DT=`date "+$CLE_HTF"`;SC=$1;shift;;
	5)	DT=$1;SC=$2;shift;shift;;
	esac
	#: ignore commands that dont want to be recorded
	REX="^cd\ |^cd$|^-$|^\.\.$|^\.\.\.$|^aa$|^lscreen|^h$|^hh$|^hh\ "
	[[ $3 =~ $REX  || -n $_NORH ]] && unset _NORH && return
	#: working dir (substitute home with ~)
	W=${2/$HOME/\~}
	#: create timestamp if missing
	ID="$DT;$CLE_USER-$$"
	REX='^\$[A-Za-z0-9_]+' #: regex to identify simple variables
	case "$3" in
	echo*) #: create special records for `echo $VARIABLE`
		echo -E "$ID;$SC;$1;$W;$3"
		for V in $3; do
			if [[ $V =~ $REX ]]; then
				V=${V/\$/}
				VD=`_clevdump $V`
				echo -E "$ID;;$;;${VD:-unset $V}"
			fi
		done;;
	xx) # directory bookmark
		echo -E "$ID;;*;$W;" ;;
	\#*) #: notes to rich history
		echo -E "$ID;;#;$W;$3" ;;
	*) #: regular commands
		echo -E "$ID;$SC;$1;$W;$3" ;;
	esac
} >>$CLE_HIST


# print MOTD + more
if [ "$CLE_MOTD" ]; then
	[ -f /etc/motd ] && cat /etc/motd
	printf "\n$CLE_MOTD"
	_clebold "\n CLE/$CLE_SH $CLE_VER\n"
	unset CLE_MOTD
fi

# read inherited environment
[ $CLE_WS ] && _clexe $CLE_ENV

# colorize LS
case $OSTYPE in
linux*)		alias ls='ls --color=auto';;
darwin*)	export CLICOLOR=1; export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd;;
FreeBSD*)       alias ls='ls -G "$@"';;
*)		alias ls='ls -F';; # at least some file type indication
esac

# colorized GREP except on busybox
#: busybox identified by symlinked 'grep' file
if [ -L `command which grep` ];then
	#: Fedora defines this mess :(
	unalias grep egrep fgrep xzgrep xzegrep xzfgrep zgrep zegrep zfgrep 2>/dev/null
else
	alias grep='grep --color=auto'
fi

# Remove alias 'which' if there is no version supporting extended options
#: This weird construction ensures that the 'which' will work even in case
#: there's an alias containing extended options inherited from such workstation
#: E.g. Fedora supports option --read-alias but Debian and BSD do not have this
#: version of 'which' command.
{ alias|command which -i which || unalias which; } >/dev/null 2>&1

## ** cd command enhancements **
## `.. ...`     - up one or two levels
## `-`  (dash)  - cd to recent dir
- () { cd - >/dev/null; _clevdump OLDPWD;}
.. () { cd ..;}
... () { cd ../..;}
## `xx` & `cx`   - bookmark $PWD & use later
xx () { _XX=$PWD; echo path bookmark: $_XX; }
cx () { cd $_XX; }

##
## ** Alias management **
aa () {
	local AED=$CLE_AL.ed
	local Z=${ZSH_NAME:+-L}
	case "$1" in
	"")	## `aa`         - show aliases
		#: also make the output nicer and more easy to read
		builtin alias $Z|sed "s/^alias \([^=]*\)=\(.*\)/$_CL\1$_CN\t\2/";;
	-s)	## `aa -s`      - save aliases
		builtin alias $Z >$CLE_AL;;
	-e)	## `aa -e`      - edit aliases
		builtin alias $Z >$AED
		vi $AED
		[ $ZSH_NAME ] && builtin unalias -m '*' || builtin unalias -a
		. $AED;;
	*=*)	## `aa a='b'`   - create new alias and save
		builtin alias "$*"
		aa -s;;
	*)	builtin alias "$*";;
	esac
}


##
## ** History tools **
## `h`               - shell 'history' wrapper
h () (
	([ $BASH ] && HISTTIMEFORMAT=";$CLE_HTF;" history "$@" || fc -lt ";$CLE_HTF;" "$@")|( IFS=';'; while read -r N DT C;do
		echo -E "$_CB$N$_Cb $DT $_CN$_CL$C$_CN"
	done;) 
)

## `hh [opt] [srch]` - rich history viewer
hh () (
	OUTF='_clehhout'
	DISP=""
	S=""
	while getopts "mdtsncfl" O;do
		case $O in
		m)	## `hh -m`           - my commands, exclude other users
			S=$S" -e'/.*;$CLE_USER/!d'";;
		d)	## `hh -d`           - today's commands
			S=$S" -e '/^$(date "+%F") /!d'";;
		t)	## `hh -t`           - commands from current session
			S=$S" -e '/.*;$CLE_USER-$$;.*/!d'";;
		s)	## `hh -s`           - select successful commands only
			S=$S" -e '/.*;.*;.*;0;.*/!d'";;
		n)	## `hh -n`           - narrow output, hide time and session id
			OUTF='_clehhout n';;
		c)	## `hh -c`           - show only commands
			OUTF="sed -n 's/^[^;]*;[^;]*;[^;]*;[0-9]*;[^;]*;\(.*\)/\1/p' |uniq";;
		f) 	## `hh -f`           - show working folder history
			OUTF="sed -n 's/^[^;]*;[^;]*;[^;]*;[0-9]*;\([^;]*\);.*/\1/p' |sort|uniq";;
		l)	## `hh -l`           - display using 'less'
			DISP="|less -r +G";;
		*)	cle help hh;return
		esac
	done
	shift $((OPTIND-1))

	#: number (default 100) or search string; sed-escape slashes to '\/'
	A=${*:-100}
	[[ $A =~ ^[0-9]*$ ]] && N=$A || S=$S" -e '/${A////\\/}/!d'"

	#: execute filter stream
	dbg_print hh: eval "tail -n ${N:-+1} $CLE_HIST ${S:+|sed $S} | $OUTF  $DISP"
	eval "tail -n ${N:-+1} $CLE_HIST ${S:+|sed $S} | $OUTF  $DISP"
)

# rich history colorful output filter
_clehhout () (
	NRW=$1	#: narrow output; without timestamp and session id
	set -f
	while read -r L; do
		#: it would be easier to use loop with `read DT SID SEC EC DIR CMD`
		#: but some bash implementations remove IFS from CMD thus rendering
		#: the command on the output incomplete. e.g. Fedora, Debian implementation
		#: of bash keeps the separator while RHEL and Centos removes it. Grrrr...
		IFS=';'
		set -- $L
		case $4 in
		 0) CE=$_Cg; CC=$_CN;;
		 @) CE=$_Cc; CC=$_Cc;;
		 '#'|$|'*') CE=$_CY; CC=$_Cy;;
		 *) CE=$_Cr; CC=$_CN;;
		esac
		if [ $NRW ]; then
			#: print less information (option -n)
			printf " $CE%-9s $CC%-20s: $_CL" "$4" "$5"
		else
			#: print full record
			printf "$_CB%s $_Cb%-13s $_CB%3s $CE%-5s $CC%-10s: $_CL" "$1" "$2" "$3" "$4" "$5"
		fi
		#: print the unprocessed rest of the input - the command itself
		shift 5
		printf "%s\n" "$*"
	done
)

# zsh hack to accept notes on cmdline
[ $ZSH_NAME ] && '#' () { true; }

#: show current working branch name
_clegitwb () (
	# go down the folder tree and look for .git
	#: Because this function is supposed to use in prompt we want to save
	#: cpu cycles. Do not call `git` if not necessary.
	while [ "$PWD" != / ]; do
		[ -d .git ] && { git symbolic-ref --short HEAD; return; }
		cd ..
	done
	return 1  # not in git repository
	)


#: Highly sophisticated .md format highlighter :-D
#: Just replaces special strings in markdown files and augments the output
#: with escape codes to highlight.
#: Not perfect, but it helps and is simple, isn't it?
_clemdf () {
	sed -e "s/^###\(.*\)/$_CL\1$_CN/"\
	 -e "s/^##\( *\)\(.*\)/\1$_CU$_CL\2$_CN/"\
	 -e "s/^#\( *\)\(.*\)/\1$_CL$_CV \2 $_CN/"\
	 -e "s/\*\*\(.*\)\*\*/$_CL\1$_CN/"\
	 -e "s/\<_\(.*\)_\>/$_CU\1$_Cu/g"\
	 -e "s/\`\`\`/$_CD~~~~~~~~~~~~~~~~~$_CN/"\
	 -e "s/\`\([^\`]*\)\`/$_Cg\1$_CN/g"
}

#: dump variables in reusable way
_clevdump () (
	#: awk: 1. exits when reaches functions
	#:      2. finds variables matching regular expression
	#:      3. replaces weird escape sequence '\C-[' from zsh to normal '\E'
	typeset 2>/dev/null | awk '/.* \(\)/{exit} /(^'$1')=/{gsub(/\\C-\[/,"\\E");print}'
)

#:------------------------------------------------------------:#

##
## ** Live session wrappers **

# Environment packer
#: On workstation do following:
#:  -copy resource file, tweak and selected variables to temporary folder
#: If required for remote session do following:
#:  -pack the folder with tar, and store as base64 encoded string into $C64
#: Always: prepare $RH and $RC for live session wrappers
_clepak () {
	RH=${CLE_RD/\/.*/}	#: resource home is path until first dot
	RD=${CLE_RD/$RH\//}	#: relative path to resource directory

	if [ $CLE_WS ]; then
		#: this is live session, all files *should* be available, just set vars
		cd $RH
		RC=${CLE_RC/$RH\//}
		TW=${CLE_TW/$RH\//}
		EN=${CLE_ENV/$RH\//}
		dbg_print "_clepak: rc already there: $(ls -l $RC)"
	else
		#: live session is to be created - copy startup files
		RH=/var/tmp/$USER
		dbg_print "_clepak: preparing $RH/$RD"
		#: by default prepare files in /var/tmp; fall back to the home dir
		mkdir -m 0755 -p $RH/$RD 2>/dev/null && cd $RH || cd
		RC=$RD/rc-$CLE_FHN
		TW=$RD/tw-$CLE_FHN
		EN=$RD/env-$CLE_FHN
		cp $CLE_RC $RC
		cp $CLE_TW $TW 2>/dev/null
		#: prepare environment to transfer: color table, prompt settings, WS name and custom exports
		echo "# evironment $CLE_USER@$CLE_FHN" >$EN
		_clevdump "CLE_SRE|CLE_P..|^_C." >>$EN
		_clevdump "$CLE_EXP" >>$EN
		echo "CLE_DEBUG='$CLE_DEBUG'" >>$EN			# dbg
		cat $CLE_AL >>$EN 2>/dev/null
	fi
	#: save the envrironment tarball into $C64 if required
	#: Note: I've never owned this computer, I had Atari 800XL instead :-)
	#: Anyway, the variable name can be considered as a tribute to the venerable 8-bit
	[ $1 ] && C64=`eval tar chzf - $RC $TW $EN 2>/dev/null | base64 | tr -d '\n\r '`
	#:             ^^^^ 'eval' required due to zsh.
}

## `lssh [usr@]host`   - access remote system and take CLE along
lssh () (
	[ "$1" ] || { cle help lssh;return 1;}
	_clepak tar
	[ $CLE_DEBUG ] && _clebold "C64 contains following:" && echo -n $C64 |base64 -d|tar tzf -			# dbg
	#: remote startup
	#: - create destination folder, unpack tarball and execute the code
	command ssh -t $* "
		H=/var/tmp/\$USER; mkdir -m 755 -p \$H; cd \$H
		export CLE_DEBUG='$CLE_DEBUG'	# dbg
		[ \"\$OSTYPE\" = darwin ] && D=D || D=d
		echo $C64|base64 -\$D|tar xzmf - 2>/dev/null
		exec \$H/$RC -m $CLE_ARG"
		#: it is not possible to use `base63 -\$D <<<$C64|tar xzf -`
		#: systems with 'ash' instead of bash would generate an error (e.g. Asustor)
)

#: Following are su* wrappers of different kinds including kerberos
#: version 'ksu'. They are basically simple, you see. Environment is not
#: packed and transferred when using them. Instead the original files from
#: user's home folder are used.
## `lsudo [user]`      - sudo wrapper; root is the default account
lsudo () (
	_clepak
	dbg_print "lsudo runs: $RH/$RC"
        sudo -i -u ${1:-root} $RH/$RC $CLE_ARG
)

## `lsu [user]`        - su wrapper
#: known issue - on debian systems controlling terminal is detached in case 
#: a command ($CLE_RC) is specified, use 'lsudo' instead
lsu () (
        _clepak
	S=
        [[ $OSTYPE =~ [Ll]inux ]] && S="-s /bin/sh"
        eval su $S -l ${1:-root} $RH/$RC
)

## `lksu [user]`       - ksu wrapper
#: Kerberized version of 'su'
lksu () (
	_clepak
        ksu ${1:-root} -a -c "cd;$RH/$RC"
)

## `lscreen [name]`    - gnu screen wrapper, join your recent session or start new
## `lscreen -j [name]` - join other screen sessions, ev. search by name
#: GNU screen wrapper is here 1) because of there was no way to tell screen
#: program to start CLE on more than first window and, 2) to allow easily
#: join detached own session and/or join cooperative session with more
#: participants.
lscreen () (
	#: get name of the screen to search and join
	#: base of session name is $CLE_USER and this can be extended
	NM=$CLE_USER${1:+-$1}
	[ "$1" = -j ] && NM=${2:-.}
	#: list all screens with that name and find how many of them are there
	SCRS=`screen -ls|sed -n "/$NM/s/^[ \t]*\([0-9]*\.[^ \t]*\)[ \t]*.*/\1/p"`
	NS=`wc -w <<<$SCRS`
	reset #: it is sometimes necessary to reset terminal
	if [ $NS = 0 ]; then
		[ "$1" = -j ] && echo "No screen to join" && return 1
		#: No session with given name found, prepare to start new session
		SCF=$CLE_D/screenrc
		SN=$CLE_TTY-CLE.$NM
		_clerh @ $CLE_TTY "screen -S $SN"
		_clescrc >$SCF
		screen -c $SCF -S $SN $CLE_RC
	else
		#: is there only one such session or more?
		if [ $NS = 1 ]; then SN=$SCRS
		else
			#: we found more screens with simiilar names, choose one!
			_clebold "${_CU}Current '$NM' sessions:"
			PS3="$_CL choose # to join: $_CN"
			select SN in $SCRS;do
				[ $SN ] && break
			done
		fi
		_clerh @ $CLE_TTY "screen -x $SN"
		screen -S $SN -X echo "$CLE_USER joining" #: alert to the original session
		screen -x $SN
	fi
)

# screenrc generator
#: This generates nice configuration file with cool features:
#:  - always visible status line with list of windows, hostname and clock
#:  - feature to quickly switch using Ctrl+Left/Right Arrows
#:  - reads good old $HOME/.screenrc
#: Own screenrc file is necessary because otherwise it wouldn't start CLE in
#: subsequent windows created with 'C-a C-c' (note the bind commands, above
#: mentioned features are cool but this part is the important one)
_clescrc () {
cat <<-EOS
	source $HOME/.screenrc
	altscreen on
	autodetach on
	# enables shift-PgUp/PgDn
	termcapinfo xterm* ti@:te@
	# change window with ctrl-left/right
	bindkey "^[[1;5D" prev
	bindkey "^[[1;5C" next
	defscrollback 9000
	hardstatus alwayslastline
	hardstatus string '%{= Kk} %-w%{Wk}%n %t%{-}%+w %-=%{+b Y}$CLE_SHN%{G} %c'
	bind c screen $CLE_RC
	bind ^c screen $CLE_RC
EOS
#: user's addition to the screenrc via the variable - set in tweak file
cat <<<$CLE_SCRC
}


#:------------------------------------------------------------:#
#: all fuctions declared, startup continues

# shorten hostname
#: by default remove domain, leave subdomains
#: eventually apply CLE_SRE as sed regexp for custom shortening
CLE_SHN=`eval sed "${CLE_SRE:-'s:\.[^.]*\.[^.]*$::'}" <<<$CLE_FHN`

#: stop annoying zsh error when '*' doesn't match any file
[ $ZSH_NAME ] && setopt +o NOMATCH

# record this startup into rich history
_clerh @ $CLE_TTY "[${STY:-${CLE_WS:-WS}},$CLE_SH]"
[ $CLE_DEBUG ] && _clerh @ $PWD "$CLE_RC [$CLE_VER]"

_clexe $HOME/.cle-local
_clexe $CLE_AL
_clexe $CLE_TW
for M in $CLE_D/mod-*; do
	_clexe $M
done

#: Enhnace PATH by user's own bin folder
[[ -d $HOME/bin && ! $PATH =~ $HOME/bin ]] && PATH=$PATH:$HOME/bin

# create the prompt in several steps
# 1. default prompt strings
_cledefp

# 2. override with inherited strings
[ $CLE_WS ] && _clepcp x

# 3. create color table if necessary
[ "$TERM" != "$_C_" -o -z "$_CN" ] && _cletable

# 4. get values from config file
# rewrite config of old CLE release					#: transition
[ -f $CLE_D/cf -a ! -f $CLE_CF ] && cp $CLE_D/cf $CLE_CF		#: transition
[ -r $CLE_CF ] && read _N <$CLE_CF || _N=Zodiac				#: transition
[[ $_N =~ Zodiac ]] || {						#: transition
	_O=$CLE_D/cf-old						#: transition
	mv -f $CLE_CF $_O 2>/dev/null					#: transition
	_R="s!^#.*!# $CLE_VER!"						#: transition
	if [ $CLE_WS ]; then						#: transition
		#: remove CLE_Px on remote sessions, ensure inheritance	#: transition
		_R=$_R";/^CLE_P/d"					#: transition
	else								#: transition
		#: rename CLE_Px to $CLE_PBx on workstation		#: transition
		_R=$_R";s/^CLE_P\(.\)='\(.*\)'/CLE_PB\1='\2 '/"		#: transition
		_R=$_R";s/%/^/g" # replace % with ^			#: transition
		_R=$_R";s/\^c/^C/g" # replace ^c with ^C		#: transition
		_R=$_R";s/\^e/^E/g" # replace ^c with ^E		#: transition
	fi								#: transition
	[ -f $_O ] && sed -e "$_R" <$_O >$CLE_CF			#: transition
	rm -f $CLE_D/cle-mod 2>/dev/null # force refresh cle-mod	#: transition
	unset _O _R							#: transition
}									#: transition
_clexe $CLE_CF
_clepcp

# 5. terminal specific
#: $_CT and $_Ct are codes to create window title
#: also in screen the title should be short and obviously no title on text console

case $TERM in
linux)	 CLE_PT='';;	# no tits on console
screen*) CLE_PT='\u'
	printf "\e]0; screen: $CLE_USER@$CLE_FHN$_Ct\007"
	_CT=$'\ek'; _Ct=$'\e\\';;
*)	_CT=$'\e]0;'; _Ct=$'\007';;
esac

# 6. shell specific
#: $_PE nad $_Pe keep strings to enclosing control charaters in prompt
if [ $BASH ]; then
	shopt -s checkwinsize
	_PE='\['; _Pe='\]'
else
	setopt PROMPT_SUBST SH_WORD_SPLIT
	_PE='%{'; _Pe='%}'
	_PN=$'\n' # zsh doesn't know '\n' as escape sequence! WTF?
fi

# 7. craft the prompt string
_cleps
_cleclr ${CLE_CLR:-$_DC}

PROMPT_COMMAND=precmd

# completions
#: Command 'cle' completion
#: as an addition, prompt strings are filled for convenience :)
#: And, thanks to nice people on stackoverflow.com I know it can be used in both shells
#: https://stackoverflow.com/questions/3249432/can-a-bash-tab-completion-script-be-used-in-zsh
_clecomp () {
	#: list of subcommands, this might be reworked to have possibility of expansion
	#: with modules (TODO)
	#: 'cle deploy' is hidden intentionaly
	local A=(color p0 p1 p2 p3 cf mod env update reload doc help)
	local C
	COMPREPLY=()
	case $3 in
	p0) COMPREPLY="'$CLE_P0'";;
	p1) COMPREPLY="'$CLE_P1'";;
	p2) COMPREPLY="'$CLE_P2'";;
	p3) COMPREPLY="'$CLE_P3'";;
	#'') COMPREPLY=$A;;
	esac
	[ "$3" != "$1" ] && return
	for C in ${A[@]}; do
		[[ $C =~ ^$2 ]] && COMPREPLY+=($C)
	done
}

if [ $BASH ]; then
	# lssh completion
	#: there are two possibilities of ssh completion _known_hosts is more common...
	declare -F _known_hosts >/dev/null && complete -F _known_hosts lssh
	#: while _ssh is better
	#: The path is valid at least on fedora and debian with installed bash-completion package
	_N=/usr/share/bash-completion
	_clexe $_N/bash_completion
	_clexe $_N/completions/ssh && complete -F _ssh lssh
else
	# ZSH completions
	autoload compinit && compinit
	autoload bashcompinit && bashcompinit
	compdef lssh=ssh
fi
complete -F _clecomp cle

# redefine alias builtins
#: those definitions must be here, only after config and tweaks not to mess
#: with builtin shell functions during startup. This also speeds up the thing
alias () {
	if [ -n "$1" ]; then
		aa "$@"
	else
		builtin alias
	fi
}

unalias () {
	[ "$1" = -a ] && cp $CLE_AL $CLE_AL.bk  # BASH only!
	builtin unalias "$@"
	aa -s
}

# check manual/initial run
[ $CLE_1 ] && cat <<EOT
 It seems you started CLE running '$CLE_1' from command line
 Since this is the first run, consider setup in your profile.
 Run following command to hook CLE into your $HOME/.${CLE_SH}rc:
$_CL    cle deploy
EOT

[ -r . ] || cd #: go home if this is unreadable directory

##
## ** CLE command & control **
cle () {
	local C I P S N
	C=$1;shift
	if declare -f _cle_$C >/dev/null;then #: check if an add-on function exists
		_cle_$C $*
		return $?
	elif [ -f $CLE_D/cle-$C ]; then	#: check module
		. $CLE_D/cle-$C $*
		return $?
	fi
	case $C in
	color)  ## `cle color COLOR`       - set prompt color
		[ $1 ]  && _cleclr $1 && _clesave;;
	p?)	## `cle p0-p3 [str]`       - show/define prompt parts
		I=${C:1:1}
		if [ "$1" ]; then
			#: obtain shell prefix
			#: if the propmt string is bash compatible, store it into $CLE_PBx
			#: otherwise use $CLE_PZx
			P=B; [[ $* =~ % && -n "$ZSH_NAME" ]] && P=Z || unset CLE_PZ$I
			#: store the value only if it's different
			#: this is to prevent situation when inherited value is set in configuration
			#: causing to break the inheritance later
			S=$*
			eval "[ \"\$S\" != \"\$CLE_P$I\" ] && { CLE_P$P$I='$*';_clepcp;_cleps;_clesave; }" || :
		else
			_clevdump CLE_P$I
		fi;;
	title)	## `cle title off|string`  - turn off window title or set the string
		case "$1" in
		off)	CLE_PT='';;
		'')	_clepcp;;
		*)	cle pT "$*";;
		esac
		_cleps;;
	cf)	## `cle cf [ed|reset|rev]` - view/edit/reset/revert configuration
		case "$1" in
		ed)	vi $CLE_CF  && . $CLE_RC;;
		reset)	mv -f $CLE_CF $CLE_CF-bk;;
		rev)	cp $CLE_CF-bk $CLE_CF;;
		"")
			if [ -f $CLE_CF ]; then
				_clebold $_CU$CLE_CF:
				cat $CLE_CF
			else
				echo Default/Inherited configuration
			fi
			return;;
		esac
		cle reload;;
	deploy) ## `cle deploy`            - hook CLE into user's profile
		P=$HOME/.cle-$USER	#: new directory for CLE
		mkdir -p $P
		cp $CLE_RC $P/rc
		CLE_RC=$P/rc
		unset CLE_1
		I='# Command Live Environment'
		S=$HOME/.${SHELL##*/}rc	#: hook into user's login shell rc
		grep -A1 "$I" $S && _clebold CLE is already hooked in $S && return 1
		_cleask "Do you want to add CLE to $S?" || return
		echo -e "\n$I\n[ -f $CLE_RC ] && . $CLE_RC\n" | tee -a $S
		cle reload;;
	update) ## `cle update [master]`   - install fresh version of CLE
		N=$CLE_D/rc.new
		#: update by default from the own branch
		#: master brach or other can be specified in parameter
		curl -k ${CLE_SRC/Zodiac/${1:-Zodiac}}/clerc >$N
		#: check correct download and its version
		S=`sed -n 's/^#\* version: //p' $N`
		[ "$S" ] || { echo "Download error"; return 1; }
		echo current: $CLE_VER
		echo "new:     $S"
		I=`diff $CLE_RC $N` && { echo No difference; return 1;}
		_cleask Do you want to see diff? && cat <<<"$I"
		_cleask Do you want to install new version? || return
		#: now replace CLE code
		cp $CLE_RC $CLE_D/rc.bk
		chmod 755 $N
		mv -f $N $CLE_RC
		cle reload
		#: update modules if necessary
		N=cle-mod
		[ -f "$CLE_D/$N" ] || return
		echo updating modules
		curl -k $CLE_SRC/modules/$N >$CLE_D/$N && cle mod update
		;;
	reload) ## `cle reload [bash|zsh]` - reload CLE
		[[ $1 =~ ^[bz] ]] && S=-$1
		#: complete re-exec removes unexported variables
		[ $S ] && exec $CLE_RC $S
		#: re-sourcing the environment keeps user's settings
		unset CLE_EXE
		. $CLE_RC
		echo CLE $CLE_VER;;
	mod)    ## `cle mod`               - cle module management
		#: this is just a fallback to initialize modularity
		#: downloaded cle-mod overrides this code
		_cleask Activate CLE modules? || return
		N=cle-mod
		P=$CLE_D/$N
		curl -k $CLE_SRC/modules/$N >$P
		grep -q "# .* $N:" $P || { _clebold Module download failed; rm -f $P; return 1;}
		cle mod "$@";;
	env)	## `cle env`               - inspect variables
		_clevdump 'CLE.*'|awk -F= "{printf \"$_CL%-12s$_CN%s\n\",\$1,\$2}";;
	ls)	_clebold CLE_D: $CLE_D; ls -l $CLE_D; _clebold CLE_RD: $CLE_RD; ls -l $CLE_RD;;	# dbg
	exe)	echo $CLE_EXE|tr : \\n;;							# dbg
	debug)	case $1 in									# dbg
		"")	dbg_var CLE_DEBUG ;;							# dbg
		off)	CLE_DEBUG=''								# dbg
			rm ~/CLEDEBUG;;								# dbg
		*)	CLE_DEBUG=on								# dbg
			touch ~/CLEDEBUG;;							# dbg
		esac;;										# dbg
	help|-h|--help) ## `cle help [fnc]`        - show help
		#: double hash denotes help content
		P=`ls $CLE_D/cle-* 2>/dev/null`
		awk -F# "/\s##\s*.*$@|^##\s*.*$@/ { print \$3 }" ${CLE_EXE//:/ } $P | _clemdf | less -erFX;;
	doc)	## `cle doc`               - show documentation
		#: obtain index of doc files
		I=`curl -sk $CLE_SRC/doc/index.md`
		#: $I - index must contain word LICENSE - part of doc files
		[[ $I =~ LICENSE ]] || { echo Unable to get documentation;return 1;}
		#: choose one to read
		PS3="$_CL doc # $_CN"
		select N in $I;do
			[ $N ] && curl -sk $CLE_SRC/doc/$N |_clemdf|less -r; break
		done;;
	"")	#: do nothing, just show off
		_clebnr
		sed -n 's/^#\*\(.*\)/\1/p' $CLE_RC #: print lines starting with '#*' - header
		;;
	*)	echo unimplemented function: cle $C;
		echo check cle help;
		return 1
		;;
	esac
}

#: final cleanup
unset _T _H _C _N _DC

# that's all, folks...

