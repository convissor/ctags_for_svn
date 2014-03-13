#! /bin/bash

if [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]] ; then
	echo "Usage:  ctags-for-svn.sh"
	echo ""
	echo "Runs ctags over the SVN repository you're currently in."
	echo "Stores the results in 'tags' file in the root .svn directory."
	echo ""
	echo "NB: add ctags_for_svn.vim to your ~/.vim/plugins directory and"
	echo "you're golden."
	echo ""
	echo "Author: Daniel Convissor <dconvissor@analysisandsolutions.com>"
	exit 1
fi

# Inspired by: http://tbaggery.com/2011/08/08/effortless-ctags-with-git.html


file=.svn/tags


dir=`pwd`

if [[ -d "$dir/.svn" ]] ; then
	# Present directory contains .svn dir.
	# Is there one in the parent directory too?
	while [[ -d "$dir/../.svn" ]] ; do
		# Yes, let's try again with its parent.
		dir=`dirname "$dir"`
	done

else
	# Present directory doesn't contain a .svn dir.
	# So we'll check parent dirs until we reach one with .svn in it or /.
	while [[ ! -d "$dir/.svn" && $dir != '/' ]] ; do
		# No love yet; let's go to the parent dir.
		dir=`dirname "$dir"`
	done

	if [[ ! -d "$dir/.svn" ]] ; then
		echo "You're not in a Subversion checkout."
		exit 1
	fi
fi


rm -f "$dir/$file"
ctags --php-kinds=-v -Rf"$dir/$file" --exclude=.svn --languages=-javascript,sql "$dir" > /dev/null 2>&1 &
