#! /bin/bash

# Usage
if [ $# -eq 0 ]
then
  # Print a usage help message
  echo "Usage: $0 [PART] [WORKING_DIR] \n"
  echo "\t [PART] script part number(number). Default value = 1"
  echo "\t [WORKING_DIR] working directory. Should be a git worktree or git repository"
  exit 1
fi

# Parse args
PT=${1:-1}
WD=${2:-$(pwd)}
EDITOR="code"

# Creading fresh data
echo "Fresh Ticket Number: "
read ticket_number

echo "Ticket public link: "
read ticket_public_link

# create rapanui mutation
echo "Create rapanui mutation \n"

echo "Type email: "
read email
echo "Type email subject: "
read subject
echo "Type tenant name: "
read tenant
echo "Type country: "
read country

# working directory should be a git working tree
echo "
Working dir: $WD
"
cd $WD

# creating worktree with a new branch
branch="hotfix/${subject// /-}-$tenant-$PT"
worktree_location="../worktrees/$ticket_number-${subject// /-}-$PT "
git worktree add -b $branch $worktree_location main &&\
cd $worktree_location &&\

# execute create mutation rapanui script
./scripts/create-mutation ${subject// /_}_$PT -e "$email" -s "$subject parte $PT" -t "$tenant" -c "$country" &&\

# add changes
git add mutations/ &&\

# edit files
$EDITOR $(git diff --staged --name-only) &&\

exit 1

# add changes
git add mutations/ &&\

# commit changes
git commit -S -s -v -m "fix: $subject part-$PT $tenant $country

[fresh-$ticket_number]($ticket_public_link)
" &&\

# push and create branch in remote
git push origin -u $branch
