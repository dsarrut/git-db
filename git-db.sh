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
git db checkout      : force pull and build the db (erase the current modification)
--
h,help        show the help
d             show debug messages
"
eval "$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

PATH=$PATH:$(git --exec-path)
. git-sh-setup

# check that we are at top-level dir
cd_to_toplevel

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
db_config_folder=".git-db"
config_file=$db_config_folder/"git-db-name.txt"

### create the config folder if does not exist
if [ ! -d $db_config_folder ]
then
    mkdir $db_config_folder
    git add $db_config_folder
    git commit $db_config_folder -m "Create config folder"
    echo "Commit new db config folder named '$db_config_folder'"
    echo $db_config_folder >> .gitignore
fi

debug "command: {$command}"
debug "quiet: {$quiet}"
debug "dir: {$dir}"
# --------------------------------------------------------------


# --------------------------------------------------------------
initialize_db_names()
{
    if [ ! -f $config_file ]
    then
        die "Please provide a 'git-db-name.txt' file that contains the name of the database you want to track in git."
    fi

    if [ ! -s $config_file ]
    then
        die "Error, file 'git-db-name.txt' is empty. Please insert the name of the database you want to track in git."
    fi

    db_core_name=$(cat $config_file)
    db_name=${db_core_name}.db
    db_sql=${db_config_folder}/${db_core_name}.sql
    db_schema=${db_config_folder}/${db_core_name}.schema
    db_temp=${db_config_folder}/${db_core_name}.temp
    db_log=${db_config_folder}/${db_core_name}.log
}
# --------------------------------------------------------------


# --------------------------------------------------------------
cmd_pull()
{
    debug "Start command pull"
    initialize_db_names

    ## check if the current db has been modified
    echo "Before pull, check if the current db has been locally modified"
    dump_database
    r=`git status -s ${db_sql}`
    if [[ ${r:1:2} == "M" ]]
    then
        echo  "Error: the current db has been locally modified, I cannot pull."
    else
        echo "No, the db has not been modified, I can pull"
        git pull
        build_database
    fi
}
# --------------------------------------------------------------


# --------------------------------------------------------------
cmd_checkout()
{
    debug "Start command checkout"
    initialize_db_names
    git checkout ${db_sql} ${db_schema}
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
    initialize_db_names
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
    initialize_db_names

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
    #echo "Converting database into sql commands"
    sqlite3 $db_name .sch > $db_schema
    sqlite3 $db_name .dump > $db_temp
    grep -v -f $db_schema $db_temp > $db_sql
    rm $db_temp
}
# --------------------------------------------------------------


# --------------------------------------------------------------
build_database()
{
    echo "(Backup the previous db as $db_name.backup)"
    if [ -e $db_name ]
    then
        mv $db_name $db_name.backup
    fi
    echo "Building the database schema"
    sqlite3 -init $db_schema $db_name .exit 2> $db_log | xargs echo -n
    echo "Insert the data"
    sqlite3 -init $db_sql $db_name .exit 2>> $db_log | xargs echo -n

    # (the  | xargs echo -n remove the line break)
    # as explain in http://stackoverflow.com/questions/12524308/bash-strip-trailing-linebreak-from-output
}
# --------------------------------------------------------------


# --------------------------------------------------------------
# Execute the command
"cmd_$command" "$@"
# --------------------------------------------------------------
