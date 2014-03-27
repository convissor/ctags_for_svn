#! /bin/bash -e

if [[ $1 == "-h" || $1 == "--help" ]] ; then
	echo "Usage:  ctags-for-svn.sh"
	echo ""
	echo "Runs ctags over the SVN repository you're currently in."
	echo "Stores the results in 'tags' file in the root .svn directory."
	echo ""
	echo "NB: add ctags_for_svn.vim to your ~/.vim/plugins directory and"
	echo "you're golden."
	echo ""
	echo "Author: Daniel Convissor <dconvissor@analysisandsolutions.com>"
	echo "https://github.com/convissor/ctags_for_svn"
	echo ""
	echo "Inspired by: http://tbaggery.com/2011/08/08/effortless-ctags-with-git.html"
	exit 1
fi


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

# Temporary file name has process id appended to it.
file_temp="$dir/.svn/tags.$$"
file_perm="$dir/.svn/tags"

# When the script exits, quietly remove the temporary file, if any.
trap "rm -f '$file_temp'" EXIT

# Recursively parse the repository.
# Record paths relative to the tag file.
# Put the output into a (temporary) file named tags.<process id>.
# Don't parse the .svn directory.
# Don't analyze JavaScript or SQL files.
# Don't analyze variables in PHP files.
# Pass along any extra arguments.
# Then replace the permanent file with the temporary file.
# Run this stuff in the background and direct all output to never never land.
$(ctags -Rf"$file_temp" --tag-relative --exclude=.svn --languages=-javascript,sql \
		--php-kinds=-v "$@" "$dir" \
	&& mv "$file_temp" "$file_perm") > /dev/null 2>&1 &
