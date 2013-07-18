#!/usr/bin/env bash
set -e

# The directory this script is in.
SCRIPT_DIR=`dirname "${BASH_SOURCE[0]}"`

usage() {
  cat $SCRIPT_DIR/README.md |
  # Remove ticks and stars.
  sed -e "s/[\`|\*]//g"
}

# Parse options.
DRUSH="drush"
URI=
DOCROOT=
VERBOSE=
DEBUG=

while getopts “xvh:l:r:” OPTION; do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    d)
      DRUSH=$OPTARG
      ;;
    l)
      URI=$OPTARG
      ;;
    r)
      # Check to make sure the directory exists.
      if [[ ! -d "$DOCROOT" ]]; then
        echo "$DOCROOT is not a directory."
        exit 1
      fi
      ;;
    v)
      VERBOSE="--verbose"
      ;;
    x)
      set -x
      DEBUG="--debug"
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

# Remove the switches we parsed above from the arguments.
shift `expr $OPTIND - 1`

# Determine which options/arguments to use. If -l and -r are specified, they are
# preferred over the alias. If no argument is specified, @self is used.
if [[ -n $URI ]] && [[ -n $DOCROOT ]]; then
  DESTINATION="--root=\"$DOCROOT\" --uri=\"$URI\""
else
  DESTINATION=${1:-@self}
fi

eval $DRUSH cc drush

# Put drush in verbose mode, if requested.
DRUSH="$DRUSH $DESTINATION $VERBOSE $DEBUG"

# Check to make sure drush is working properly, and can access the source site.
if [[ -z `eval $DRUSH --pipe status database` ]]; then
  echo "$DESTINATION is not a valid Drupal site."
  exit 1
fi

# Get a list of all available commands.
COMMANDS=`eval $DRUSH help --pipe`

# Update the database.
eval $DRUSH updatedb -y
# Clear the drush cache before reverting features.
eval $DRUSH cache-clear drush
# Revert features.
if [[ $COMMANDS =~ features-revert-all ]]; then
  eval $DRUSH features-revert-all --force -y
fi
# Update l10n.
if [[ $COMMANDS =~ l10n-update ]]; then
  $DRUSH l10n-update -y
fi
# Clear all caches.
eval $DRUSH cache-clear all
