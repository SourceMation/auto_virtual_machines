#!/bin/bash

man_dirs_dirs=$(man -w | sed 's/:/ /g')
for i in man_dirs_dirs; do
    echo "Removing $i/*"
    rm -rf $i/*
done

echo "Removing info pages"
rm -rf /usr/share/info/*
