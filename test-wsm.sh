#!/bin/bash -

# set -x

if [ -z "$1" ]; then
    echo "Usage: test-wsm.sh <article-name-sans-extension>";
    exit 1;
fi

article=$1;
article_miz="$article.miz";
mml="$MIZFILES/mml";
article_path="$mml/$article_miz";

if [ ! -e $article_path ]; then
    echo "Article $article doesn't exist at the expected location '$article_path'";
    exit 1;
fi

cp $article_path .;
if [ "$?" -ne "0" ]; then
    echo "Error copying the article to the current directory";
    exit 1;
fi

accom -q -s -l $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error accommodating $article";
    exit 1;
fi

newparser -q -s -l $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error with newparser applied to $article"; 
    exit 1;
fi

article_wsx="$article.wsx";

if [ ! -e $article_wsx ]; then
    echo "Error: wsx doesnt't exist for $article";
    exit 1;
fi

stylesheet="/Users/alama/sources/mizar/xsl4mizar/wsm.xsl";

if [ ! -e $stylesheet ]; then
    echo "Error: the WSM stylesheet doesn't exist at '$stylesheet'";
    exit 1;
fi

env_stylesheet="/Users/alama/sources/mizar/xsl4mizar/env.xsl";

if [ ! -e $env_stylesheet ]; then
    echo "Error: environment constructor stylesheet is missing";
    exit 1;
fi

echo "environ" > splork.miz;

envget $article > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error calling envget on $article";
    exit 1;
fi

article_evl="$article.evl";

if [ ! -e $article_evl ]; then
    echo "The evl file for $article doesn't exist";
    exit 1;
fi

xsltproc $env_stylesheet $article_evl >> splork.miz;
if [ "$?" -ne "0" ]; then
    echo "Error calling xsltproc with $env_stylesheet and $article_evl";
    exit 1;
fi
echo "begin" >> splork.miz;

xsltproc $stylesheet $article_wsx >> splork.miz 2> /dev/null;
if [ "$?" -ne "0" ]; then
    echo "Error calling xsltproc with $stylesheet and $article_wsx";
    exit 1;
fi

accom -q -s -l splork > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error accommodating the transformed miz for $article";
    exit 1;
fi

verifier -q -l splork > /dev/null 2>&1;
if [ "$?" -ne "0" ]; then
    echo "Error verifiying the transformed miz for $article";
    exit 1;
fi

echo "$article: OK";
exit 0;
