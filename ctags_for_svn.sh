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
while [[ -d "$dir/../.svn" ]] ; do
	dir=`dirname "$dir"`
done

if [[ ! -d "$dir/.svn" ]] ; then
	echo "Sorry, $dir is not a SVN checkout."
	exit 1
fi


rm -f "$dir/$file"
ctags --tag-relative -Rf"$dir/$file" --exclude=.svn --languages=-javascript,sql "$dir" > /dev/null 2>&1 &
