#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename);

unless (scalar @ARGV == 1) {
  print 'Usage: inferred-constructors.pl ARTICLE', "\n";
  exit 1;
}

my $article = $ARGV[0];

my $article_basename = basename ($article, '.miz');
my $article_xml = "${article_basename}.xml";
my $article_absolute_xml = "${article_basename}.xml1";

my $absrefs_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/addabsrefs.xsl';

unless (-e $absrefs_stylesheet) {
  print 'Error: the addabsrefs stylesheet does not exist at the expected location (', $absrefs_stylesheet, ').', "\n";
  exit 1;
}

unless (-r $absrefs_stylesheet) {
  print 'Error: the addabsrefs stylesheet at ', $absrefs_stylesheet, ' is unreadable.', "\n";
  exit 1;
}

my $inferred_constructors_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/inferred-constructors.xsl';

unless (-e $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet does not exist at the expected location (', $inferred_constructors_stylesheet, ').', "\n";
}

unless (-r $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet at ', $inferred_constructors_stylesheet, ' is unreadable.', "\n";
}

unless (-e $article_xml) {
  print 'Error: the XML for ', $article_basename, ' does not exist at the expected location (', $article_xml, ').', "\n";
  exit 1;
}

unless (-r $article_xml) {
  print 'Error: the XML for ', $article_basename, ' at ', $article_xml, ' is unreadable.', "\n";
  exit 1;
}

my @extensions = ('xml', 'eno', 'dfs', 'ecl', 'eid', 'epr', 'erd', 'esh', 'eth');

foreach my $extension (@extensions) {
  my $file = "${article_basename}.${extension}";
  my $absolutized_file = "${article_basename}.${extension}1";

  if (-e $file) {
    unless (-e $absolutized_file) {
      my $xsltproc_status = system ("xsltproc --output $absolutized_file $absrefs_stylesheet $file 2>/dev/null");
      my $xsltproc_exit_code = $xsltproc_status >> 8;
      if ($xsltproc_exit_code != 0) {
        print 'Warning: xsltproc did not exist cleanly when computing the absolutized form of ', $file, "\n";
      }
    }
  }
}

my @inferred_constructors = `xsltproc $inferred_constructors_stylesheet $article_absolute_xml 2>/dev/null | sort -u | uniq`;

print @inferred_constructors;