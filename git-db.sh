#!/bin/sh
#
# git-db.sh:
#
# Copyright (C) 2015 David Sarrut <david.sarrut@gmail.com>
#
# (inspired from git-annex)
# --------------------------------------------------------
if [ $# -eq 0 ]; then
    set -- -h
fi

OPTS_SPEC="\
git db pull
git db commit
git db push
--
h,help        show the help
d             show debug messages
"
eval "$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

PATH=$PATH:$(git --exec-path)
. git-sh-setup

require_work_tree

debug=

db_name=mydb.db
db_sql=mydb.sql
db_tables_dump=dump_for_git.txt

# --------------------------------------------------------------
debug()
{
    if [ -n "$debug" ]; then
	printf "%s\n" "$*" >&2
    fi
}
# --------------------------------------------------------------

# --------------------------------------------------------------

#echo "Options: $*"

while [ $# -gt 0 ]; do
    opt="$1"
    shift
    case "$opt" in
	-d) debug=1 ;;
	--) break ;;
	*) die "Unexpected option: $opt" ;;
    esac
done

command="$1"
shift

dir="$(dirname "$prefix/.")"

debug "command: {$command}"
debug "quiet: {$quiet}"
debug "dir: {$dir}"
# --------------------------------------------------------------

# --------------------------------------------------------------
cmd_pull()
{
    debug "start cmd pull"
    git pull
    build_database
}
# --------------------------------------------------------------

# --------------------------------------------------------------
cmd_commit()
{
    if [ $# -ne 1 ]; then
	die "You must provide <commit message>"
    fi
    debug "start cmd commit with msg=\""$1"\""

    # convert the database into a text file with sql commands
    dump_database

    # commit the created files
    git commit $db_sql -m "$1"
}
# --------------------------------------------------------------

# --------------------------------------------------------------
dump_database()
{
    echo "dump db"
    sqlite3 $db_name < $db_tables_dump > $db_sql
}
# --------------------------------------------------------------

# --------------------------------------------------------------
build_database()
{
    echo "Building the database from sql commands"
    if [ -e $db_name ]
    then
        mv $db_name $db_name.backup
    fi
    sqlite3 -init $db_sql $db_name .exit 2> sqlite.log
}
# --------------------------------------------------------------


# --------------------------------------------------------------
# Execute the command
"cmd_$command" "$@"
# --------------------------------------------------------------
