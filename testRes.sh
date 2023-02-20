#!/bin/bash

resourceExist () {
    if [ $(oc get $2 -n $1 $3 | grep $3 | wc -l) -lt 1 ];
    then
        return 0
    fi
    return 1
}

resourceExist $1 $2 $3
if [ $? -eq 0 ]; then
    echo "KO"
else
    echo "Esiste"
fi
