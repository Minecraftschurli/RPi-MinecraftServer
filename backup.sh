#!/bin/bash

#================:CONFIG:================#
EXT=.tar.gz
BACKUP_FOLDER=./backups
TIMESTAMP_FORMAT=+%F_%T
TIMESTAMP=$(date $TIMESTAMP_FORMAT)
KEEP_FOR="4 months"
#========================================#
DIR="@DIR@"

# parse parameters
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -a|--auto)
            AUTO=YES
            shift
        ;;
        -f|--full)
            FULL=YES
            shift
        ;;
        -w|--world)
            WORLDS+=("$2")
            shift
            shift
        ;;
        --test)
            TEST=YES
            shift
        ;;
        --legacy)
            ENABLE_LEGACY=YES
            shift
        ;;
        *)
            POSITIONAL+=("$1")
            shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

TEST="${TEST:-NO}"
AUTO="${AUTO:-NO}"
if [ ${#WORLDS[@]} -le 0 ]; then
    FULL=YES
fi
if [[ "$AUTO" == YES ]]; then
    FULL=YES
fi
FULL="${FULL:-NO}"

if [[ "$TEST" == YES ]]; then
    echo "Running backup with options:"
    echo "Automatic=$AUTO"
    if [[ "$FULL" == YES ]]; then
        echo "Full=$FULL"
    else
        echo "Worlds=${WORLDS[@]}"
    fi
fi

echo "Ensure disc mounted"
sudo mount -a
echo "Ensure right workdir"
cd $DIR

if [[ "$FULL" == YES ]]; then
    if [[ "$TEST" == NO ]]; then
        pg_dump -Fc minecraft > ./db_dump
    fi
    if [[ "$AUTO" == YES ]]; then
        BACKUP_NAME="AUTOMATIC_FULL_BACKUP_$TIMESTAMP"
    else
        BACKUP_NAME="MANUAL_FULL_BACKUP_$TIMESTAMP"
    fi
    FILE_NAME=$BACKUP_FOLDER/$BACKUP_NAME$EXT
    echo "Backing up server to \"$FILE_NAME\""
    if [[ "$TEST" == NO ]]; then
        tar --exclude=$BACKUP_FOLDER --exclude='./cache' --exclude='./logs/*.log.gz' --exclude='./paperclip.jar' --exclude='./plugins/dynmap/web' -pzcf $FILE_NAME ./*
        rm ./db_dump
    fi
else
    echo "Backing up worlds: ${WORLDS[@]}"
    for (( i=0; i<${#WORLDS[@]}; i++ )); do
        WORLD_NAME=${WORLDS[$i]}
        if [ -d ./$WORLD_NAME ]; then
            BACKUP_NAME="WORLD_BACKUP_${WORLD_NAME}_${TIMESTAMP}"
            FILE_NAME=$BACKUP_FOLDER/$BACKUP_NAME$EXT
            echo "Backing up world \"$WORLD_NAME\" to \"$FILE_NAME\""
            if [[ "$TEST" == NO ]]; then
                tar -pzcf $FILE_NAME ./$WORLD_NAME
            fi
        else
            echo "World \"$WORLDNAME\" does not extst! skipping..."
        fi
    done
fi

THRESHOLD=$(date -d "$KEEP_FOR ago" +%s)

echo "Removing automatic Backups older than $KEEP_FOR"
FILES=$BACKUP_FOLDER/AUTOMATIC*$EXT
for file in $FILES; do
    if [[ "$file" == "$FILES" ]]; then break; fi
    date=${file#*}
    date=${date%$EXT}
    date=`echo $date| rev `
    date=${date:0:19}
    date=`echo $date| rev `
    date=${date/_/T}
    if [[ $(date -d $date +%s) -le $THRESHOLD ]]; then
        echo "Removing $file"
        if [[ "$TEST" == NO ]]; then
            rm $file
        fi
    fi
done
if [[ "$ENABLE_LEGACY" != YES ]]; then exit 0; fi
# LEGACY
LEGACY=$BACKUP_FOLDER/*$EXT
for file in $LEGACY; do
    if [[ "$file" == "$LEGACY" ]]; then break; fi
    date=${file#*}
    date=${date%$EXT}
    date=`echo $date| rev `
    date=${date:0:19}
    date=`echo $date| rev `
    tmp_date=$date
    date=${date//./}
    date=$(date -d ${tmp_date:0:4}-${tmp_date:5:2}-${tmp_date:8:2}T${tmp_date:11:2}:${tmp_date:14:2}:${tmp_date:17:2}+00:00 +%s)
    if [[ $date -le $THRESHOLD ]]; then
        echo "Removing $file"
        if [[ "$TEST" == NO ]]; then
            rm $file
        fi
    else
        echo "DETECTED LEGACY FILE \"$file\""
        if [ ${tmp_date:11:2} == "04" ]; then
            echo "LEGACY FILE is AUTOMATIC"
            NEW_FILE_PREFIX=AUTOMATIC_
        else
            echo "LEGACY FILE is MANUAL"
            NEW_FILE_PREFIX=MANUAL_
        fi
        NEW_FILE=${BACKUP_FOLDER}/${NEW_FILE_PREFIX}FULL_BACKUP_$(date -d "@${date}" $TIMESTAMP_FORMAT)${EXT}
        echo "RENAME LEGACY FILE to \"$NEW_FILE\""
        if [[ "$TEST" == NO ]]; then
            mv $file $NEW_FILE
        fi
    fi
done
