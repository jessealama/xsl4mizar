#!/bin/bash -

# set -x

if [ -z "$1" ]; then
    echo "Usage: test-wsm.sh <article-name-sans-extension>";
    rm -f $article.* splork.*;
    exit 1;
fi

article=$1;
article_miz="$article.miz";
mml="$MIZFILES/mml";
article_path="$mml/$article_miz";

if [ ! -e $article_path ]; then
    echo "Article $article doesn't exist at the expected location '$article_path'";
    rm -f $article.* splork.*;
    exit 1;
fi

cp $article_path .;
if [ "$?" -ne "0" ]; then
    echo "Error copying the article to the current directory";
    rm -f $article.* splork.*;
    exit 1;
fi

accom -q -s -l $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error accommodating $article";
    rm -f $article.* splork.*;
    exit 1;
fi

newparser -q -s -l $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error with newparser applied to $article"; 
    rm -f $article.* splork.*;
    exit 1;
fi

article_wsx="$article.wsx";

if [ ! -e $article_wsx ]; then
    echo "Error: wsx doesnt't exist for $article";
    rm -f $article.* splork.*;
    exit 1;
fi

wsm_stylesheet="/Users/alama/sources/mizar/xsl4mizar/wsm.xsl";

if [ ! -e $wsm_stylesheet ]; then
    echo "Error: the WSM stylesheet doesn't exist at '$stylesheet'";
    rm -f $article.* splork.*;
    exit 1;
fi

env_stylesheet="/Users/alama/sources/mizar/xsl4mizar/env.xsl";

if [ ! -e $env_stylesheet ]; then
    echo "Error: environment constructor stylesheet is missing";
    rm -f $article.* splork.*;
    exit 1;
fi

itemize_stylesheet="/Users/alama/sources/mizar/xsl4mizar/itemize.xsl";

if [ ! -e $itemize_stylesheet ]; then
    echo "Error: the itemization stylesheet doesn't exist at '$itemize_stylesheet'";
    rm -f $article.* splork.*;
    exit 1;
fi

# Itemize
article_wsx_one="$article.wsx1";
xsltproc $itemize_stylesheet $article_wsx > $article_wsx_one 2> /dev/null;
if [ "$?" -ne "0" ]; then
    echo "$article: Error calling xsltproc with $itemize_stylesheet and $article_wsx";
    rm -f $article.* splork.*;
    exit 1;
fi

# Construct the .miz article

echo "environ" > splork.miz;

envget $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "$article: Error calling envget";
    rm -f $article.* splork.*;
    exit 1;
fi

article_evl="$article.evl";

if [ ! -e $article_evl ]; then
    echo "The evl file for $article doesn't exist";
    rm -f $article.* splork.*;
    exit 1;
fi

xsltproc $env_stylesheet $article_evl >> splork.miz;
if [ "$?" -ne "0" ]; then
    echo "$article: Error calling xsltproc with $env_stylesheet and $article_evl";
    rm -f $article.* splork.*;
    exit 1;
fi
echo "begin" >> splork.miz;

xsltproc $wsm_stylesheet $article_wsx_one >> splork.miz 2> /dev/null;
if [ "$?" -ne "0" ]; then
    echo "$article: Error calling xsltproc with $wsm_stylesheet and $article_wsx";
    rm -f $article.* splork.*;
    exit 1;
fi

accom -q -s -l splork > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "$article: Error accommodating the transformed miz";
    rm -f $article.* splork.*;
    exit 1;
fi

verifier -q -s -l splork > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "$article: Error verifiying the transformed miz";
    rm -f $article.* splork.*;
    exit 1;
fi

echo "$article: OK";

rm -f $article.* splork.*;

exit 0;
