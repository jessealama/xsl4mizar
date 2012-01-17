#!/usr/bin/perl

use warnings;
use strict;
use File::Basename qw(dirname basename);
use Getopt::Long;
use Pod::Usage;
use XML::LibXML;

my $xml_parser = XML::LibXML->new (suppress_warnings => 1,
				   suppress_errors => 1);

sub ensure_valid_xml_file {
  my $xml_path = shift;
  if (defined eval { $xml_parser->parse_file ($xml_path) }) {
    return 1;
  } else {
    croak ('Error: ', $xml_path, ' is not a well-formed XML file.');
  }
}

my $help = 0;
my $man = 0;
my $verbose = 0;
my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'stylesheet-home=s' => \$stylesheet_home)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) unless (scalar @ARGV == 1);

my $article = $ARGV[0];

my $article_dirname = dirname ($article);
my $article_basename = basename ($article, '.miz');
my $article_xml = "${article_dirname}/${article_basename}.xml";
my $article_absolute_xml = "${article_dirname}/${article_basename}.xml1";

my $absrefs_stylesheet = "${stylesheet_home}/addabsrefs.xsl";

unless (-e $absrefs_stylesheet) {
  print 'Error: the addabsrefs stylesheet does not exist at the expected location (', $absrefs_stylesheet, ').', "\n";
  exit 1;
}

unless (-r $absrefs_stylesheet) {
  print 'Error: the addabsrefs stylesheet at ', $absrefs_stylesheet, ' is unreadable.', "\n";
  exit 1;
}

if  (! -e $article_xml) {
  croak ('Error: the semantic XML for ', $article_basename, ' could not be found at the expected location (', $article_xml, ').', "\n");
}

if  (! -r $article_xml) {
  croak ('Error: the semantic XML for ', $article_basename, ' at (', $article_xml, ') is unreadable.', "\n");
}

ensure_valid_xml_file ($article_xml);

if (! -e $article_absolute_xml) {
  my $xsltproc_status = system ("xsltproc $absrefs_stylesheet $article_xml > $article_absolute_xml 2> /dev/null");
  my $xsltproc_exit_code = $xsltproc_status >> 8;
  if ($xsltproc_exit_code != 0) {
    die 'Error: the needed absolute form of the XML for ', $article_basename, ' was missing, so we tried to create it;', "\n", 'but xsltproc did not exit cleanly applying the absolutizer stylesheet to ', $article_xml, '.';
  }
  ensure_valid_xml_file ($article_absolute_xml);
}

if (! -r $article_absolute_xml) {
  die 'Error: the absolute form of ', $article_basename, ' at ', $article_absolute_xml, ' is unreadable.';
}

ensure_valid_xml_file ($article_absolute_xml);

my $inferred_constructors_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/items/inferred-constructors.xsl';

if (! -e $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet does not exist at the expected location (', $inferred_constructors_stylesheet, ').', "\n";
}

if (! -r $inferred_constructors_stylesheet) {
  print 'Error: the inferred-constructors stylesheet at ', $inferred_constructors_stylesheet, ' is unreadable.', "\n";
}

unless (-r $article_xml) {
  print 'Error: the XML for ', $article_basename, ' at ', $article_xml, ' is unreadable.', "\n";
  exit 1;
}

my @inferred_constructors = `xsltproc --stringparam 'article-directory' '${article_dirname}' $inferred_constructors_stylesheet $article_absolute_xml | sort -u | uniq`;

print @inferred_constructors;
