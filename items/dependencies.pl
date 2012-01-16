#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw(basename dirname);

use Xsltproc qw(apply_stylesheet);

my $stylesheet_home = undef;
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

if (defined $stylesheet_home) {
  if (! -e $stylesheet_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets does not exist.', "\n";
  }
  if (! -d $stylesheet_home) {
    die 'Error: the supplied directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.', "\n";
  }
} else {
  $stylesheet_home = '/Users/alama/sources/mizar/xsl4mizar/items';
  if (! -e $stylesheet_home) {
    die 'Error: the default directory in which we look for stylesheets', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'does not exist.  Consider using the --stylesheet-home option.', "\n";
  }
  if (! -d $stylesheet_home) {
    die 'Error: the default directory', "\n", "\n", '  ', $stylesheet_home, "\n", "\n", 'in which we look for stylesheets is not actually a directory.  Consider using the --stylesheet-home option.', "\n";
  }
}

my $article = $ARGV[0];

my $article_basename = basename ($article, '.miz');
my $article_dirname = dirname ($article);
my $article_miz = "${article_dirname}/${article_basename}.miz";
my $article_xml = "${article_dirname}/${article_basename}.xml";
my $article_absolute_xml = "${article_dirname}/${article_basename}.xml1";

my %stylesheet_paths = ('absrefs' => "${stylesheet_home}/addabsrefs.xsl",
			'inferred-constructors' => "${stylesheet_home}/inferred-constructors.xsl",
			'dependencies' => "${stylesheet_home}/dependencies.xsl");

foreach my $stylesheet (keys %stylesheet_paths) {
  my $stylesheet_path = $stylesheet_paths{$stylesheet};
  if (! -e $stylesheet_path) {
    die 'Error: the ', $stylesheet, ' stylesheet does not exist at the expected location (', $stylesheet_path, ').';
  }
  if (! -r $stylesheet_path) {
    die 'Error: the ', $stylesheet, ' stylesheet at ', $stylesheet_path, ' is unreadable.';
  }
}

sub ensure_sensible_mizar_environment {
  # MIZFILES is set and refers to an existing directory
  if (! defined $ENV{'MIZFILES'}) {
    die 'Error: we were asked to ensure a sensible Mizar environment, but the MIZFILES environment variable appears not to be set.';
  }
  my $mizfiles = $ENV{'MIZFILES'};
  if (! -e $mizfiles) {
    die 'Error: we were asked to ensure a sensible Mizar environment, but the value of the MIZFILES environment variable,', "\n", "\n", '  ', $mizfiles, "\n", "\n", 'does not exist.';
  }
  if (! -d $mizfiles) {
    die 'Error: we were asked to ensure a sensible Mizar environment, but the value of the MIZFILES environment variable,', "\n", "\n", '  ', $mizfiles, "\n", "\n", 'is not a directory.';
  }
  my @mizar_tools = ('accom', 'verifier');
  foreach my $tool (@mizar_tools) {
    my $which_status = system ("which $tool > /dev/null 2>&1");
    my $which_exit_code = $which_status >> 8;
    if ($which_exit_code != 0) {
      die 'Error: we were asked to ensure a sensible Mizar environment, but the needed Mizar tool ', $tool, ' could not be found (or is not executable).';
    }
  }
  return 1;
}

sub run_mizar_tool {
  my $tool = shift;
  my $article_err = "${article_dirname}/${article_basename}.err";
  my $tool_status = system ("$tool $article_miz > /dev/null 2>&1");
  my $tool_exit_code = $tool_status >> 8;
  unless ($tool_exit_code == 0 && -z $article_err) {
    if ($verbose) {
      print 'Error: the ', $tool, ' Mizar tool did not exit cleanly when applied to ', $article_miz, ' (or the .err file is non-empty).', "\n";
    }
    return 0;
  }
  return 1;
}

sub accom {
  my $article = shift;
  return (run_mizar_tool ('accom -s -l -q'));
}

sub verifier {
  my $article = shift;
  return (run_mizar_tool ('verifier -s -l -q'));
}

if (! -e $article_xml) {
  if ($verbose) {
    print 'The semantic XML for ', $article_basename, ' does not exist.  Generating...';
  }
  ensure_sensible_mizar_environment ();
  if (accom ($article_miz)) {
    if (! verifier ($article_miz)) {
      die 'Error: the semantic XML for ', $article_basename, ' could not be found, so we tried generating it.  But we failed to verify the article.';
    }
  } else {
    die 'Error: the semantic XML for ', $article_basename, ' could not be found, so we tried generating it.  But we failed to accommodate the article.';
  }
}

if (! -e $article_absolute_xml) {

  if ($verbose) {
    print 'The absolute form of the XML for ', $article_basename, ' does not exist.  Generating...';
  }

  my $absrefs_stylesheet = $stylesheet_paths{'absrefs'};
  my $xsltproc_status = system ("xsltproc --output $article_absolute_xml $absrefs_stylesheet $article_xml 2>/dev/null | sort -u | uniq");

  # Skip checking the exit code of xsltproc; we can be safe even when
  # it is non-zero, owing to errors like 'Missing .fex' and 'Missing
  # .bex'.  But we will check that the $article_absolute_xml exists.

  if (! -e $article_absolute_xml) {
    if ($verbose) {
      print "\n";
    }
    die 'Error: we failed to generate the absolute form of the XML for ', $article_basename, '.', "\n";
    exit 1;
  }

  if ($verbose) {
    print 'done.', "\n";
  }
}

my $dependencies_stylesheet = $stylesheet_paths{'dependencies'};
my @non_constructor_deps = `xsltproc $dependencies_stylesheet $article_absolute_xml`;
chomp @non_constructor_deps;

# Sanity check: the stylsheet didn't produce any junk output
if (grep (/^$/, @non_constructor_deps)) {
  die 'Error: the dependencies stylesheet generated some junk output (a blank line).';
}

# Constructors are a special case

my $inferred_constructors_stylesheet = $stylesheet_paths{'inferred-constructors'};
my @constructor_deps = `xsltproc $inferred_constructors_stylesheet $article_absolute_xml | sort -u | uniq`;
chomp @constructor_deps;

# Sanity check: the stylesheet didn't produce any junk output
if (grep (/^$/, @constructor_deps)) {
  die 'Error: the inferred-constructors stylesheet generated some junk output.';
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
