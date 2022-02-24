#!/bin/bash
# show the usage
usage() {
	script=${1##*/}
	echo "Usage :
	./$script [options] [folder]

	options:
		-h            show this usage
		-p [folder]   show undone tasks

	Parse the TODO in found files
	and put them in Markdown in a todo.md

ignores files/folders in .todo_ignore & $HOME/.todo_ignore"
}
# if no folder given
[ -z "$1" ] && usage "$0" && exit 1
# get arguments
while getopts ":hp:" options; do
	case $options in
		p)
			# show undone tasks
			while read r; do
				[ "$(echo "$r" | grep -v "[X]")" ] && echo "$r"
			done < <(cat "$OPTARG"/TODO.md)
			;;
		h)
			usage
			;;
		:)
			echo "-$OPTARG : missing argument"
			exit 1
			;;
		?)
			echo "-$OPTARG : unknown argument"
			exit 1
			;;
	esac
done
# get the argument after the getopts args
shift $(($OPTIND - 1))
# if is not a directory
[ -z "$1" ] && exit 1
! [ -d "$1" ] && echo "$1 is not a directory" && exit 2
# preparation
touch "$1/TODO.md"
list="$(cat "$1"/.todo_ignore 2> /dev/null || cat "$HOME/.todo_ignore" 2> /dev/null)"
no_dir=""
no_file=""
if ! [ -z "$list" ];then
	while read r; do
		f=$(find "$1" -type f)
		d=$(find "$1" -type d)
		[ $(d=$( echo "$d" | grep "$r") && echo "${d##*/}" | grep "${r}$") ] && no_dir+="$r,"
		[ $(f=$( echo "$f" | grep "$r") && echo "${f##*/}" | grep "${r}$") ] && no_file+="$r,"
	done < <(echo "$list")
	no_dir=${no_dir%,*}
	no_file=${no_file%,*}
	[ $(echo "$no_dir"| grep -o "," | wc -l) -ge "1" ] && no_dir="{$(echo "$no_dir")}"
	[ $(echo "$no_file"| grep -o "," | wc -l) -ge "1" ] && no_file="{$(echo "$no_file")}"
fi
# add to TODO.me
while read r; do
	filename=$(echo "$r" | cut -d : -f 1)
	todo="$filename: ${r##*TODO }"
	if [ "$(grep "$todo" "$1/TODO.md")" ]; then
		# if it is done but still in the file mark it as not done
		infile="$(grep "$todo" "$1/TODO.md")"
		if [ "$(echo "$infile" | grep -E '\[X]')" ]; then
			sed -i "s|- \[X] $todo|- \[ ] $todo|g" "$1/TODO.md"
		fi
	else
		echo "- [ ] $todo" >> "$1/TODO.md"
	fi
done < <(eval grep -r TODO "$1" --exclude-dir="$no_dir" --exclude="$no_file")
# loop through TODO.md to check if they are DONE
while read r; do
	f="$(echo "$r" | sed 's/^- \[.\] \(.*\)$/\1/g' | cut -d ':' -f1)"
	todo=$(echo "$r" | grep -Po '[^:]*.$')
	if ! [ "$(grep "$todo" "$f")" ]; then
		todo=$(echo "$r" | grep -Po '[^\]]*.$')
		sed -i "s|- \[ ]$todo|- \[X]$todo|g" "$1/TODO.md"
	fi
done < <(cat "$1/TODO.md")
