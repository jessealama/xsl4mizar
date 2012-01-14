#!/bin/bash -

if [ -z $1 ]; then
    echo "Usage: `basename $0` MIZAR-ND-PROBLEM";
    exit 1;
fi

theorem_file=$1;
theorem_file_basename=`basename $theorem_file`;
theorem_file_dirname=`dirname $theorem_file`;

if [ ! -e $theorem_file ]; then
    echo "Error: the supplied Mizar ND problem file '$theorem_file' does not exist.";
    exit 1;
fi

if [ ! -r $theorem_file ]; then
    echo "Error: the supplied Mizar ND problem file '$theorem_file' is unreadable.";
fi

which tptp4X > /dev/null 2>&1;

if [ $? -ne "0" ]; then
    echo "Error: tptp4X does not seem to be in your path.";
    exit 1;
fi

tptp4X -N -V -c -x $theorem_file > /dev/null 2>&1;

if [ $? -ne "0" ]; then
    echo "Error: the Mizar ND problem file '$theorem_file' is not a valid TPTP file.";
    exit 1;
fi

dir_for_theorem_problems="${theorem_file_dirname}/${theorem_file_basename}-problems";

rm -Rf $dir_for_theorem_problems;

mkdir -p $dir_for_theorem_problems;

theorem_file_xml="${dir_for_theorem_problems}/${theorem_file_basename}.xml";

tptp4X -N -V -c -x -fxml $theorem_file > $theorem_file_xml 2> /dev/null;

by_problems=`xsltproc /Users/alama/sources/mizar/xsl4mizar/nd/list-by-formulas.xsl $theorem_file_xml`;

for by_problem in $by_problems; do
    xsltproc --stringparam formula "$by_problem" \
        /Users/alama/sources/mizar/xsl4mizar/nd/list-hypotheses.xsl $theorem_file_xml > "$dir_for_theorem_problems/$by_problem.tptp";
done

rm $theorem_file_xml;
