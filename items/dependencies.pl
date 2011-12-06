#!/usr/bin/perl -w

use strict;
use File::Basename qw(basename dirname);

unless (scalar @ARGV == 1) {
  print 'Usage: dependencies.pl ARTICLE', "\n";
  exit 1;
}

my $article = $ARGV[0];

my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_miz = "${article_dirname}/${article_basename}.miz";
my $article_xml = "${article_dirname}/${article_basename}.xml";
my $article_absolute_xml = "${article_dirname}/${article_basename}.xml1";

unless (-e $article_miz) {
  print 'Error: the .miz for ', $article_basename, ' does not exist.', "\n";
  exit 1;
}

unless (-r $article_miz) {
  print 'Error: the .miz for ', $article_basename, ' is unreadable.', "\n";
  exit 1;
}

my $absrefs_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/addabsrefs.xsl';

unless (-e $absrefs_stylesheet) {
  print 'Error: the absolutizer stylesheet does not exist at the expected location (', $absrefs_stylesheet, ').', "\n";
  exit 1;
}

unless (-r $absrefs_stylesheet) {
  print 'Error: the absolutizer stylesheet at ', $absrefs_stylesheet, ' is unreadable.', "\n";
  exit 1;
}

if (! -e $article_xml) {
  print 'The XML for ', $article_basename, ' does not exist.';
  exit 1;
}

if (! -e $article_absolute_xml) {

  print 'The absolute form of the XML for ', $article_basename, ' does not exist.  Generating...';

  my $xsltproc_status = system ("xsltproc --output $article_absolute_xml $absrefs_stylesheet $article_xml 2>/dev/null | sort -u | uniq");

  # Skip checking the exit code of xsltproc; we can be safe even when
  # it is non-zero, owing to errors like 'Missing .fex' and 'Missing
  # .bex'.  But we will check that the $article_absolute_xml exists.

  unless (-e $article_absolute_xml) {
    print "\n";
    print 'Error: we failed to generate the absolute form of the XML for ', $article_basename, '.', "\n";
    exit 1;
  }

  print 'done.', "\n";
}

my $dependencies_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/dependencies.xsl';

unless (-e $dependencies_stylesheet) {
  print 'Error: the dependencies stylesheet does not exist at the expected location (', $dependencies_stylesheet, ').', "\n";
  exit 1;
}

unless (-r $dependencies_stylesheet) {
  print 'Error: the dependencies stylesheet at ', $dependencies_stylesheet, ' is unreadable.', "\n";
  exit 1;
}

my @non_constructor_deps = `xsltproc $dependencies_stylesheet $article_absolute_xml 2>/dev/null`;
chomp @non_constructor_deps;

# Sanity check: the stylsheet didn't produce any junk output
if (grep (/^$/, @non_constructor_deps)) {
  print 'Error: the dependencies stylesheet generated some junk output.', "\n";
  exit 1;
}

# Constructors are a special case

my $inferred_constructors_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/inferred-constructors.xsl';

unless (-e $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet does not exist at the expected location (', $inferred_constructors_stylesheet, ').', "\n";
}

unless (-r $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet at ', $inferred_constructors_stylesheet, ' is unreadable.', "\n";
}

my @constructor_deps = `xsltproc $inferred_constructors_stylesheet $article_absolute_xml 2>/dev/null | sort -u | uniq`;
chomp @constructor_deps;

# Sanity check: the stylesheet didn't produce any junk output
if (grep (/^$/, @constructor_deps)) {
  print 'Error: the inferred-constructors stylesheet generated some junk output.', "\n";
  exit 1;
}

foreach my $dep (@constructor_deps, @non_constructor_deps) {
  print $dep, "\n";
}
