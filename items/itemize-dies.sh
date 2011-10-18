#!/bin/bash -

if [ -z $1 ]; then
    echo "Usage: itemize-dies.sh <article-sans-extension>";
fi

article=$1

xsl4mizar_dir=$HOME/sources/mizar/xsl4mizar
split_stylesheet=$xsl4mizar_dir/split.xsl
free_vars_stylesheet=$xsl4mizar_dir/free-variables.xsl
itemize_stylesheet=$xsl4mizar_dir/itemize.xsl

if [ ! -e $split_stylesheet ]; then
    echo "$article: Error: the split stylesheet doesn't exist at '$split_stylesheet'!";
    exit 1;
fi

if [ ! -e $free_vars_stylesheet ]; then
    echo "$article: Error: the free variable stylesheet doesn't exist at '$free_vars_stylesheet'!";
    exit 1;
fi

if [ ! -e $itemize_stylesheet ]; then
    echo "$article: Error: the itemize stylesheet doesn't exist at '$itemize_stylesheet'!";
    exit 1;
fi

article_wsx=$article.wsx

if [ ! -e $article_wsx ]; then
    echo "$article: Error: the .wsx file for $article doesn't exist!";
    exit 1;
fi

split_one=$article.wsxs1
split_two=$article.wsx2
with_free_vars=$article.wsxsf

xsltproc $split_stylesheet $article_wsx > $split_one 2> /dev/null;

if [ $? -ne "0" ]; then
    echo "$article: Error: unable to split $article_wsx";
    exit 1;
fi

xsltproc $split_stylesheet $split_one > $split_two 2> /dev/null;

if [ $? -ne "0" ]; then
    echo "$article: Error: unable to split $split_one";
    exit 1;
fi

xsltproc $free_vars_stylesheet $split_two > $with_free_vars 2> /dev/null;

if [ $? -ne "0" ]; then
    echo "$article: Error: unable to compute free variables fo $split_two";
    exit 1;
fi

xsltproc $itemize_stylesheet $with_free_vars > /dev/null 2> /dev/null;

if [ $? -eq "0" ]; then
    echo "$article: OK";
    exit 0;
else
    echo "$article: Error: unable to itemize $with_free_vars";
    exit 1;
fi
