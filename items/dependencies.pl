#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw(basename dirname);

my $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
my $verbose = 0;
my $man = 0;
my $help = 0;

GetOptions('help|?' => \$help,
           'man' => \$man,
           'verbose'  => \$verbose,
	   'stylesheet-home=s' => \$stylesheet_home)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
pod2usage(1) unless (scalar @ARGV == 1);

my $article = $ARGV[0];

my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_xml = "${article_dirname}/${article_basename}.xml";
my $article_absolute_xml = "${article_dirname}/${article_basename}.xml1";

unless (-e $stylesheet_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.', "\n";
  exit 1;
}

unless (-d $stylesheet_home) {
  print 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.', "\n";
  exit 1;
}

my %stylesheet_paths = ('absrefs' => "${stylesheet_home}/addabsrefs.xsl",
			'inferred-constructors' => "${stylesheet_home}/inferred-constructors.xsl",
			'dependencies' => "${stylesheet_home}/dependencies.xsl");

foreach my $stylesheet (keys %stylesheet_paths) {
  my $stylesheet_path = $stylesheet_paths{$stylesheet};
  unless (-e $stylesheet_path) {
    print 'Error: the ', $stylesheet, ' stylesheet does not exist at the expected location (', $stylesheet_path, ').', "\n";
    exit 1;
  }
  unless (-r $stylesheet_path) {
    print 'Error: the ', $stylesheet, ' stylesheet at ', $stylesheet_path, ' is unreadable.', "\n";
    exit 1;
  }
}

if (! -e $article_xml) {
  print 'The XML for ', $article_basename, ' does not exist.';
  exit 1;
}

if (! -e $article_absolute_xml) {

  print 'The absolute form of the XML for ', $article_basename, ' does not exist.  Generating...';

  my $absrefs_stylesheet = $stylesheet_paths{'absrefs'};
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

my $dependencies_stylesheet = $stylesheet_paths{'dependencies'};
my @non_constructor_deps = `xsltproc $dependencies_stylesheet $article_absolute_xml 2>/dev/null`;
chomp @non_constructor_deps;

# Sanity check: the stylsheet didn't produce any junk output
if (grep (/^$/, @non_constructor_deps)) {
  print 'Error: the dependencies stylesheet generated some junk output (a blank line).', "\n";
  exit 1;
}

# Constructors are a special case

my $inferred_constructors_stylesheet = $stylesheet_paths{'inferred-constructors'};
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

__END__

=head1 DEPENDENCIES

dependencies.pl - Print the dependencies of a Mizar article

=head1 SYNOPSIS

dependencies.pl [options] mizar-article

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<dependencies.pl> will consult the given article as well as its
environment to determine the article's dependencies, which it prints
(one per line) to standard output.

=cut
