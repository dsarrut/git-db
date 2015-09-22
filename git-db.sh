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
git db pull          : pull and build the db (update to last version)
git db commit        : commit a new db version
git db set <mydb.db> : set the current db for next pull/commit
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
config_file="git-db-name.txt"

debug "command: {$command}"
debug "quiet: {$quiet}"
debug "dir: {$dir}"
# --------------------------------------------------------------


# --------------------------------------------------------------
set_db_data()
{
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
}
# --------------------------------------------------------------


# --------------------------------------------------------------
cmd_pull()
{
    debug "Start command pull"
    set_db_data
    git pull
    build_database
}
# --------------------------------------------------------------


# --------------------------------------------------------------
cmd_set()
{
    debug "Start command set $@"
    if [ -f $config_file ]
    then
        mv $config_file ${config_file}.backup
    fi
    f=$@
    filename=$(basename "$f")
    extension="${f##*.}"
    file="${f%.*}"
    # create the db name
    echo $file > $config_file
    set_db_data
    # insert files in git
    echo "Committing the schema/sql of the '$file'"
    git add $config_file
    git commit $config_file -m "Updating database name '$file'"
    dump_database
    git add $db_schema $db_sql
    git commit $db_sql $db_schema -m "Update database schema and sql of '$file'"
    echo $f >> .gitignore
}
# --------------------------------------------------------------


# --------------------------------------------------------------
cmd_commit()
{
    debug "Start command commit"
    set_db_data

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
# Execute the command
"cmd_$command" "$@"
# --------------------------------------------------------------
