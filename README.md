### git-db
Simple git extension to manage sqlite db versioning in git. 

Convert a sqlite database into a txt file that can be versioned in git. The txt files contains sql commands that enable to build the database everytime an update is pulled.

#### Requirements

git and sqlite

### Install
Make this script available in your path, git should recognize it. For example: 
`export PATH=${HOME}/git-db/:${PATH}`

### Usage

Type `git db` for help. 

* To insert a sqlite database into the current repository: `git db set mydatabase.db`
  **WARNING**, this command must be set before any of the two others.
* To commit a modification of the database: `git db commit -m "The db is updated"`
* To retrieve (pull) a modification: `git db pull`

#### Limitation

* Does not manage conflicts. Do it by hand by looking the file `.git-db/mydatabase.sql`
* The pull is slow because the database is rebuild from scratch.
