#!/bin/sh

PROGDIR=$(dirname "$0")
# on MacOS X need to resort to python to determine the full absolute path of PROGDIR as "readlink -f" only works on Linux
[ `uname -s` = "Darwin" ] && PROGDIR=$(python -c "import os; print(os.path.realpath('$PROGDIR'))") || PROGDIR=$(readlink -f "$PROGDIR")

usage()
{
    echo "usage: $0 <Cluster> <Group> <User> <BecomeUser> <Command>"
    echo ""
    echo "   Cluster: name of a cluster from the 'inventory' subfolder or "
    echo "             path and name of an inventory file"
    echo ""
    CLUSTERS=$(find "inventory_prod/" -mindepth 1 -maxdepth 1 -type d ! -name '_*' | sed 's,//,/,g'; find "inventory_uat/" -mindepth 1 -maxdepth 1 -type d ! -name '_*' | sed 's,//,/,g')
    CLUSTER_COUNT=$(echo "$CLUSTERS" | sed '/^$/d' | wc -l)
    if [ "$CLUSTER_COUNT" -eq 0 ]
    then
        echo "No clusters are currently defined in inventory."
    else
        echo "List of clusters:"
        for CLUSTER in $CLUSTERS
        do
            INVENTORY_ENV=$(echo "$CLUSTER" | cut -d'/' -f1 | sed 's/inventory_//g' | tr 'a-z' 'A-Z')
            CLUSTER_NAME=$(echo "$CLUSTER" | cut -d'/' -f2)
            echo "   - $INVENTORY_ENV: $CLUSTER_NAME"
        done
    fi
    exit 1
}

[ "$#" -lt 5 ] && usage

CLUSTERARG=$(echo "$1")
CLUSTER=$(echo "$CLUSTERARG" | tr "a-z" "A-Z")
shift
GROUP=$1
shift
USER=$1
shift
BECOMEUSER=$1
shift
COMMAND=$1
shift

#echo "CLUSTER:    $CLUSTER"
#echo "GROUP:      $GROUP"
#echo "USER:       $USER"
#echo "BECOMEUSER: $BECOMEUSER"
#echo "COMMAND:    $COMMAND"

[ "x$CLUSTER" = "x" ] && {
    echo "Empty cluster name specified."
    echo ""
    usage
}

INVENTORY_ARG="/proc/dummy_inventory_location"
if [ -e "inventory_prod/${CLUSTER}" ]
then
    [ -e "inventory_prod/${CLUSTER}/hosts.py" ] && INVENTORY_ARG="inventory_prod/${CLUSTER}/hosts.py"
    [ -e "inventory_prod/${CLUSTER}/hosts"    ] && INVENTORY_ARG="inventory_prod/${CLUSTER}/hosts"
elif [ -e "inventory_uat/${CLUSTER}" ]
then
    [ -e "inventory_uat/${CLUSTER}/hosts.py" ] && INVENTORY_ARG="inventory_uat/${CLUSTER}/hosts.py"
    [ -e "inventory_uat/${CLUSTER}/hosts"    ] && INVENTORY_ARG="inventory_uat/${CLUSTER}/hosts"
elif [ -e "inventory_dev/${CLUSTER}" ]
then
    [ -e "inventory_dev/${CLUSTER}/hosts.py" ] && INVENTORY_ARG="inventory_dev/${CLUSTER}/hosts.py"
    [ -e "inventory_dev/${CLUSTER}/hosts"    ] && INVENTORY_ARG="inventory_dev/${CLUSTER}/hosts"
else
    [ -e "${CLUSTERARG}" ] && INVENTORY_ARG="${CLUSTERARG}"
    [ -e "./${CLUSTERARG}" ] && INVENTORY_ARG="./${CLUSTERARG}"
fi

[ -e "$INVENTORY_ARG" ] || {
    echo "Invalid cluster name/inventory file specified: $INVENTORY_ARG."
    echo ""
    usage
}

EXTRAARGS=
[ "x$BECOMEUSER" != "x" ] && EXTRAARGS="-s -U $BECOMEUSER -K"

echo "Executing command: ansible \"$GROUP\" -i \"$INVENTORY_ARG\" -u $USER $EXTRAARGS -m shell -a \"$COMMAND\" $@"
ansible "$GROUP" -i "$INVENTORY_ARG" -u $USER $EXTRAARGS -m shell -a "$COMMAND" "$@"
