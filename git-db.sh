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
--
h,help        show the help
d             show debug messages
"
eval "$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

PATH=$PATH:$(git --exec-path)
. git-sh-setup

require_work_tree

debug=

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
set_db_data()
{
    config_file="git-db-name.txt"
    if [ ! -f $config_file ]
    then
        die "Please provide a 'git-db-name.txt' file that contains the name of the database you want to track in git."
    fi

    if [ ! -s $config_file ]
    then
        die "Error, file 'git-db-name.txt' is empty. Please insert the name of the database you want to track in git."
    fi

    db_core_name=$(cat "git-db-name.txt")
    db_name=${db_core_name}.db
    db_sql=${db_core_name}.sql
    db_schema=${db_core_name}.schema
    db_temp=.${db_core_name}.temp
    db_log=.${db_core_name}.log
    echo $db_name
}
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
    git commit $db_sql $db_schema -m "$1"
}
# --------------------------------------------------------------


# --------------------------------------------------------------
dump_database()
{
    echo "Converting database into  sql commands"
    #sqlite3 $db_name < $db_tables_dump > $db_sql
    sqlite3 $db_name .sch > $db_schema
    sqlite3 $db_name .dump > $db_temp
    grep -v -f $db_schema $db_temp > $db_sql
    rm $db_temp
}
# --------------------------------------------------------------


# --------------------------------------------------------------
build_database()
{
    echo "Backup previous db"
    if [ -e $db_name ]
    then
        mv $db_name $db_name.backup
    fi
    echo "Building the database schema"
    sqlite3 -init $db_schema $db_name .exit 2> $db_log
    echo "Insert the data"
    sqlite3 -init $db_sql $db_name .exit 2>> $db_log
}
# --------------------------------------------------------------


# --------------------------------------------------------------
# set the db name
set_db_data

# Execute the command
"cmd_$command" "$@"
# --------------------------------------------------------------
